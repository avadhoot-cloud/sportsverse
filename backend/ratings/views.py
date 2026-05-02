"""
ratings/views.py

Refactored for Student-Driven Match Submission, Verification, and Dispute Flow.
"""
import logging
from datetime import date as date_type
from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import CustomUser
from organizations.models import Enrollment, Sport
from ratings.models import PlayerRatingProfile, RatingMatch, RatingAudit, MatchAuditTrail
from ratings.rating import update_singles, update_doubles, expected_points_percentage
from ratings.reconciliation import reconcile_scores
from ratings.reliability import update_reliability
from ratings.fairness import calculate_fairness_index

logger = logging.getLogger(__name__)

def _get_or_create_rating(user, sport, org):
    profile, _ = PlayerRatingProfile.objects.get_or_create(
        user=user,
        sport=sport,
        organization=org,
        defaults={
            'dupr_rating_singles': 4.000,
            'dupr_rating_doubles': 4.000,
            'matches_played_singles': 0,
            'matches_played_doubles': 0,
            'reliability': 50.00,
        },
    )
    return profile


class MatchSubmitView(APIView):
    """
    POST /api/ratings/matches/
    Players submit match results here. Status becomes PENDING.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data
        required = ['sport_id', 'date', 'format', 'opponent_username', 'score']
        missing = [f for f in required if not data.get(f)]
        if missing:
            return Response({'error': f'Missing fields: {missing}'}, status=status.HTTP_400_BAD_REQUEST)

        fmt = data['format'].upper()
        if fmt not in ('SINGLES', 'DOUBLES'):
            return Response({'error': 'format must be SINGLES or DOUBLES'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            sport = Sport.objects.get(pk=data['sport_id'])
            # Assuming first organization for simplicity in this demo endpoint
            org = sport.organizations.first() 
        except Sport.DoesNotExist:
            return Response({'error': 'Sport ID not found in the database.'}, status=status.HTTP_404_NOT_FOUND)
            
        try:
            p2 = CustomUser.objects.get(username=data['opponent_username'])
            if p2 == request.user:
                return Response({'error': 'You cannot submit a match against yourself.'}, status=status.HTTP_400_BAD_REQUEST)
            if p2.user_type != 'STUDENT':
                return Response({'error': 'The specified opponent is not a valid student player.'}, status=status.HTTP_400_BAD_REQUEST)
        except CustomUser.DoesNotExist:
            return Response({'error': 'Invalid Username. That player does not exist.'}, status=status.HTTP_404_NOT_FOUND)

        participants = [request.user.pk, p2.pk]
        if fmt == 'DOUBLES':
            if not data.get('player3_id') or not data.get('player4_id'):
                return Response({'error': 'Doubles needs 4 players'}, status=status.HTTP_400_BAD_REQUEST)
            participants.extend([data['player3_id'], data['player4_id']])

        dedup_hash = RatingMatch.compute_dedup_hash(participants, data['date'], data['score'])
        if RatingMatch.objects.filter(dedup_hash=dedup_hash).exists():
            return Response({'error': 'Duplicate match'}, status=status.HTTP_409_CONFLICT)

        with transaction.atomic():
            match = RatingMatch.objects.create(
                organization=org,
                sport=sport,
                submitted_by=request.user,
                date=data['date'],
                format=fmt,
                participants=participants,
                score=data['score'], 
                dedup_hash=dedup_hash,
                status=RatingMatch.STATUS_PENDING,
            )
            MatchAuditTrail.objects.create(
                match=match, actor=request.user,
                new_status=RatingMatch.STATUS_PENDING,
                action_type="SUBMITTED",
                note="Match submitted pending verification."
            )

        return Response({"match_id": match.pk, "status": match.status}, status=status.HTTP_201_CREATED)


class MatchVerificationView(APIView):
    """
    POST /api/ratings/matches/<uuid>/verify/
    Opponent acts on the match: confirm, counter, or dispute.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            match = RatingMatch.objects.get(pk=pk)
        except RatingMatch.DoesNotExist:
            return Response({'error': 'Match not found'}, status=status.HTTP_404_NOT_FOUND)

        if match.status != RatingMatch.STATUS_PENDING:
            return Response({'error': 'Match no longer pending'}, status=status.HTTP_400_BAD_REQUEST)

        # Check if user is opponent (simplification: if they are in participants and not submitter)
        if request.user.pk not in match.participants or request.user == match.submitted_by:
            return Response({'error': 'Only opponents can verify'}, status=status.HTTP_403_FORBIDDEN)

        action = request.data.get('action') # "CONFIRM", "COUNTER", "DISPUTE"
        if action not in ["CONFIRM", "COUNTER", "DISPUTE"]:
            return Response({'error': 'Invalid action'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            old_status = match.status
            rp_opponent = _get_or_create_rating(request.user, match.sport, match.organization)
            rp_submitter = _get_or_create_rating(match.submitted_by, match.sport, match.organization)

            if action == "CONFIRM":
                match.status = RatingMatch.STATUS_CONFIRMED
                match.resolved_score = match.score
                update_reliability(rp_submitter, "EXACT_MATCH")
                update_reliability(rp_opponent, "EXACT_MATCH")
                
            elif action == "DISPUTE":
                match.status = RatingMatch.STATUS_DISPUTED
                match.evidence_url = request.data.get('evidence_url', '')

            elif action == "COUNTER":
                opponent_score = request.data.get('opponent_score')
                if not opponent_score:
                    return Response({'error': 'opponent_score required'}, status=status.HTTP_400_BAD_REQUEST)
                
                match.opponent_score = opponent_score
                resolved = reconcile_scores(match.score, opponent_score, rp_submitter.reliability, rp_opponent.reliability)
                
                if resolved:
                    match.status = RatingMatch.STATUS_AUTO_RESOLVED
                    match.resolved_score = resolved
                    update_reliability(rp_submitter, "MINOR_DISCREPANCY")
                    update_reliability(rp_opponent, "MINOR_DISCREPANCY")
                else:
                    match.status = RatingMatch.STATUS_DISPUTED
            
            match.save()
            MatchAuditTrail.objects.create(
                match=match, actor=request.user,
                previous_status=old_status, new_status=match.status,
                action_type=action,
            )

        # Trigger Celery task here to calculate rating if CONFIRMED or AUTO_RESOLVED
        if match.status in [RatingMatch.STATUS_CONFIRMED, RatingMatch.STATUS_AUTO_RESOLVED]:
            # e.g., process_match_rating.delay(match.pk)
            pass

        return Response({"match_id": match.pk, "status": match.status}, status=status.HTTP_200_OK)


class PendingMatchesView(APIView):
    """
    GET /api/ratings/matches/pending/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # All matches where user is a participant but did not submit, and status is PENDING
        matches = RatingMatch.objects.filter(
            participants__contains=request.user.pk,
            status=RatingMatch.STATUS_PENDING
        ).exclude(submitted_by=request.user)

        data = []
        for m in matches:
            data.append({
                'match_id': m.pk,
                'reporter': m.submitted_by.username,
                'date': m.date,
                'score': m.score,
                'deadline_at': m.deadline_at,
            })
        return Response(data, status=status.HTTP_200_OK)


class MatchHistoryView(APIView):
    """
    GET /api/ratings/matches/history/
    Returns all match records the user participated in (Pending, Confirmed, Disputed, etc.)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        matches = RatingMatch.objects.filter(
            participants__contains=request.user.pk
        ).order_by('-date')

        data = []
        for m in matches:
            data.append({
                'match_id': m.pk,
                'reporter': m.submitted_by.username,
                'date': m.date,
                'status': m.status,
                'score': m.score,
                'opponent_score': m.opponent_score,
                'resolved_score': m.resolved_score,
                'format': m.format,
            })
        return Response(data, status=status.HTTP_200_OK)


class StudentRatingsView(APIView):
    """
    GET /api/ratings/students/
    List all students in the organization with their current DUPR ratings.
    Used for the leaderboard in Admin and Coach dashboards.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        print(f"DEBUG: StudentRatingsView hit by user {request.user.username} ({request.user.user_type})")
        # Determine organization scope
        if hasattr(request.user, 'academy_admin_profile'):
            org = request.user.academy_admin_profile.organization
        elif hasattr(request.user, 'coach_profile'):
            org = request.user.coach_profile.organization
        elif hasattr(request.user, 'student_profile'):
            org = request.user.student_profile.organization
        else:
            return Response({'error': 'Organization context not found.'}, status=status.HTTP_403_FORBIDDEN)

        from accounts.models import StudentProfile
        students = StudentProfile.objects.filter(organization=org).select_related('user')
        
        # Optional filters
        batch_id = request.query_params.get('batch_id')
        if batch_id:
            from organizations.models import Enrollment
            student_ids = Enrollment.objects.filter(batch_id=batch_id, is_active=True).values_list('student_id', flat=True)
            students = students.filter(id__in=student_ids)

        # Get all rating profiles for this org to avoid N+1
        profiles_map = {
            p.user_id: p 
            for p in PlayerRatingProfile.objects.filter(organization=org)
        }

        data = []
        for s in students:
            u = s.user
            if not u:
                continue
            
            p = profiles_map.get(u.pk)
            
            # Default values if no profile exists
            rating_singles = float(p.dupr_rating_singles) if p else 4.000
            rating_doubles = float(p.dupr_rating_doubles) if p else 4.000
            matches_s = p.matches_played_singles if p else 0
            matches_d = p.matches_played_doubles if p else 0
            reliability = float(p.reliability) if p else 50.00
            
            data.append({
                'user_id': u.pk,
                'username': u.username,
                'first_name': u.first_name or s.first_name,
                'last_name': u.last_name or s.last_name,
                'sport_id': p.sport_id if p else 0,
                'sport_name': p.sport.name if p and p.sport else 'N/A',
                'dupr_rating_singles': rating_singles,
                'dupr_rating_doubles': rating_doubles,
                'matches_played_singles': matches_s,
                'matches_played_doubles': matches_d,
                'reliability': int(reliability),
                'is_provisional': matches_s < 10, 
                'updated_at': p.updated_at.isoformat() if p else None,
            })
        
        # Sort ranking wise by singles rating by default
        data.sort(key=lambda x: x['dupr_rating_singles'], reverse=True)
        
        return Response(data, status=status.HTTP_200_OK)


class MyRatingHistoryView(APIView):
    """
    GET /api/ratings/my-history/
    Returns rating change audit entries for the logged-in user.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        audits = RatingAudit.objects.filter(player=request.user).order_by('-created_at')[:50]
        data = []
        for a in audits:
            data.append({
                'id': a.pk,
                'match_id': a.match_id if a.match else None,
                'old_rating': float(a.old_rating),
                'new_rating': float(a.new_rating),
                'delta': float(a.delta),
                'format': a.format,
                'date': a.created_at.date().isoformat(),
                'method': a.method,
                'note': a.note,
            })
        return Response(data, status=status.HTTP_200_OK)


class ForecastMatchView(APIView):
    """
    POST /api/ratings/forecast/
    Simulate a match result between two players to see predicted rating impact.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        p1_id = request.data.get('player1_id')
        p2_id = request.data.get('player2_id')
        fmt = request.data.get('format', 'SINGLES').upper()
        
        if not p1_id or not p2_id:
            return Response({'error': 'player1_id and player2_id are required'}, status=400)

        try:
            p1 = CustomUser.objects.get(pk=p1_id)
            p2 = CustomUser.objects.get(pk=p2_id)
            # Use first sport for profile fetch (simplification)
            profile1 = PlayerRatingProfile.objects.filter(user=p1).first()
            profile2 = PlayerRatingProfile.objects.filter(user=p2).first()
        except CustomUser.DoesNotExist:
            return Response({'error': 'Player not found'}, status=404)

        # Fallback to defaults if profiles are missing
        r1 = float(profile1.dupr_rating_singles if fmt == 'SINGLES' else profile1.dupr_rating_doubles) if profile1 else 4.000
        r2 = float(profile2.dupr_rating_singles if fmt == 'SINGLES' else profile2.dupr_rating_doubles) if profile2 else 4.000

        win_prob1 = expected_points_percentage(r1, r2)
        
        # Simple delta simulation (using a fixed K-factor of 0.1 for forecast)
        k = 0.1
        delta_if_win = k * (1.0 - win_prob1)
        delta_if_loss = k * (0.0 - win_prob1)

        return Response({
            'win_probability_player1': win_prob1,
            'player1': {
                'current_rating': r1,
                'if_win': {'new_rating': r1 + delta_if_win, 'delta': delta_if_win},
                'if_loss': {'new_rating': r1 + delta_if_loss, 'delta': delta_if_loss},
            },
            'player2': {
                'current_rating': r2,
                'if_win': {'new_rating': r2 + (k * (1.0 - (1.0-win_prob1))), 'delta': k * (1.0 - (1.0-win_prob1))},
            }
        })

