from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import PlayerReport

class ReportUploadView(APIView):
    def post(self, request):
        try:
            title = request.data.get('title')
            branch_id = request.data.get('branch')
            batch_id = request.data.get('batch')
            student_ids = request.data.get('student_ids').split(',')
            report_file = request.FILES.get('report_file')

            report = PlayerReport.objects.create(
                title=title,
                branch_id=branch_id,
                batch_id=batch_id,
                report_file=report_file
            )
            report.students.set(student_ids)
            report.save()

            return Response({"message": "Report uploaded successfully"}, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)