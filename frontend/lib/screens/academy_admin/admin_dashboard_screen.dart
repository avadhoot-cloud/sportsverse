import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:sportsverse_app/screens/academy_admin/mark_attendence.dart';
import 'package:sportsverse_app/widgets/ai_bot_sheet.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/api/payment_api.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';
import 'package:sportsverse_app/providers/admin_provider.dart'; 
import 'package:sportsverse_app/screens/academy_admin/student_payment_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/pay_salary_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/salary_details_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/branch_management_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/batch_management_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/add_student_enrollment_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/student_management_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/admin_face_attendance_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/view_attendance_screen.dart';
import 'package:sportsverse_app/screens/coaches/assign_coach.dart';
import 'package:sportsverse_app/screens/coaches/coach_enroll_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/view_students_screen.dart';
import 'package:sportsverse_app/screens/coaches/coach_list_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/send_video_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/player_report_screen.dart';
import 'package:sportsverse_app/widgets/financial_chart.dart';

import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_card.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';
import 'package:sportsverse_app/widgets/performance_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  List expenses = [];
  bool isLoadingExpenses = true;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final titleController = TextEditingController();
  final amountController = TextEditingController();

  bool _isCoachesExpanded = false;
  bool _isStudentsExpanded = false;
  bool _isAttendanceExpanded = false;
  bool _isPaymentsExpanded = false;
  bool _isStaffExpanded = false;
  bool _isVideosExpanded = false;
  
  Map<String, dynamic>? _analyticsData;
  bool _isChartLoading = false;
  

  Widget? _currentContent;
  late final PaymentApi _paymentApi;

  @override
  void initState() {
    super.initState();
    _paymentApi = PaymentApi(apiClient);
    _loadAnalytics();
    fetchExpenses();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchExpenses() async {
    setState(() {
      isLoadingExpenses = true;
    });

    try {
      final response = await apiClient.get("/api/payments/expenses/");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          expenses = data;
          isLoadingExpenses = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          isLoadingExpenses = false;
          expenses = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingExpenses = false;
        expenses = [];
      });
    }
  }

  Future<void> addExpense() async {
    final res = await apiClient.post(
      '/api/payments/add-expense/',
      {
        "title": titleController.text,
        "amount": amountController.text,
      },
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      if (!mounted) return;
      Navigator.pop(context);
      fetchExpenses();
    }
  }

  void showAddExpenseDialog() {
    titleController.clear();
    amountController.clear();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: addExpense,
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() {
      _isChartLoading = true;
    });

    try {
      final response = await apiClient.get("/api/payments/dashboard/analytics/");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (!mounted) return;
          setState(() {
            _analyticsData = data;
            _isChartLoading = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _analyticsData = null;
            _isChartLoading = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _analyticsData = null;
          _isChartLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyticsData = null;
        _isChartLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    try {
      final response = await apiClient.get('/api/accounts/dashboard-stats/');
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
    return {'total_students': 0, 'total_coaches': 0, 'total_branches': 0, 'total_batches': 0};
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final profile = authProvider.profileDetails;
    final theme = EliteTheme.of(context);

    return Builder(
      builder: (innerContext) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 900;

            return Scaffold(
              backgroundColor: theme.surface,
              drawer: isDesktop ? null : _buildSidebar(innerContext, theme),
              appBar: isDesktop ? null : _buildMobileAppBar(innerContext, authProvider, theme),
              floatingActionButton: ScaleTransition(
                scale: _scaleAnimation,
                child: FloatingActionButton(
                  backgroundColor: theme.accent, // Lime!
                  child: Icon(Icons.smart_toy, color: theme.primary),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => const AIBotSheet(),
                    );
                  },
                ),
              ),
              body: Row(
                children: [
                  if (isDesktop) _buildSidebar(innerContext, theme),
                  Expanded(
                    child: Column(
                      children: [
                        if (isDesktop) _buildTopHeader(innerContext, authProvider, theme),
                        Expanded(
                          child: _currentContent ?? FutureBuilder<Map<String, dynamic>>(
                            future: _fetchStats(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(child: CircularProgressIndicator(color: theme.primary));
                              }

                              if (snapshot.hasError) {
                                return Center(child: Text("Error loading data", style: theme.body));
                              }

                              final stats = snapshot.data ?? {
                                'total_students': 0,
                                'total_coaches': 0,
                                'total_branches': 0,
                                'total_batches': 0
                              };

                              return RefreshIndicator(
                                color: theme.primary,
                                backgroundColor: theme.surfaceContainerLowest,
                                onRefresh: () async {
                                  await _loadAnalytics();
                                  if (!mounted) return;
                                  setState(() {});
                                },
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.all(isDesktop ? 32 : 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildTopFinancialSummary(constraints.maxWidth, theme),
                                      const SizedBox(height: 24),

                                      _buildAnalyticsDashboardContainer(theme),
                                      const SizedBox(height: 32),
                                      
                                      /// 💸 EXPENSE SECTION
                                      EliteCard(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text("Expenses", style: theme.display2),
                                                ElevatedButton.icon(
                                                  onPressed: showAddExpenseDialog,
                                                  icon: const Icon(Icons.add, size: 18),
                                                  label: const Text("Add"),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: theme.primary,
                                                    foregroundColor: theme.surfaceContainerLowest,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            isLoadingExpenses
                                                ? Center(child: CircularProgressIndicator(color: theme.primary))
                                                : expenses.isEmpty
                                                    ? Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                                      child: Text("No expenses added", style: theme.body.copyWith(color: theme.secondaryText)),
                                                    )
                                                    : ListView.builder(
                                                        shrinkWrap: true,
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: expenses.length,
                                                        itemBuilder: (context, index) {
                                                          final e = expenses[index];
                                                          return ListTile(
                                                            contentPadding: EdgeInsets.zero,
                                                            leading: Container(
                                                              padding: const EdgeInsets.all(10),
                                                              decoration: BoxDecoration(
                                                                color: theme.accent.withValues(alpha: 0.2),
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              child: Icon(
                                                                e['type'] == "Salary" ? Icons.person : Icons.receipt,
                                                                color: theme.primary,
                                                                size: 20,
                                                              ),
                                                            ),
                                                            title: Text(e['title'], style: theme.heading),
                                                            subtitle: Text(e['type'], style: theme.caption.copyWith(color: theme.secondaryText)),
                                                            trailing: Text("₹${e['amount']}", style: theme.subtitle.copyWith(color: theme.primary)),
                                                          );
                                                        },
                                                      ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 32),

                                      _buildWelcomeBanner(user, profile, isDesktop, theme),
                                      const SizedBox(height: 32),

                                      _buildStatsGrid({
                                        'total_students': stats['total_students'] ?? 0,
                                        'total_coaches': stats['total_coaches'] ?? 0,
                                        'total_branches': stats['total_branches'] ?? 0,
                                        'total_batches': stats['total_batches'] ?? 0,
                                      }, false, constraints.maxWidth, theme),

                                      const SizedBox(height: 32),
                                      Text('Quick Actions', style: theme.display2),
                                      const SizedBox(height: 16),

                                      _buildManagementGrid(innerContext, constraints.maxWidth, theme),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopFinancialSummary(double maxWidth, EliteTheme theme) {
    final summary = _analyticsData?['summary'] ?? {
      'total_income': 0,
      'total_expense': 0,
      'total_profit': 0,
    };
    int crossAxisCount = maxWidth > 1200 ? 3 : 1;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: maxWidth > 1200 ? 4 : 2.5,
      children: [
        _buildStatCardTop('₹${summary['total_income']}', 'Total Income', Icons.account_balance_wallet, theme.accent, theme),
        _buildStatCardTop('₹${summary['total_expense']}', 'Total Expenses', Icons.credit_card, theme.error, theme),
        _buildStatCardTop('₹${summary['total_profit']}', 'Total Profit', Icons.trending_up, theme.primary, theme),
      ],
    );
  }

  Widget _buildStatCardTop(String value, String title, IconData icon, Color color, EliteTheme theme) {
    return EliteCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: theme.display2),
                ),
                Text(title, style: theme.caption.copyWith(color: theme.secondaryText)),
              ]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsDashboardContainer(EliteTheme theme) {
    return EliteCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
            ),
            child: Text('Analytics Dashboard', style: theme.heading.copyWith(color: theme.surfaceContainerLowest)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date Range', style: theme.heading),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                      border: Border.all(color: theme.surfaceContainer),
                      borderRadius: BorderRadius.circular(12)),
                  child: DropdownButton<String>(
                    value: 'This Year',
                    underline: const SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down, color: theme.primary),
                    items: ['This Year']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: theme.body)))
                        .toList(),
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: 24),
                _isChartLoading
                    ? Center(child: CircularProgressIndicator(color: theme.primary))
                    : (_analyticsData == null)
                        ? Center(child: Text("No Analytics Data", style: theme.body))
                        : FinancialDashboardChart(
                            analytics: _analyticsData!,
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, AuthProvider auth, EliteTheme theme) {
    return GlassHeader(
      title: 'Admin Dashboard',
      useNavyStyle: true,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Icon(Icons.menu, color: theme.surfaceContainerLowest),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: () => auth.logout()),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, EliteTheme theme) {
    return Container(
      width: 280,
      color: theme.primary, // Navy
      child: ListView(
        children: [
          const SizedBox(height: 40),
          _buildLogo(theme),
          _sidebarItem(theme, Icons.dashboard, 'Dashboard', isSelected: _currentContent == null, onTap: () {
            setState(() => _currentContent = null);
            if (Scaffold.maybeOf(context)?.hasDrawer ?? false) Navigator.pop(context);
          }),
          
          _buildExpansionTile(
            theme: theme,
            title: 'Coaches',
            icon: Icons.psychology,
            isExpanded: _isCoachesExpanded,
            onExpansionChanged: (val) => setState(() => _isCoachesExpanded = val),
            children: [
              _sidebarSubItem(theme, context, 'Enrolled Coaches', Icons.view_list, () => setState(() => _currentContent = const CoachListScreen())),
              _sidebarSubItem(theme, context, 'Enroll Coach', Icons.person_add, () => setState(() => _currentContent = CoachEnrollScreen(onSuccess: () => setState(() => _currentContent = null)))),
              _sidebarSubItem(theme, context, 'Assign Coach', Icons.assignment_ind, () => setState(() => _currentContent = AssignCoachScreen(onSuccess: () => setState(() => _currentContent = null)))),
            ],
          ),

          _buildExpansionTile(
            theme: theme,
            title: 'Students',
            icon: Icons.school,
            isExpanded: _isStudentsExpanded,
            onExpansionChanged: (val) => setState(() => _isStudentsExpanded = val),
            children: [
              _sidebarSubItem(theme, context, 'View Students', Icons.visibility_outlined, () {
                setState(() => _currentContent = ChangeNotifierProvider(create: (context) => AdminProvider(), child: const ViewStudentsScreen()));
              }),
              _sidebarSubItem(theme, context, 'Enroll Student', Icons.add_circle_outline, () => setState(() => _currentContent = AddStudentEnrollmentScreen(onSuccess: () => setState(() => _currentContent = null)))),
            ],
          ),

          _buildExpansionTile(
            theme: theme,
            title: 'Attendance',
            icon: Icons.how_to_reg,
            isExpanded: _isAttendanceExpanded,
            onExpansionChanged: (val) => setState(() => _isAttendanceExpanded = val),
            children: [
              _sidebarSubItem(theme, context, 'Face Attendance', Icons.face, () => setState(() => _currentContent = const AdminFaceAttendanceScreen())),
              _sidebarSubItem(theme, context, 'Mark Attendance', Icons.check_circle_outline, () => setState(() => _currentContent = const MarkAttendanceScreen())),
              _sidebarSubItem(theme, context, 'View Attendance', Icons.calendar_month, () => setState(() => _currentContent = const ViewAttendanceScreen())),
            ],
          ),

          _buildExpansionTile(
            theme: theme,
            title: 'Payments',
            icon: Icons.payments,
            isExpanded: _isPaymentsExpanded,
            onExpansionChanged: (val) => setState(() => _isPaymentsExpanded = val),
            children: [
              _sidebarSubItem(theme, context, 'Student Payments', Icons.monetization_on, () => setState(() => _currentContent = const StudentPaymentScreen())),
              _sidebarSubItem(theme, context, 'Pay Salaries', Icons.account_balance_wallet, () => setState(() => _currentContent = const PaySalaryScreen())),
              _sidebarSubItem(theme, context, 'Salary History', Icons.history, () => setState(() => _currentContent = const SalaryDetailsScreen())),
            ],
          ),

          _buildExpansionTile(
            theme: theme,
            title: 'Organization',
            icon: Icons.business,
            isExpanded: _isStaffExpanded,
            onExpansionChanged: (val) => setState(() => _isStaffExpanded = val),
            children: [
              _sidebarSubItem(theme, context, 'Branch Management', Icons.location_city, () => setState(() => _currentContent = const BranchManagementScreen())),
              _sidebarSubItem(theme, context, 'Batch Management', Icons.groups, () => setState(() => _currentContent = const BatchManagementScreen())),
            ],
          ),

          _buildExpansionTile(
            theme: theme,
            title: 'Content',
            icon: Icons.video_library,
            isExpanded: _isVideosExpanded,
            onExpansionChanged: (val) => setState(() => _isVideosExpanded = val),
            children: [
              _sidebarSubItem(theme, context, 'Send Video', Icons.send, () => setState(() => _currentContent = const SendVideoScreen())),
              _sidebarSubItem(theme, context, 'Player Reports', Icons.assessment, () => setState(() => _currentContent = const PlayerReportScreen())),
            ],
          ),
          
          const Divider(color: Colors.white24, height: 32),
          _sidebarItem(theme, Icons.logout, 'Logout', onTap: () => Provider.of<AuthProvider>(context, listen: false).logout()),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sidebarItem(EliteTheme theme, IconData icon, String label, {bool isSelected = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? theme.accent : theme.surfaceContainerLowest.withValues(alpha: 0.6)),
      title: Text(label, style: theme.heading.copyWith(color: isSelected ? theme.surfaceContainerLowest : theme.surfaceContainerLowest.withValues(alpha: 0.6))),
      onTap: onTap,
    );
  }

  Widget _sidebarSubItem(EliteTheme theme, BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 50),
      leading: Icon(icon, color: theme.accent, size: 20),
      title: Text(label, style: theme.body.copyWith(color: theme.surfaceContainerLowest.withValues(alpha: 0.8))),
      onTap: () {
        if (Scaffold.maybeOf(context)?.hasDrawer ?? false) Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildExpansionTile({required EliteTheme theme, required String title, required IconData icon, required bool isExpanded, required Function(bool) onExpansionChanged, required List<Widget> children}) {
    return ExpansionTile(
      onExpansionChanged: onExpansionChanged,
      leading: Icon(icon, color: theme.surfaceContainerLowest.withValues(alpha: 0.6)),
      title: Text(title, style: theme.heading.copyWith(color: theme.surfaceContainerLowest.withValues(alpha: 0.6))),
      trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: theme.surfaceContainerLowest.withValues(alpha: 0.6)),
      children: children,
    );
  }

  Widget _buildManagementGrid(BuildContext context, double maxWidth, EliteTheme theme) {
    final List<Map<String, dynamic>> actions = [
      {'title': 'Add Student', 'icon': Icons.person_add_alt, 'color': theme.primary, 'onTap': () => setState(() => _currentContent = AddStudentEnrollmentScreen(onSuccess: () => setState(() => _currentContent = null)))},
      {'title': 'Enroll Coach', 'icon': Icons.sports, 'color': theme.accent, 'onTap': () => setState(() => _currentContent = CoachEnrollScreen(onSuccess: () => setState(() => _currentContent = null)))},
      {'title': 'Manage Branches', 'icon': Icons.location_city, 'color': theme.primary, 'onTap': () => setState(() => _currentContent = const BranchManagementScreen())},
      {'title': 'Manage Batches', 'icon': Icons.groups, 'color': theme.accent, 'onTap': () => setState(() => _currentContent = const BatchManagementScreen())},
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: actions.map((action) => SizedBox(
        width: maxWidth > 1200 ? (maxWidth - 48)/4 - 16 : (maxWidth > 700 ? (maxWidth - 16)/2 - 16 : maxWidth - 32),
        child: _buildActionCard(action, theme),
      )).toList(),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action, EliteTheme theme) {
    return EliteCard(
      onTap: action['onTap'],
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: action['color'].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(action['icon'], color: action['color'])
          ),
          const SizedBox(width: 16),
          Text(action['title'], style: theme.heading),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats, bool isLoading, double maxWidth, EliteTheme theme) {
    final width = maxWidth > 1200 ? (maxWidth - 48)/4 - 16 : (maxWidth > 600 ? (maxWidth - 16)/2 - 16 : maxWidth - 32);
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(width: width, child: _buildStatCard('Students', stats['total_students'].toString(), Icons.people, theme.primary, isLoading, theme)),
        SizedBox(width: width, child: _buildStatCard('Coaches', stats['total_coaches'].toString(), Icons.sports, theme.accent, isLoading, theme)),
        SizedBox(width: width, child: _buildStatCard('Branches', stats['total_branches'].toString(), Icons.location_on, theme.primary, isLoading, theme)),
        SizedBox(width: width, child: _buildStatCard('Batches', stats['total_batches'].toString(), Icons.class_, theme.accent, isLoading, theme)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isLoading, EliteTheme theme) {
    return EliteCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 16),
          isLoading ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: color, strokeWidth: 2)) : Text(value, style: theme.display2),
          const SizedBox(height: 8),
          Text(title, style: theme.caption.copyWith(color: theme.secondaryText)),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(dynamic user, dynamic profile, bool isDesktop, EliteTheme theme) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      decoration: BoxDecoration(
        color: theme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: theme.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${user?.firstName ?? 'Admin'} 👋', style: theme.display1.copyWith(color: theme.surfaceContainerLowest)),
              const SizedBox(height: 12),
              Text('Welcome back to the SportsVerse dashboard.', style: theme.body.copyWith(color: theme.surfaceContainerLowest.withValues(alpha: 0.8))),
            ]),
          ),
          if (isDesktop) Icon(Icons.dashboard_customize, color: theme.surfaceContainerLowest.withValues(alpha: 0.1), size: 100),
        ],
      ),
    );
  }

  Widget _buildLogo(EliteTheme theme) => Padding(
    padding: const EdgeInsets.all(24), 
    child: Text('SPORTSVERSE', style: theme.display2.copyWith(color: theme.surfaceContainerLowest, letterSpacing: 2.0))
  );

  Widget _buildTopHeader(BuildContext context, AuthProvider auth, EliteTheme theme) {
    return GlassHeader(
      title: "",
      useNavyStyle: false,
      actions: [
        IconButton(icon: Icon(Icons.notifications_none, color: theme.primary), onPressed: () {}),
        const SizedBox(width: 16),
        Container(width: 1, height: 24, color: theme.surfaceContainer),
        const SizedBox(width: 16),
        Text(auth.currentUser?.username ?? 'Admin', style: theme.heading),
        const SizedBox(width: 16),
        CircleAvatar(backgroundColor: theme.primary, radius: 18, child: Icon(Icons.person, color: theme.surfaceContainerLowest, size: 20)),
      ],
    );
  }
}