import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/api/payment_api.dart';
import 'package:sportsverse_app/api/branch_api.dart';
import 'package:sportsverse_app/api/batch_api.dart';
import 'package:sportsverse_app/models/branch.dart';
import 'package:sportsverse_app/models/batch.dart';
import 'dart:convert';

class StudentPaymentScreen extends StatefulWidget {
  const StudentPaymentScreen({super.key});

  @override
  State<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends State<StudentPaymentScreen> {
  late BranchApi _branchApi;
  late BatchApi _batchApi;
  late PaymentApi _paymentApi;

  String? _selectedBranchId;
  String? _selectedBatchId;
  String? _selectedSportId; 
  String? _selectedStudentId; 
  
  List<Branch> _branches = [];
  List<Batch> _batches = [];
  List<dynamic> _sports = []; 
  List<dynamic> _studentFinancials = [];
  Map<String, dynamic>? _selectedStudentData; 
  
  bool _isLoadingData = true;
  bool _isFetchingReport = false;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _branchApi = BranchApi(apiClient);
      _batchApi = BatchApi(apiClient);
      _paymentApi = PaymentApi(apiClient);
      _loadInitialData();
      _isInitialized = true;
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    try {
      final branches = await _branchApi.getBranches();
      final response = await apiClient.get('/api/organizations/sports/');
      List<dynamic> fetchedSports = [];
      if (response.statusCode == 200) {
        fetchedSports = jsonDecode(response.body);
      }
      setState(() {
        _branches = branches;
        _sports = fetchedSports;
        _isLoadingData = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _loadBatches(String branchId) async {
    try {
      final batches = await _batchApi.getBatches();
      setState(() {
        _batches = batches.where((b) => b.branchId.toString() == branchId).toList();
      });
    } catch (e) {
      debugPrint("Error loading batches: $e");
    }
  }

  void _handleFetchBatchData() async {
    if (_selectedBranchId == null || _selectedBatchId == null || _selectedSportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Branch, Sport, and Batch")),
      );
      return;
    }

    setState(() {
      _isFetchingReport = true;
      _studentFinancials = [];
      _selectedStudentId = null;
      _selectedStudentData = null;
    });

    try {
      final data = await _paymentApi.getBatchFinancials(
        branchId: _selectedBranchId!,
        sportId: _selectedSportId!, 
        batchId: _selectedBatchId!,
      );

      if (data != null && data['students'] != null) {
        setState(() => _studentFinancials = data['students']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching financials: $e")));
    } finally {
      setState(() => _isFetchingReport = false);
    }
  }

Future<void> _showPaymentDialog() async {
  final s = _selectedStudentData!;
  final TextEditingController amountController = TextEditingController();

  String paymentMethod = "Cash"; // default
  amountController.text = "";

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Record Payment for ${s['first_name']}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Policy: ${s['policy'] ?? s['payment_policy'] ?? 'N/A'}"),
          const SizedBox(height: 10),

          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Amount (₹)",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: paymentMethod,
            decoration: const InputDecoration(
              labelText: "Payment Method",
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: "Cash", child: Text("Cash")),
              DropdownMenuItem(value: "Online", child: Text("UPI / Online")),
            ],
            onChanged: (value) {
              paymentMethod = value!;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ElevatedButton(
          onPressed: () async {
            if (amountController.text.isEmpty) return;

            try {
              final response = await apiClient.post(
                '/api/payments/collect-fee/',
                {
                  'student_id': s['student_id'],
                  'enrollment_id': s['enrollment_id'],
                  'amount': amountController.text,
                  'payment_method': paymentMethod,
                },
              );

              if (response.statusCode == 200 || response.statusCode == 201) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Payment Recorded!")),
                  );
                  _handleFetchBatchData();
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${response.body}")),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Network Error: $e")),
                );
              }
            }
          },
          child: const Text("CONFIRM"),
        )
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Payment & Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00796B),
      ),
      body: _isLoadingData 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildFilterSection(),
                if (_studentFinancials.isNotEmpty) ...[
  const SizedBox(height: 20),
  _buildStudentDropdown(),
] else if (!_isFetchingReport && _selectedBranchId != null) ...[
  const SizedBox(height: 20),
  const Text(
    "No student available",
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.red,
    ),
  ),
],
                if (_selectedStudentData != null) ...[
                  const SizedBox(height: 20),
                  _buildStudentStatusCard(),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade100)),
      child: Column(
        children: [
          _buildDropdown("Branch", Icons.business, _selectedBranchId, _branches.map((b) => DropdownMenuItem(value: b.id.toString(), child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(), (val) {
            setState(() { _selectedBranchId = val; _selectedBatchId = null; _studentFinancials = []; });
            if (val != null) _loadBatches(val);
          }),
          const SizedBox(height: 15),
          _buildDropdown("Sport", Icons.sports, _selectedSportId, _sports.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name'], overflow: TextOverflow.ellipsis))).toList(), (val) => setState(() => _selectedSportId = val)),
          const SizedBox(height: 15),
          _buildDropdown("Batch", Icons.groups, _selectedBatchId, _batches.map((b) => DropdownMenuItem(value: b.id.toString(), child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(), (val) => setState(() => _selectedBatchId = val)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isFetchingReport ? null : _handleFetchBatchData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
              child: _isFetchingReport ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("FETCH STUDENTS"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDropdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
      child: _buildDropdown(
        "Select Student to View Status", 
        Icons.person, 
        _selectedStudentId, 
        _studentFinancials.map((s) => DropdownMenuItem(
          value: s['student_id'].toString(),
          child: Text("${s['first_name']} ${s['last_name']}", overflow: TextOverflow.ellipsis)
        )).toList(), 
        (val) {
          setState(() {
            _selectedStudentId = val;
            _selectedStudentData = _studentFinancials.firstWhere((element) => element['student_id'].toString() == val);
          });
        }
      ),
    );
  }

  Widget _buildStudentStatusCard() {
    final s = _selectedStudentData!;
    final bool isDefaulter = s['is_defaulter'] ?? false;
    final String policy = s['policy'] ?? s['payment_policy'] ?? 'SESSION_BASED';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isDefaulter ? Colors.red.shade700 : Colors.green.shade700,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${s['first_name']} ${s['last_name']}", 
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Chip(label: Text(policy), backgroundColor: Colors.white24),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _statusRow("Account Status", s['display_status'] ?? (isDefaulter ? "Action Required" : "Up to date"), Icons.info_outline),
                const Divider(),
                _statusRow("Total Fees Paid", "₹${s['total_fees_paid'] ?? 0}", Icons.account_balance_wallet),
                
                if (policy == 'SESSION_BASED') ...[
                  const Divider(),
                  _statusRow("Unpaid Sessions", "${s['unpaid_sessions'] ?? 0}", Icons.warning_amber, 
                    color: ((s['unpaid_sessions'] ?? 0) > 0) ? Colors.red : Colors.green),
                ],
                
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(),
                  icon: const Icon(Icons.add_card),
                  label: const Text("RECORD NEW PAYMENT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDefaulter ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50)
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 15),
        Text(label, style: const TextStyle(fontSize: 16)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildDropdown(String hint, IconData icon, String? value, List<DropdownMenuItem<String>> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF00796B)),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}