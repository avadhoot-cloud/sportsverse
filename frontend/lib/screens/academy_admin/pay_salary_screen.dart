// lib/screens/academy_admin/pay_salary_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';

class PaySalaryScreen extends StatefulWidget {
  const PaySalaryScreen({super.key});

  @override
  State<PaySalaryScreen> createState() => _PaySalaryScreenState();
}

class _PaySalaryScreenState extends State<PaySalaryScreen> {
  String? _selectedRecipientId;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();

  List<dynamic> _coaches = [];
  bool _isLoadingCoaches = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _periodController.text = _defaultPeriod();
    _loadCoaches();
  }

  String _defaultPeriod() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  Future<void> _loadCoaches() async {
    try {
      final response = await apiClient.get('/api/coaches/list/');
      if (response.statusCode == 200) {
        setState(() {
          _coaches = jsonDecode(response.body);
          _isLoadingCoaches = false;
        });
      } else {
        setState(() => _isLoadingCoaches = false);
      }
    } catch (_) {
      setState(() => _isLoadingCoaches = false);
    }
  }

  Future<void> _handlePayment() async {
    if (_selectedRecipientId == null || _amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a coach and enter an amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await apiClient.post(
        '/api/payments/add-salary/',
        {
          'coach_id': int.parse(_selectedRecipientId!),
          'amount': double.tryParse(_amountController.text.trim()) ?? _amountController.text.trim(),
          'payment_period': _periodController.text.trim(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Salary recorded successfully'), backgroundColor: Colors.green),
          );
          _amountController.clear();
          setState(() => _selectedRecipientId = null);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Salary", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF00796B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00796B), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Coach", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildDropdown(),
              const SizedBox(height: 25),
              const Text("Payment Period", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _periodController,
                decoration: InputDecoration(
                  hintText: "e.g. Jan 2026",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 25),
              const Text("Amount", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.money, color: Color(0xFF00796B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handlePayment,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.payments_outlined),
                  label: const Text("PAY SALARY"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    if (_isLoadingCoaches) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _coaches.any((c) => c['id'].toString() == _selectedRecipientId)
              ? _selectedRecipientId
              : null,
          hint: const Text("Select Coach"),
          items: _coaches.map<DropdownMenuItem<String>>((coach) {
            return DropdownMenuItem<String>(
              value: coach['id'].toString(),
              child: Text(coach['full_name'] ?? coach['email'] ?? 'Coach'),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedRecipientId = val),
        ),
      ),
    );
  }
}
