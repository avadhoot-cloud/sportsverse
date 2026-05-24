import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/api/student_api.dart';
import 'package:sportsverse_app/providers/student_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _uploadedReports = [];
  bool _loadingReports = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final provider = Provider.of<StudentProvider>(context, listen: false);
      provider.loadDashboardData();
      provider.loadPaymentSummary();
      _loadReports();
    });
  }

  Future<void> _loadReports() async {
    setState(() => _loadingReports = true);
    try {
      final reports = await StudentApi.getReports();
      if (mounted) {
        setState(() {
          _uploadedReports = reports;
          _loadingReports = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final data = provider.dashboardData;

    int totalSessions = 0;
    int attendedSessions = 0;
    if (data != null) {
      for (final e in data.currentEnrollments) {
        totalSessions += (e.totalSessions ?? 0);
        attendedSessions += e.sessionsAttended;
      }
    }

    final totalPaid = (provider.paymentSummary['total_paid'] as num?)?.toDouble() ?? 0;
    final totalDue = (provider.paymentSummary['total_due'] as num?)?.toDouble() ?? 0;
    final attendanceRate = totalSessions > 0 ? attendedSessions / totalSessions : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: provider.isLoading && data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await provider.loadDashboardData();
                await provider.loadPaymentSummary();
                await _loadReports();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B3D2F), Color(0xFF2D5A46)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.description, color: Colors.white, size: 40),
                          SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Reports',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Live data from your academy',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildReportCard(
                      title: 'Attendance Report',
                      icon: Icons.fact_check,
                      color: const Color(0xFF1B3D2F),
                      children: [
                        _statRow('Sessions Attended', '$attendedSessions / $totalSessions'),
                        _statRow('Attendance Rate', '${(attendanceRate * 100).toStringAsFixed(0)}%'),
                        if (data != null)
                          ...data.currentEnrollments.map(
                            (e) => _statRow(e.batchName, e.progressDisplay),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildReportCard(
                      title: 'Payment Summary',
                      icon: Icons.account_balance_wallet,
                      color: const Color(0xFF1565C0),
                      children: [
                        _statRow('Total Paid', '₹${totalPaid.toStringAsFixed(0)}'),
                        _statRow('Outstanding', '₹${totalDue.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Coach Reports',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingReports)
                      const Center(child: CircularProgressIndicator())
                    else if (_uploadedReports.isEmpty)
                      const Text('No uploaded reports yet', style: TextStyle(color: Colors.grey))
                    else
                      ..._uploadedReports.map((r) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF1B3D2F)),
                              title: Text(r['title']?.toString() ?? 'Report'),
                              subtitle: Text(
                                '${r['batch_name']} · ${r['uploaded_at']?.toString().split('T').first ?? ''}',
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
