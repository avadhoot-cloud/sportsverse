# backend/api/ai_utils.py
"""
AI Chatbot utilities for SportsVerse Academy Management.
Priority: Gemini AI with tool calling → Fallback to keyword-matched predefined Q&A
"""

import os
import re
import logging
from datetime import date
from django.conf import settings

logger = logging.getLogger(__name__)

_FIELD_PREFIXES = (
    'id:', 'patterns:', 'answer_template:', 'requires_db:',
    'db_query_key:', 'action_type:', 'action_params:', 'category:',
)


def _get_gemini_client():
    """Initialize Gemini only when needed."""
    try:
        import google.generativeai as genai
        api_key = getattr(settings, 'GEMINI_API_KEY', None) or os.getenv('GEMINI_API_KEY')
        if not api_key:
            return None
        genai.configure(api_key=api_key)
        return genai
    except Exception as e:
        logger.warning(f"Gemini init failed: {e}")
        return None


def _get_db_data(query_key: str, organization_id: int) -> dict:
    """Fetch live data from DB based on query_key."""
    from accounts.models import StudentProfile
    from coaches.models import CoachProfile
    from organizations.models import Branch, Batch, Enrollment, Attendance
    from payments.models import FeeTransaction
    from django.db.models import Sum

    data = {}

    try:
        if query_key in ('dashboard_stats', 'student_count', 'coach_count', 'branch_count', 'batch_count'):
            data['total_students'] = StudentProfile.objects.filter(organization_id=organization_id).count()
            data['total_coaches'] = CoachProfile.objects.filter(organization_id=organization_id).count()
            data['total_branches'] = Branch.objects.filter(organization_id=organization_id).count()
            data['total_batches'] = Batch.objects.filter(organization_id=organization_id, is_active=True).count()

        elif query_key == 'avadhoot_attendance':
            student = StudentProfile.objects.filter(
                organization_id=organization_id,
                user__username='avadhoot_student',
            ).first()
            if student:
                enrollment = Enrollment.objects.filter(student=student, is_active=True).first()
                if enrollment:
                    data['sessions_attended'] = enrollment.sessions_attended or 0
                    data['total_sessions'] = enrollment.total_sessions or 'N/A (Duration-based)'
                    data['enrollment_status'] = 'Active' if enrollment.enrollment_started else 'Not Started'
                    data['enrollment_started'] = 'Yes' if enrollment.enrollment_started else 'No'
                else:
                    data['sessions_attended'] = 0
                    data['total_sessions'] = 'No enrollment'
                    data['enrollment_status'] = 'Not enrolled'
                    data['enrollment_started'] = 'No'
            else:
                data['sessions_attended'] = 'N/A'
                data['total_sessions'] = 'N/A'
                data['enrollment_status'] = 'Student not found'
                data['enrollment_started'] = 'No'

        elif query_key == 'avadhoot_profile':
            student = StudentProfile.objects.filter(
                organization_id=organization_id,
                user__username='avadhoot_student',
            ).select_related('user').first()
            if student:
                enrollment = Enrollment.objects.filter(
                    student=student, is_active=True,
                ).select_related('batch').first()
                data['batch_name'] = enrollment.batch.name if enrollment else 'No active batch'
            else:
                data['batch_name'] = 'Not found in this org'

        elif query_key == 'mark_attendance_avadhoot':
            student = StudentProfile.objects.filter(
                organization_id=organization_id,
                user__username='avadhoot_student',
            ).first()
            data['today_date'] = str(date.today())
            data['already_marked'] = False
            if student:
                enrollment = Enrollment.objects.filter(student=student, is_active=True).first()
                if enrollment:
                    today = date.today()
                    _, created = Attendance.objects.get_or_create(
                        enrollment=enrollment,
                        date=today,
                        defaults={
                            'batch': enrollment.batch,
                            'student': student,
                            'organization_id': organization_id,
                        },
                    )
                    data['already_marked'] = not created

        elif query_key == 'recent_payments':
            payments = FeeTransaction.objects.filter(
                organization_id=organization_id, is_paid=True,
            ).select_related('student').order_by('-paid_date', '-transaction_date')[:5]
            items = []
            for p in payments:
                items.append(f"₹{p.amount} from {p.student.first_name} {p.student.last_name}")
            data['recent_payments_list'] = ', '.join(items) if items else 'No recent payments'

        elif query_key == 'unpaid_fees':
            unpaid = FeeTransaction.objects.filter(organization_id=organization_id, is_paid=False)
            total = unpaid.aggregate(t=Sum('amount'))['t'] or 0
            data['unpaid_count'] = unpaid.count()
            data['unpaid_amount'] = float(total)
            student_names = list(
                unpaid.select_related('student')
                .values_list('student__first_name', flat=True)
                .distinct()[:5]
            )
            data['unpaid_students_list'] = ', '.join(student_names) if student_names else 'None'

        elif query_key == 'list_students':
            qs = StudentProfile.objects.filter(organization_id=organization_id)
            data['total_students'] = qs.count()
            students = qs[:10]
            data['students_list'] = ', '.join([f"{s.first_name} {s.last_name}" for s in students])

        elif query_key == 'list_coaches':
            coaches = CoachProfile.objects.filter(organization_id=organization_id).select_related('user')
            data['total_coaches'] = coaches.count()
            names = []
            for c in coaches:
                if c.user:
                    names.append(f"{c.user.first_name} {c.user.last_name}".strip())
            data['coaches_list'] = ', '.join(names) if names else 'None'

        elif query_key == 'list_branches':
            branches = Branch.objects.filter(organization_id=organization_id)
            data['branches_list'] = ', '.join([b.name for b in branches]) or 'None'

        elif query_key == 'list_batches':
            batches = Batch.objects.filter(organization_id=organization_id, is_active=True)
            data['batches_list'] = ', '.join([b.name for b in batches]) or 'None'

        elif query_key == 'financial_summary':
            paid = FeeTransaction.objects.filter(
                organization_id=organization_id, is_paid=True,
            ).aggregate(t=Sum('amount'))['t'] or 0
            due = FeeTransaction.objects.filter(
                organization_id=organization_id, is_paid=False,
            ).aggregate(t=Sum('amount'))['t'] or 0
            data['total_income'] = float(paid)
            data['total_due'] = float(due)
            data['total_expense'] = 0
            data['total_profit'] = float(paid)
            data['online_pct'] = 60
            data['cash_pct'] = 40

        elif query_key == 'enrollment_stats':
            enrollments = Enrollment.objects.filter(organization_id=organization_id, is_active=True)
            data['active_enrollments'] = enrollments.count()
            data['session_based_count'] = enrollments.filter(enrollment_type='SESSION_BASED').count()
            data['duration_based_count'] = enrollments.filter(enrollment_type='DURATION_BASED').count()

    except Exception as e:
        logger.error(f"DB fetch error for key={query_key}: {e}")

    data.setdefault('today_date', str(date.today()))
    return data


def _load_knowledge_base() -> list:
    """Load predefined Q&A from chatbot_knowledge.txt at project root."""
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    kb_path = os.path.join(root, 'chatbot_knowledge.txt')
    entries = []

    if not os.path.exists(kb_path):
        logger.warning(f"chatbot_knowledge.txt not found at {kb_path}")
        return entries

    try:
        with open(kb_path, 'r', encoding='utf-8') as f:
            content = f.read()

        blocks = content.split('---ENTRY---')
        for block in blocks:
            block = block.strip()
            if not block or block.startswith('===') or 'patterns:' not in block:
                continue

            entry = {}
            lines = block.split('\n')
            i = 0
            while i < len(lines):
                line = lines[i].strip()
                if line.startswith('id:'):
                    entry['id'] = line.replace('id:', '').strip()
                elif line.startswith('patterns:'):
                    pats = []
                    i += 1
                    while i < len(lines):
                        pline = lines[i].strip()
                        if not pline:
                            i += 1
                            continue
                        if any(pline.startswith(prefix) for prefix in _FIELD_PREFIXES):
                            break
                        pats.append(pline)
                        i += 1
                    entry['patterns'] = pats
                    continue
                elif line.startswith('answer_template:'):
                    entry['answer_template'] = line.replace('answer_template:', '').strip().strip('"')
                elif line.startswith('requires_db:'):
                    entry['requires_db'] = 'true' in line.lower()
                elif line.startswith('db_query_key:'):
                    entry['db_query_key'] = line.replace('db_query_key:', '').strip()
                elif line.startswith('action_type:'):
                    entry['action_type'] = line.replace('action_type:', '').strip()
                i += 1

            if 'id' in entry and 'patterns' in entry:
                entries.append(entry)

    except Exception as e:
        logger.error(f"Error loading knowledge base: {e}")

    return entries


def _match_knowledge(user_text: str, entries: list) -> dict | None:
    """Find best matching knowledge entry using keyword overlap."""
    cleaned = re.sub(r'[^\w\s]', '', user_text.lower().strip())
    words = set(cleaned.split())

    best_match = None
    best_score = 0

    for entry in entries:
        for pattern in entry.get('patterns', []):
            pattern_clean = re.sub(r'[^\w\s]', '', pattern.lower().strip())
            if pattern_clean in cleaned:
                score = len(pattern_clean.split()) + 10
                if score > best_score:
                    best_score = score
                    best_match = entry
                continue

            p_words = set(pattern_clean.split())
            overlap = len(words & p_words)
            if overlap > best_score and overlap >= 1:
                if any(pw in cleaned for pw in p_words if len(pw) > 3):
                    best_score = overlap
                    best_match = entry

    return best_match if best_score >= 1 else None


def _fill_template(template: str, data: dict) -> str:
    """Fill answer template with DB data."""
    try:
        for key, value in data.items():
            template = template.replace('{' + key + '}', str(value))
    except Exception as e:
        logger.error(f"Template fill error: {e}")
    return template


def _build_gemini_tools(organization_id: int, organization_name: str):
    """Build secure tool functions for Gemini tool-calling."""
    from accounts.models import StudentProfile
    from coaches.models import CoachProfile
    from organizations.models import Branch, Batch, Enrollment, Attendance
    from payments.models import FeeTransaction
    from django.db.models import Sum, Q

    def get_student_count() -> str:
        """Returns total number of enrolled students in the academy."""
        count = StudentProfile.objects.filter(organization_id=organization_id).count()
        return f"There are {count} students in {organization_name}."

    def get_coach_count() -> str:
        """Returns total number of coaches in the academy."""
        count = CoachProfile.objects.filter(organization_id=organization_id).count()
        return f"There are {count} coaches in {organization_name}."

    def get_branch_count() -> str:
        """Returns total number of branches in the academy."""
        count = Branch.objects.filter(organization_id=organization_id).count()
        return f"There are {count} branches in {organization_name}."

    def get_batch_count() -> str:
        """Returns total number of active batches in the academy."""
        count = Batch.objects.filter(organization_id=organization_id, is_active=True).count()
        return f"There are {count} active batches in {organization_name}."

    def get_dashboard_summary() -> str:
        """Returns a full academy dashboard summary with all key statistics."""
        students = StudentProfile.objects.filter(organization_id=organization_id).count()
        coaches = CoachProfile.objects.filter(organization_id=organization_id).count()
        branches = Branch.objects.filter(organization_id=organization_id).count()
        batches = Batch.objects.filter(organization_id=organization_id, is_active=True).count()
        return (
            f"Dashboard Summary for {organization_name}: "
            f"{students} students, {coaches} coaches, {branches} branches, {batches} batches."
        )

    def get_recent_payments(limit: int = 5) -> str:
        """Returns the latest fee payments collected in the academy."""
        payments = FeeTransaction.objects.filter(
            organization_id=organization_id, is_paid=True,
        ).select_related('student').order_by('-paid_date', '-transaction_date')[:limit]
        if not payments.exists():
            return "No recent payments found."
        result = "Recent payments:\n"
        for p in payments:
            result += f"- ₹{p.amount} from {p.student.first_name} {p.student.last_name}\n"
        return result

    def get_student_attendance(student_name: str) -> str:
        """Returns attendance information for a specific student by name or username."""
        name_parts = student_name.lower().split()
        q = Q(user__username__icontains=student_name)
        if name_parts:
            q |= Q(first_name__icontains=name_parts[0])
            if len(name_parts) > 1:
                q |= Q(last_name__icontains=name_parts[-1])

        students = StudentProfile.objects.filter(
            organization_id=organization_id,
        ).filter(q).select_related('user')[:3]

        if not students:
            return f"No student found with name '{student_name}'."

        results = []
        for student in students:
            enrollment = Enrollment.objects.filter(student=student, is_active=True).first()
            if enrollment:
                results.append(
                    f"{student.first_name} {student.last_name}: "
                    f"{enrollment.sessions_attended} sessions attended, "
                    f"status: {'Active' if enrollment.enrollment_started else 'Not Started'}"
                )
            else:
                results.append(f"{student.first_name} {student.last_name}: No active enrollment")
        return "\n".join(results)

    def get_pending_fees() -> str:
        """Returns count and total of pending/unpaid fee transactions."""
        unpaid = FeeTransaction.objects.filter(organization_id=organization_id, is_paid=False)
        total = unpaid.aggregate(t=Sum('amount'))['t'] or 0
        count = unpaid.count()
        return f"Pending fees: {count} transactions, total ₹{total:.2f}"

    def list_all_students() -> str:
        """Returns a list of all student names in the academy."""
        students = StudentProfile.objects.filter(organization_id=organization_id)[:15]
        names = [f"{s.first_name} {s.last_name}" for s in students]
        return f"Students ({len(names)}): {', '.join(names)}"

    def list_all_coaches() -> str:
        """Returns a list of all coach names in the academy."""
        coaches = CoachProfile.objects.filter(organization_id=organization_id).select_related('user')
        names = [f"{c.user.first_name} {c.user.last_name}" for c in coaches if c.user]
        return f"Coaches ({len(names)}): {', '.join(names)}"

    def list_all_batches() -> str:
        """Returns a list of all active batch names in the academy."""
        batches = Batch.objects.filter(organization_id=organization_id, is_active=True)
        names = [b.name for b in batches]
        return f"Active batches ({len(names)}): {', '.join(names)}"

    def list_all_branches() -> str:
        """Returns a list of all branch names in the academy."""
        branches = Branch.objects.filter(organization_id=organization_id)
        names = [b.name for b in branches]
        return f"Branches ({len(names)}): {', '.join(names)}"

    def mark_attendance_for_student(student_username: str) -> str:
        """Marks today's attendance for a student by username. Returns success or failure."""
        student = StudentProfile.objects.filter(
            organization_id=organization_id,
            user__username=student_username,
        ).first()
        if not student:
            return f"Student with username '{student_username}' not found."
        enrollment = Enrollment.objects.filter(student=student, is_active=True).first()
        if not enrollment:
            return f"{student.first_name} {student.last_name} has no active enrollment."
        today = date.today()
        _, created = Attendance.objects.get_or_create(
            enrollment=enrollment,
            date=today,
            defaults={
                'batch': enrollment.batch,
                'student': student,
                'organization_id': organization_id,
            },
        )
        if created:
            return f"✅ Attendance marked for {student.first_name} {student.last_name} on {today}."
        return f"⚠️ Attendance was already marked for {student.first_name} {student.last_name} today."

    def get_financial_summary() -> str:
        """Returns the financial summary including income, due amounts for the academy."""
        paid = FeeTransaction.objects.filter(
            organization_id=organization_id, is_paid=True,
        ).aggregate(t=Sum('amount'))['t'] or 0
        due = FeeTransaction.objects.filter(
            organization_id=organization_id, is_paid=False,
        ).aggregate(t=Sum('amount'))['t'] or 0
        return (
            f"Financial summary for {organization_name}: "
            f"Total collected: ₹{float(paid):.2f}, Total pending: ₹{float(due):.2f}"
        )

    return [
        get_student_count, get_coach_count, get_branch_count, get_batch_count,
        get_dashboard_summary, get_recent_payments, get_student_attendance,
        get_pending_fees, list_all_students, list_all_coaches, list_all_batches,
        list_all_branches, mark_attendance_for_student, get_financial_summary,
    ]


def process_bot_request(user_text: str, organization_id: int, organization_name: str) -> str:
    """
    Main function. Tries Gemini first, falls back to predefined Q&A.
    """
    try:
        genai = _get_gemini_client()
        if genai:
            tools = _build_gemini_tools(organization_id, organization_name)
            model = genai.GenerativeModel(
                model_name='gemini-1.5-flash',
                tools=tools,
                system_instruction=(
                    f"You are the official AI assistant for {organization_name} sports academy. "
                    "Use the provided tools to answer questions about the academy's students, "
                    "coaches, attendance, fees, and other data. "
                    "Be concise, helpful, and professional. "
                    "For attendance marking or fee collection, use the appropriate tools. "
                    "If asked to mark attendance, do it directly using mark_attendance_for_student."
                ),
            )
            chat = model.start_chat(enable_automatic_function_calling=True)
            response = chat.send_message(user_text)
            if response.text and len(response.text.strip()) > 5:
                logger.info(f"Gemini responded successfully for org {organization_id}")
                return response.text
    except Exception as e:
        logger.warning(f"Gemini failed, using fallback: {e}")

    return _fallback_response(user_text, organization_id, organization_name)


def _fallback_response(user_text: str, organization_id: int, organization_name: str) -> str:
    """Keyword-matched fallback using chatbot_knowledge.txt."""
    entries = _load_knowledge_base()
    match = _match_knowledge(user_text, entries)

    if match:
        template = match.get('answer_template', 'I found a match but no answer template.')
        db_data = {}
        if match.get('requires_db') and match.get('db_query_key'):
            db_data = _get_db_data(match['db_query_key'], organization_id)
            if match.get('db_query_key') == 'mark_attendance_avadhoot' and db_data.get('already_marked'):
                return (
                    f"⚠️ Attendance was already marked for Avadhoot Student today "
                    f"({db_data.get('today_date')})."
                )
            template = _fill_template(template, db_data)
        return template

    return (
        f"I'm your assistant for {organization_name}. "
        "I can help with: dashboard stats, student attendance, coach info, "
        "fee summaries, batch/branch info, and marking attendance. "
        "Try asking: 'show dashboard stats', 'avadhoot attendance', 'list students', "
        "'show unpaid fees', or 'mark attendance for avadhoot'."
    )
