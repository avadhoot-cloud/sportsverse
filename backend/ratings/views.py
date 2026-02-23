"""
ratings/views.py

Three views for the coach-facing DUPR rating system:
  - StudentRatingsView  : GET all student ratings for coach's org
  - MatchSubmitView     : POST a match → recalculate DUPR immediately
  - MatchListView       : GET matches submitted by this coach
"""
import logging
from datetime import date as date_type

from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from coaches.models import CoachAssignment
from organizations.models import Enrollment
from ratings.models import PlayerRatingProfile, RatingMatch, RatingAudit
from ratings.rating import (
    dupr_to_elo,
    elo_to_dupr,
    expected_score,
    k_factor,
    reliability_from_matches,
)

logger = logging.getLogger(__name__)


def _coach_or_403(user):
    """Returns (coach_profile, None) or (None, Response 403)."""
    if user.user_type != 'COACH' or not hasattr(user, 'coach_profile'):
        return None, Response(
            {'error': 'Coach access required.'},
            status=status.HTTP_403_FORBIDDEN,
        )
    return user.coach_profile, None


def _get_or_create_rating(user, sport, org):
    """Get or create a PlayerRatingProfile for a user/sport/org triple."""
    profile, _ = PlayerRatingProfile.objects.get_or_create(
        user=user,
        sport=sport,
        organization=org,
        defaults={
            'dupr_rating_singles': 4.000,
            'dupr_rating_doubles': 4.000,
            'matches_played_singles': 0,
            'matches_played_doubles': 0,
            'reliability': 0,
        },
    )
    return profile


# ─── StudentRatingsView ───────────────────────────────────────────────────────

class StudentRatingsView(APIView):
    """
    GET /api/ratings/students/

    Returns all PlayerRatingProfile rows for students in the coach's organization.
    Optionally filtered by ?sport_id=X or ?batch_id=X.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        coach, err = _coach_or_403(request.user)
        if err:
            return err

        org = coach.organization
        sport_id = request.query_params.get('sport_id')
        batch_id = request.query_params.get('batch_id')

        # Get all student user IDs in this org
        student_qs = org.student_profiles.select_related('user')

        # Filter to batch if requested
        if batch_id:
            enrolled_user_ids = (
                Enrollment.objects
                .filter(batch_id=batch_id, organization=org, is_active=True)
                .values_list('student__user_id', flat=True)
            )
            student_qs = student_qs.filter(user_id__in=enrolled_user_ids)

        student_user_ids = list(student_qs.values_list('user_id', flat=True))

        # Fetch rating profiles
        rating_qs = PlayerRatingProfile.objects.filter(
            organization=org,
            user_id__in=student_user_ids,
        ).select_related('user', 'sport')

        if sport_id:
            rating_qs = rating_qs.filter(sport_id=sport_id)

        rating_qs = rating_qs.order_by('-dupr_rating_singles')

        data = []
        for rp in rating_qs:
            u = rp.user
            data.append({
                'user_id': u.pk,
                'username': u.username,
                'first_name': u.first_name,
                'last_name': u.last_name,
                'sport_id': rp.sport.pk,
                'sport_name': rp.sport.name,
                'dupr_rating_singles': float(rp.dupr_rating_singles),
                'dupr_rating_doubles': float(rp.dupr_rating_doubles),
                'matches_played_singles': rp.matches_played_singles,
                'matches_played_doubles': rp.matches_played_doubles,
                'reliability': rp.reliability,
                'is_provisional': rp.is_provisional_singles,
                'updated_at': rp.updated_at.isoformat(),
            })

        # For students with no rating profile yet, include them with defaults
        rated_user_ids = {rp.user_id for rp in rating_qs}
        for sp in student_qs:
            if sp.user_id not in rated_user_ids:
                u = sp.user
                data.append({
                    'user_id': u.pk,
                    'username': u.username,
                    'first_name': u.first_name,
                    'last_name': u.last_name,
                    'sport_id': None,
                    'sport_name': 'N/A',
                    'dupr_rating_singles': 4.000,
                    'dupr_rating_doubles': 4.000,
                    'matches_played_singles': 0,
                    'matches_played_doubles': 0,
                    'reliability': 0,
                    'is_provisional': True,
                    'updated_at': None,
                })

        return Response(data, status=status.HTTP_200_OK)


# ─── MatchSubmitView ──────────────────────────────────────────────────────────

class MatchSubmitView(APIView):
    """
    POST /api/ratings/matches/

    Submit a match and immediately recalculate DUPR ratings.

    Expected payload:
    {
        "sport_id": 1,
        "date": "2026-02-22",
        "format": "SINGLES",            # or "DOUBLES"
        "importance": "CASUAL",         # CASUAL | LEAGUE | TOURNAMENT
        "player1_id": 5,                # winner (singles)
        "player2_id": 8,                # loser  (singles)
        "score": {"sets": [[6,3],[6,4]], "winner_id": 5},

        # Doubles only (optional for SINGLES):
        "player3_id": null,
        "player4_id": null
    }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        coach, err = _coach_or_403(request.user)
        if err:
            return err

        data = request.data

        # ── Validate required fields ──────────────────────────────────────────
        required = ['date', 'format', 'importance', 'player1_id', 'player2_id', 'score']
        missing = [f for f in required if not data.get(f)]
        if missing:
            return Response({'error': f'Missing fields: {missing}'}, status=status.HTTP_400_BAD_REQUEST)

        fmt = data['format'].upper()
        if fmt not in ('SINGLES', 'DOUBLES'):
            return Response({'error': 'format must be SINGLES or DOUBLES'}, status=status.HTTP_400_BAD_REQUEST)

        importance = data.get('importance', 'CASUAL').upper()
        if importance not in ('CASUAL', 'LEAGUE', 'TOURNAMENT'):
            return Response({'error': 'Invalid importance'}, status=status.HTTP_400_BAD_REQUEST)

        org = coach.organization

        # ── Load sport (optional — fall back to org's first sport) ─────────────
        sport_id = data.get('sport_id')
        try:
            from organizations.models import Sport
            if sport_id:
                sport = Sport.objects.get(pk=sport_id, organizations=org)
            else:
                sport = Sport.objects.filter(organizations=org).order_by('pk').first()
                if not sport:
                    return Response(
                        {'error': 'No sports configured in your organization'},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
        except Sport.DoesNotExist:
            return Response({'error': 'Sport not found in your organization'}, status=status.HTTP_404_NOT_FOUND)

        # ── Load users ────────────────────────────────────────────────────────
        from accounts.models import CustomUser
        try:
            p1 = CustomUser.objects.get(pk=data['player1_id'])
            p2 = CustomUser.objects.get(pk=data['player2_id'])
        except CustomUser.DoesNotExist:
            return Response({'error': 'Player not found'}, status=status.HTTP_404_NOT_FOUND)

        score_json = data['score']
        winner_id = score_json.get('winner_id')

        # For SINGLES: participants = [p1_id, p2_id]
        participants = [p1.pk, p2.pk]

        if fmt == 'DOUBLES':
            p3_id = data.get('player3_id')
            p4_id = data.get('player4_id')
            if not p3_id or not p4_id:
                return Response({'error': 'Doubles requires player3_id and player4_id'}, status=status.HTTP_400_BAD_REQUEST)
            try:
                p3 = CustomUser.objects.get(pk=p3_id)
                p4 = CustomUser.objects.get(pk=p4_id)
            except CustomUser.DoesNotExist:
                return Response({'error': 'Doubles player not found'}, status=status.HTTP_404_NOT_FOUND)
            participants = [p1.pk, p2.pk, p3.pk, p4.pk]

        # ── Dedup check ───────────────────────────────────────────────────────
        dedup_hash = RatingMatch.compute_dedup_hash(participants, data['date'], score_json)
        if RatingMatch.objects.filter(dedup_hash=dedup_hash).exists():
            return Response({'error': 'Duplicate match already recorded'}, status=status.HTTP_409_CONFLICT)

        # ── Create match + process ratings atomically ─────────────────────────
        with transaction.atomic():
            match = RatingMatch.objects.create(
                organization=org,
                sport=sport,
                submitted_by=request.user,
                date=data['date'],
                format=fmt,
                importance=importance,
                participants=participants,
                score=score_json,
                dedup_hash=dedup_hash,
                status=RatingMatch.STATUS_VALIDATED,
                validated=True,
                source=RatingMatch.SOURCE_MANUAL,
            )

            result = {}

            if fmt == 'SINGLES':
                rp1 = _get_or_create_rating(p1, sport, org)
                rp2 = _get_or_create_rating(p2, sport, org)

                elo1 = dupr_to_elo(float(rp1.dupr_rating_singles))
                elo2 = dupr_to_elo(float(rp2.dupr_rating_singles))

                exp1 = expected_score(elo1, elo2)
                exp2 = 1.0 - exp1

                actual1 = 1.0 if winner_id == p1.pk else 0.0
                actual2 = 1.0 - actual1

                k1 = k_factor(rp1.matches_played_singles, importance)
                k2 = k_factor(rp2.matches_played_singles, importance)

                new_elo1 = elo1 + k1 * (actual1 - exp1)
                new_elo2 = elo2 + k2 * (actual2 - exp2)

                new_dupr1 = elo_to_dupr(new_elo1)
                new_dupr2 = elo_to_dupr(new_elo2)

                old_dupr1 = float(rp1.dupr_rating_singles)
                old_dupr2 = float(rp2.dupr_rating_singles)

                rp1.matches_played_singles += 1
                rp1.dupr_rating_singles = new_dupr1
                rp1.reliability = reliability_from_matches(rp1.matches_played_singles)
                rp1.last_synced_at = timezone.now()
                rp1.save()

                rp2.matches_played_singles += 1
                rp2.dupr_rating_singles = new_dupr2
                rp2.reliability = reliability_from_matches(rp2.matches_played_singles)
                rp2.last_synced_at = timezone.now()
                rp2.save()

                # Audit entries
                for player, old_r, new_r in [(p1, old_dupr1, new_dupr1), (p2, old_dupr2, new_dupr2)]:
                    RatingAudit.objects.create(
                        match=match,
                        player=player,
                        format=RatingMatch.FORMAT_SINGLES,
                        old_rating=old_r,
                        new_rating=new_r,
                        delta=round(new_r - old_r, 3),
                        method=RatingAudit.METHOD_LIVE,
                        note=f'Match #{match.pk} singles result',
                    )

                match.status = RatingMatch.STATUS_PROCESSED
                match.processed_at = timezone.now()
                match.save(update_fields=['status', 'processed_at'])

                result = {
                    'match_id': match.pk,
                    'format': 'SINGLES',
                    'player1': {
                        'user_id': p1.pk, 'username': p1.username,
                        'old_rating': old_dupr1, 'new_rating': new_dupr1,
                        'delta': round(new_dupr1 - old_dupr1, 3),
                    },
                    'player2': {
                        'user_id': p2.pk, 'username': p2.username,
                        'old_rating': old_dupr2, 'new_rating': new_dupr2,
                        'delta': round(new_dupr2 - old_dupr2, 3),
                    },
                }

            else:
                # DOUBLES — treat team 1 (p1, p2) vs team 2 (p3, p4)
                # Winner determined by winner_id belonging to p1 or p2
                team1_wins = winner_id in (p1.pk, p2.pk)
                actual_t1 = 1.0 if team1_wins else 0.0
                actual_t2 = 1.0 - actual_t1

                players_team1 = [p1, p2]
                players_team2 = [p3, p4]

                rps_t1 = [_get_or_create_rating(p, sport, org) for p in players_team1]
                rps_t2 = [_get_or_create_rating(p, sport, org) for p in players_team2]

                avg_elo_t1 = sum(dupr_to_elo(float(r.dupr_rating_doubles)) for r in rps_t1) / 2
                avg_elo_t2 = sum(dupr_to_elo(float(r.dupr_rating_doubles)) for r in rps_t2) / 2

                exp_t1 = expected_score(avg_elo_t1, avg_elo_t2)
                exp_t2 = 1.0 - exp_t1

                result_players = []
                for idx, (rp, player, actual, exp) in enumerate([
                    (rps_t1[0], p1, actual_t1, exp_t1),
                    (rps_t1[1], p2, actual_t1, exp_t1),
                    (rps_t2[0], p3, actual_t2, exp_t2),
                    (rps_t2[1], p4, actual_t2, exp_t2),
                ]):
                    old_elo = dupr_to_elo(float(rp.dupr_rating_doubles))
                    k = k_factor(rp.matches_played_doubles, importance)
                    new_elo = old_elo + k * (actual - exp)
                    new_dupr = elo_to_dupr(new_elo)
                    old_dupr = float(rp.dupr_rating_doubles)

                    rp.matches_played_doubles += 1
                    rp.dupr_rating_doubles = new_dupr
                    rp.reliability = reliability_from_matches(rp.matches_played_doubles)
                    rp.last_synced_at = timezone.now()
                    rp.save()

                    RatingAudit.objects.create(
                        match=match, player=player,
                        format=RatingMatch.FORMAT_DOUBLES,
                        old_rating=old_dupr, new_rating=new_dupr,
                        delta=round(new_dupr - old_dupr, 3),
                        method=RatingAudit.METHOD_LIVE,
                        note=f'Match #{match.pk} doubles result',
                    )
                    result_players.append({
                        'user_id': player.pk, 'username': player.username,
                        'old_rating': old_dupr, 'new_rating': new_dupr,
                        'delta': round(new_dupr - old_dupr, 3),
                    })

                match.status = RatingMatch.STATUS_PROCESSED
                match.processed_at = timezone.now()
                match.save(update_fields=['status', 'processed_at'])

                result = {'match_id': match.pk, 'format': 'DOUBLES', 'players': result_players}

        logger.info('MatchSubmitView: match_id=%s processed by coach_id=%s', match.pk, coach.pk)
        return Response(result, status=status.HTTP_201_CREATED)


# ─── ForecastView ─────────────────────────────────────────────────────────────

class ForecastView(APIView):
    """
    POST /api/ratings/forecast/

    Simulate what would happen to two players' ratings if one of them wins.
    NO database writes — pure calculation.

    Payload:
    {
        "player1_id": 5,
        "player2_id": 8,
        "format": "SINGLES",       # SINGLES | DOUBLES
        "importance": "CASUAL"
    }

    Response:
    {
        "player1": {
            "user_id": 5,
            "username": "alice",
            "current_rating": 4.200,
            "if_win":  {"new_rating": 4.250, "delta": +0.050},
            "if_loss": {"new_rating": 4.170, "delta": -0.030}
        },
        "player2": { ... },
        "win_probability_player1": 0.67,   # 0-1
        "win_probability_player2": 0.33
    }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data
        p1_id = data.get('player1_id')
        p2_id = data.get('player2_id')
        fmt = (data.get('format', 'SINGLES') or 'SINGLES').upper()
        importance = (data.get('importance', 'CASUAL') or 'CASUAL').upper()

        if not p1_id or not p2_id:
            return Response({'error': 'player1_id and player2_id required'}, status=status.HTTP_400_BAD_REQUEST)

        from accounts.models import CustomUser
        from organizations.models import Sport
        try:
            p1 = CustomUser.objects.get(pk=p1_id)
            p2 = CustomUser.objects.get(pk=p2_id)
        except CustomUser.DoesNotExist:
            return Response({'error': 'Player not found'}, status=status.HTTP_404_NOT_FOUND)

        # Determine org — use the requesting coach's org
        org = None
        sport = None
        if request.user.user_type == 'COACH' and hasattr(request.user, 'coach_profile'):
            org = request.user.coach_profile.organization
            sport = Sport.objects.filter(organizations=org).order_by('pk').first()

        # Get current ratings (default 4.000 if no profile)
        def get_rating(user):
            if org and sport:
                try:
                    rp = PlayerRatingProfile.objects.get(user=user, organization=org, sport=sport)
                    return (
                        float(rp.dupr_rating_singles) if fmt == 'SINGLES' else float(rp.dupr_rating_doubles),
                        rp.matches_played_singles if fmt == 'SINGLES' else rp.matches_played_doubles,
                    )
                except PlayerRatingProfile.DoesNotExist:
                    pass
            return 4.000, 0

        r1, mp1 = get_rating(p1)
        r2, mp2 = get_rating(p2)

        elo1 = dupr_to_elo(r1)
        elo2 = dupr_to_elo(r2)

        win_prob_1 = expected_score(elo1, elo2)
        win_prob_2 = 1.0 - win_prob_1

        def simulate(current_r, opp_r, mp, actual):
            from ratings.rating import update_one_player
            new_r, delta = update_one_player(current_r, opp_r, actual, mp, importance)
            return {'new_rating': new_r, 'delta': delta}

        p1_if_win  = simulate(r1, r2, mp1, 1.0)
        p1_if_loss = simulate(r1, r2, mp1, 0.0)
        p2_if_win  = simulate(r2, r1, mp2, 1.0)
        p2_if_loss = simulate(r2, r1, mp2, 0.0)

        def name(u):
            full = f'{u.first_name} {u.last_name}'.strip()
            return full if full else u.username

        return Response({
            'format': fmt,
            'importance': importance,
            'win_probability_player1': round(win_prob_1, 3),
            'win_probability_player2': round(win_prob_2, 3),
            'player1': {
                'user_id': p1.pk,
                'username': p1.username,
                'display_name': name(p1),
                'current_rating': r1,
                'if_win': p1_if_win,
                'if_loss': p1_if_loss,
            },
            'player2': {
                'user_id': p2.pk,
                'username': p2.username,
                'display_name': name(p2),
                'current_rating': r2,
                'if_win': p2_if_win,
                'if_loss': p2_if_loss,
            },
        }, status=status.HTTP_200_OK)


# ─── PlayerAuditHistoryView ───────────────────────────────────────────────────

class PlayerAuditHistoryView(APIView):
    """
    GET /api/ratings/my-history/

    Returns the last 30 rating audit entries for the authenticated user.
    Used by student profile screen to show recent rating changes.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        entries = (
            RatingAudit.objects
            .filter(player=request.user, rolled_back=False)
            .select_related('match')
            .order_by('-created_at')[:30]
        )

        data = []
        for e in entries:
            data.append({
                'id': e.pk,
                'format': e.format,
                'old_rating': float(e.old_rating),
                'new_rating': float(e.new_rating),
                'delta': float(e.delta),
                'method': e.method,
                'date': e.created_at.date().isoformat(),
                'match_id': e.match_id,
                'note': e.note,
            })

        return Response(data, status=status.HTTP_200_OK)


# ─── MatchListView ────────────────────────────────────────────────────────────

class MatchListView(APIView):
    """
    GET /api/ratings/matches/

    Returns matches submitted by this coach, most recent first.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        coach, err = _coach_or_403(request.user)
        if err:
            return err

        matches = (
            RatingMatch.objects
            .filter(submitted_by=request.user)
            .select_related('sport')
            .order_by('-date', '-created_at')[:50]
        )

        data = []
        for m in matches:
            data.append({
                'match_id': m.pk,
                'sport': m.sport.name,
                'date': m.date.isoformat(),
                'format': m.format,
                'importance': m.importance,
                'status': m.status,
                'participants': m.participants,
                'score': m.score,
                'processed_at': m.processed_at.isoformat() if m.processed_at else None,
            })

        return Response(data, status=status.HTTP_200_OK)
