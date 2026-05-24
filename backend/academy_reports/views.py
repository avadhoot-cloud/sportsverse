from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from .models import PlayerReport


def _parse_student_ids(raw_value):
    if raw_value is None:
        return []
    if isinstance(raw_value, list):
        return [str(item).strip() for item in raw_value if str(item).strip()]
    return [part.strip() for part in str(raw_value).split(',') if part.strip()]


class ReportUploadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not hasattr(request.user, 'academy_admin_profile'):
            return Response({'detail': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        try:
            organization = request.user.academy_admin_profile.organization
            title = request.data.get('title')
            branch_id = request.data.get('branch')
            batch_id = request.data.get('batch')
            student_ids = _parse_student_ids(request.data.get('student_ids'))
            report_file = request.FILES.get('report_file')

            if not all([title, branch_id, batch_id, student_ids, report_file]):
                return Response(
                    {'error': 'title, branch, batch, student_ids, and report_file are required'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            try:
                student_pks = [int(sid) for sid in student_ids]
            except (TypeError, ValueError):
                return Response({'error': 'Invalid student_ids format'}, status=400)

            from organizations.models import Branch, Batch
            branch = Branch.objects.filter(pk=branch_id, organization=organization).first()
            batch = Batch.objects.filter(pk=batch_id, organization=organization).first()
            if not branch or not batch:
                return Response({'error': 'Invalid branch or batch for your organization'}, status=400)

            report = PlayerReport.objects.create(
                title=title,
                branch_id=branch_id,
                batch_id=batch_id,
                report_file=report_file,
            )
            report.students.set(student_pks)

            return Response({'message': 'Report uploaded successfully'}, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
