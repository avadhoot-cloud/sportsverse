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


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});


  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
  
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  static const Color sidebarDarkGreen = Color(0xFF1B3D2F);
  static const Color brandTeal = Color(0xFF00796B);
  static const Color accentTeal = Color(0xFF00A388);

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
  bool _isReportsExpanded = false;

  // Changed to dynamic to handle both List and Map responses
  dynamic _analyticsData; 
  bool _isChartLoading = false;
  late PaymentApi _paymentApi;
  

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
final response = await apiClient.get(
  "/api/payments/expenses/",
);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        expenses = data;
        isLoadingExpenses = false; // ✅ IMPORTANT
      });
    } else {
      // 🔥 VERY IMPORTANT (HANDLE ERROR)
      if (!mounted) return;

      setState(() {
        isLoadingExpenses = false;
        expenses = [];
      });

      print("Error: ${response.statusCode}");
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      isLoadingExpenses = false; // ✅ STOP LOADING
      expenses = [];
    });

    print("Exception: $e");
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
final response = await apiClient.get(
  "/api/payments/dashboard/analytics/",
);
    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // ✅ DEBUG (ONLY ONE PRINT)
      print("ANALYTICS DATA: $data");

      if (data is Map<String, dynamic>) {
        if (!mounted) return;

        setState(() {
          _analyticsData = data;
          _isChartLoading = false;
        });
      } else {
        print("Invalid format (not a Map)");

        if (!mounted) return;

        setState(() {
          _analyticsData = null;
          _isChartLoading = false;
        });
      }
    } else {
      print("Analytics API Error: ${response.statusCode}");
      if (!mounted) return;

      setState(() {
        _analyticsData = null;
        _isChartLoading = false;
      });
    }
  } catch (e) {
    print("Error fetching analytics: $e");
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

  return Builder(
    builder: (innerContext) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 900;

          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            drawer: isDesktop ? null : _buildSidebar(innerContext),
            appBar: isDesktop ? null : _buildMobileAppBar(innerContext, authProvider),


          // ADD THIS PART HERE:
  floatingActionButton: ScaleTransition(
    scale: _scaleAnimation, // Using your existing pulse animation!
    child: FloatingActionButton(
      backgroundColor: brandTeal,
      child: const Icon(Icons.smart_toy, color: Colors.white),
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
                if (isDesktop) _buildSidebar(innerContext),
                Expanded(
                  child: Column(
                    children: [
                      if (isDesktop) _buildTopHeader(innerContext, authProvider),
                      Expanded(
                        child: FutureBuilder<Map<String, dynamic>>(
                          future: _fetchStats(),
                          builder: (context, snapshot) {

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return const Center(child: Text("Error loading data"));
                            }

                            final stats = snapshot.data ?? {
                              'total_students': 0,
                              'total_coaches': 0,
                              'total_branches': 0,
                              'total_batches': 0
                            };

                            return RefreshIndicator(
                              onRefresh: () async {
                                await _loadAnalytics();
                                if (!mounted) return;

                                setState(() {});
                              },
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    _buildTopFinancialSummary(constraints.maxWidth),
                                    const SizedBox(height: 24),

                                    _buildAnalyticsDashboardContainer(),
                                    const SizedBox(height: 32),
                                    
                                    /// 💸 EXPENSE SECTION
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [

                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "Expenses",
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: showAddExpenseDialog,
                                                icon: const Icon(Icons.add, size: 16),
                                                label: const Text("Add"),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 10),

                                          isLoadingExpenses
                                              ? const Center(child: CircularProgressIndicator())
                                              : expenses.isEmpty
                                                  ? const Text("No expenses added")
                                                  : ListView.builder(
                                                      shrinkWrap: true,
                                                      physics: const NeverScrollableScrollPhysics(),
                                                      itemCount: expenses.length,
                                                      itemBuilder: (context, index) {
                                                        final e = expenses[index];

                                                        return ListTile(
                                                          leading: Icon(
                                                            e['type'] == "Salary"
                                                                ? Icons.person
                                                                : Icons.receipt,
                                                            color: Colors.teal,
                                                          ),
                                                          title: Text(e['title']),
                                                          subtitle: Text(e['type']),
                                                          trailing: Text("₹${e['amount']}"),
                                                        );
                                                      },
                                                    ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 32),

                                    _buildWelcomeBanner(user, profile, isDesktop),
                                    const SizedBox(height: 32),

                                    _buildStatsGrid({
                                      'total_students': stats['total_students'] ?? 0,
                                      'total_coaches': stats['total_coaches'] ?? 0,
                                      'total_branches': stats['total_branches'] ?? 0,
                                      'total_batches': stats['total_batches'] ?? 0,
                                    }, false, constraints.maxWidth),

                                    const SizedBox(height: 32),
                                    const Text(
                                      'Quick Actions',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 20),

                                    _buildManagementGrid(innerContext, constraints.maxWidth),
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

Widget _buildTopFinancialSummary(double maxWidth) {
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
    childAspectRatio: maxWidth > 1200 ? 4 : 5,
    children: [
      _buildStatCardTop('₹${summary['total_income']}', 'Total Income', Icons.account_balance_wallet, Colors.teal),
      _buildStatCardTop('₹${summary['total_expense']}', 'Total Expenses', Icons.credit_card, Colors.teal),
      _buildStatCardTop('₹${summary['total_profit']}', 'Total Profit', Icons.trending_up, Colors.teal),
    ],
  );
}

  Widget _buildStatCardTop(String value, String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 16),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ]),
        ],
      ),
    );
  }

Widget _buildAnalyticsDashboardContainer() {
  return Container(
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200)),
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8), topRight: Radius.circular(8))),
          child: const Text('Analytics Dashboard',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date Range',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4)),
                child: DropdownButton<String>(
                  value: 'This Year',
                  underline: const SizedBox(),
                  items: ['This Year']
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (_) {},
                ),
              ),

              const Divider(height: 40),

              // 🔥 FIXED PART
              _isChartLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_analyticsData == null)
                      ? const Center(child: Text("No Analytics Data"))
                      : FinancialDashboardChart(
                          analytics: _analyticsData,
                        ),
            ],
          ),
        ),
      ],
    ),
  );
}

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, AuthProvider auth) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: sidebarDarkGreen),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: const Text('Admin Dashboard', style: TextStyle(color: sidebarDarkGreen, fontSize: 16, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: () => auth.logout()),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      color: sidebarDarkGreen,
      child: ListView(
        children: [
          const SizedBox(height: 40),
          _buildLogo(),
          _sidebarItem(Icons.dashboard, 'Dashboard', isSelected: true, onTap: () {
            if (Scaffold.of(context).hasDrawer) Navigator.pop(context);
          }),
          
          _buildExpansionTile(
            title: 'Coaches',
            icon: Icons.psychology,
            isExpanded: _isCoachesExpanded,
            onExpansionChanged: (val) => 
             setState(() => _isCoachesExpanded = val),
            children: [
              _sidebarSubItem(context, 'Enrolled Coaches', Icons.view_list, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachListScreen()))),
              _sidebarSubItem(context, 'Enroll Coach', Icons.person_add, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachEnrollScreen()))),
              _sidebarSubItem(context, 'Assign Coach', Icons.assignment_ind, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignCoachScreen()))),
            ],
          ),

          _buildExpansionTile(
            title: 'Students',
            icon: Icons.school,
            isExpanded: _isStudentsExpanded,
            onExpansionChanged: (val) => setState(() => _isStudentsExpanded = val),
            children: [
              _sidebarSubItem(context, 'View Students', Icons.visibility_outlined, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider(
                      create: (context) => AdminProvider(),
                      child: const ViewStudentsScreen(),
                    ),
                  ),
                );
              }),
              _sidebarSubItem(context, 'Enroll Student', Icons.add_circle_outline, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStudentEnrollmentScreen()))),
            ],
          ),

          _buildExpansionTile(
            title: 'Attendance',
            icon: Icons.how_to_reg,
            isExpanded: _isAttendanceExpanded,
            onExpansionChanged: (val) => setState(() => _isAttendanceExpanded = val),
             children: [
  _sidebarSubItem(
    context,
    'Face Attendance',
    Icons.face,
    () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminFaceAttendanceScreen(),
      ),
    ),
  ),

  // 🔥 ADD THIS HERE
  _sidebarSubItem(
    context,
    'Mark Attendance',
    Icons.check_circle_outline,
    () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MarkAttendanceScreen(),
      ),
    ),
  ),

  _sidebarSubItem(
    context,
    'View Attendance',
    Icons.calendar_month,
    () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ViewAttendanceScreen(),
      ),
    ),
  ),
],
      
          ),

          _buildExpansionTile(
            title: 'Payments',
            icon: Icons.payments,
            isExpanded: _isPaymentsExpanded,
            onExpansionChanged: (val) => setState(() => _isPaymentsExpanded = val),
            children: [
              _sidebarSubItem(context, 'Student Payments', Icons.monetization_on, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentPaymentScreen()))),
              _sidebarSubItem(context, 'Pay Salaries', Icons.account_balance_wallet, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaySalaryScreen()))),
              _sidebarSubItem(context, 'Salary History', Icons.history, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryDetailsScreen()))),
            ],
          ),

          _buildExpansionTile(
            title: 'Organization',
            icon: Icons.business,
            isExpanded: _isStaffExpanded,
            onExpansionChanged: (val) => setState(() => _isStaffExpanded = val),
            children: [
              _sidebarSubItem(context, 'Branch Management', Icons.location_city, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchManagementScreen()))),
              _sidebarSubItem(context, 'Batch Management', Icons.groups, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchManagementScreen()))),
            ],
          ),

          _buildExpansionTile(
            title: 'Content',
            icon: Icons.video_library,
            isExpanded: _isVideosExpanded,
            onExpansionChanged: (val) => setState(() => _isVideosExpanded = val),
            children: [
              _sidebarSubItem(context, 'Send Video', Icons.send, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SendVideoScreen()))),
              _sidebarSubItem(context, 'Player Reports', Icons.assessment, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerReportScreen()))),
            ],
          ),
          
          const Divider(color: Colors.white24),
          _sidebarItem(Icons.logout, 'Logout', onTap: () => Provider.of<AuthProvider>(context, listen: false).logout()),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, {bool isSelected = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white60),
      title: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60)),
      onTap: onTap,
    );
  }

  Widget _sidebarSubItem(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 50),
      leading: Icon(icon, color: accentTeal, size: 18),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      onTap: () {
        if (Scaffold.maybeOf(context)?.hasDrawer ?? false) Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildExpansionTile({required String title, required IconData icon, required bool isExpanded, required Function(bool) onExpansionChanged, required List<Widget> children}) {
    return ExpansionTile(
      onExpansionChanged: onExpansionChanged,
      leading: Icon(icon, color: Colors.white60),
      title: Text(title, style: const TextStyle(color: Colors.white60)),
      trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white60),
      children: children,
    );
  }

  Widget _buildManagementGrid(BuildContext context, double maxWidth) {
    int crossAxisCount = maxWidth > 1200 ? 4 : (maxWidth > 700 ? 2 : 1);
    final List<Map<String, dynamic>> actions = [
      {'title': 'Add Student', 'icon': Icons.person_add_alt, 'color': Colors.pink, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStudentEnrollmentScreen()))},
      {'title': 'Enroll Coach', 'icon': Icons.sports, 'color': Colors.green, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachEnrollScreen()))},
      {'title': 'Manage Branches', 'icon': Icons.location_city, 'color': Colors.orange, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchManagementScreen()))},
      {'title': 'Manage Batches', 'icon': Icons.groups, 'color': Colors.blue, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchManagementScreen()))},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2.5),
      itemCount: actions.length,
      itemBuilder: (context, index) => _buildActionCard(actions[index]),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action) {
    return InkWell(
      onTap: action['onTap'],
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: action['color'].withOpacity(0.1), child: Icon(action['icon'], color: action['color'])),
            const SizedBox(width: 16),
            Text(action['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats, bool isLoading, double maxWidth) {
    int crossAxisCount = maxWidth > 1200 ? 4 : (maxWidth > 600 ? 2 : 2);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: maxWidth > 1200 ? 1.5 : 1.2,
      children: [
        _buildStatCard('Students', stats['total_students'].toString(), Icons.people, Colors.teal, isLoading),
        _buildStatCard('Coaches', stats['total_coaches'].toString(), Icons.sports, Colors.indigo, isLoading),
        _buildStatCard('Branches', stats['total_branches'].toString(), Icons.location_on, Colors.orange, isLoading),
        _buildStatCard('Batches', stats['total_batches'].toString(), Icons.class_, Colors.purple, isLoading),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1), width: 1)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(user, profile, isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [brandTeal, brandTeal.withOpacity(0.8)]), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${user?.firstName ?? 'Admin'} 👋', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Welcome back to the SportsVerse dashboard.', style: TextStyle(color: Colors.white.withOpacity(0.9))),
            ]),
          ),
          if (isDesktop) Icon(Icons.dashboard_customize, color: Colors.white.withOpacity(0.2), size: 80),
        ],
      ),
    );
  }

  Widget _buildLogo() => const Padding(padding: EdgeInsets.all(24), child: Text('SPORTSVERSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 1.2)));

  Widget _buildTopHeader(BuildContext context, AuthProvider auth) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.grey), onPressed: () {}),
          const SizedBox(width: 16),
          const VerticalDivider(indent: 20, endIndent: 20),
          const SizedBox(width: 16),
          Text(auth.currentUser?.username ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          const CircleAvatar(backgroundColor: accentTeal, radius: 18, child: Icon(Icons.person, color: Colors.white, size: 20)),
        ],
      ),
    );
  }
}