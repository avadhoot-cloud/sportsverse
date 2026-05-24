from rest_framework import status, views
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import CoachProfile, CoachAssignment
from organizations.models import Batch, Branch, Sport, Organization
from django.contrib.auth import get_user_model

User = get_user_model()

class CoachEnrollmentView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data
        try:
            user = User.objects.create_user(
                username=data['email'],
                email=data['email'],
                password=data['password'],
                first_name=data['first_name'],
                last_name=data['last_name'],
                user_type='COACH'
            )
            
            org = request.user.academy_admin_profile.organization

            CoachProfile.objects.create(
                user=user,
                organization=org,
                phone_number=data['phone']
            )
            return Response({"message": "Coach enrolled successfully"}, status=201)
        except Exception as e:
            return Response({"error": str(e)}, status=400)

class CoachListView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        org = request.user.academy_admin_profile.organization
        coaches = CoachProfile.objects.filter(organization=org).prefetch_related(
            'assignments__batch', 'assignments__branch', 'assignments__sport'
        )
        data = []
        for c in coaches:
            assignments = [
                {
                    'id': a.id,
                    'batch_id': a.batch_id,
                    'batch_name': a.batch.name,
                    'branch_name': a.branch.name,
                    'sport_name': a.sport.name,
                }
                for a in c.assignments.all()
            ]
            data.append({
                'id': c.id,
                'full_name': f"{c.user.first_name} {c.user.last_name}",
                'email': c.user.email,
                'phone': c.phone_number,
                'assignments': assignments,
            })
        return Response(data)


class CoachAssignmentDeleteView(views.APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, assignment_id):
        org = request.user.academy_admin_profile.organization
        assignment = CoachAssignment.objects.filter(
            pk=assignment_id,
            coach__organization=org,
        ).first()
        if not assignment:
            return Response({'error': 'Assignment not found'}, status=404)
        assignment.delete()
        return Response({'message': 'Coach assignment removed'}, status=200)
    
class CoachAssignmentView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            org = request.user.academy_admin_profile.organization
            branches = Branch.objects.filter(organization=org)
            coaches = CoachProfile.objects.filter(organization=org)
            sports = Sport.objects.filter(organizations=org).distinct()
            
            data = {
                "branches": [{"id": b.id, "name": b.name} for b in branches],
                "sports": [{"id": s.id, "name": s.name} for s in sports],
                "coaches": [{"id": c.id, "name": c.user.get_full_name} for c in coaches],
            }
            return Response(data, status=200)
        except Exception as e:
            return Response({"error": str(e)}, status=400)

    # ADD THIS POST METHOD TO FIX THE 405 ERROR
    def post(self, request):
        try:
            data = request.data
            # We create the assignment using the IDs sent from Flutter
            assignment = CoachAssignment.objects.create(
                coach_id=data.get('coach_id'),
                branch_id=data.get('branch_id'),
                sport_id=data.get('sport_id'),
                batch_id=data.get('batch_id')
            )
            return Response({"message": "Coach assigned successfully!"}, status=201)
        except Exception as e:
            print(f"POST ERROR: {str(e)}")
            return Response({"error": str(e)}, status=400)

class BatchLookupView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            branch_id = request.query_params.get('branch_id')
            sport_id = request.query_params.get('sport_id')
            org = request.user.academy_admin_profile.organization
            
            # Filter batches by branch, sport, and organization
            batches = Batch.objects.filter(
                branch_id=branch_id, 
                sport_id=sport_id,
                organization=org
            )

            data = [{"id": b.id, "name": b.name} for b in batches]
            return Response(data, status=200)
        except Exception as e:
            return Response({"error": str(e)}, status=400)