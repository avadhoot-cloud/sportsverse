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
