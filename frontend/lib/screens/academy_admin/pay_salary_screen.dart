// lib/screens/academy_admin/pay_salary_screen.dart
import 'package:flutter/material.dart';

class PaySalaryScreen extends StatefulWidget {
  const PaySalaryScreen({super.key});

  @override
  State<PaySalaryScreen> createState() => _PaySalaryScreenState();
}

class _PaySalaryScreenState extends State<PaySalaryScreen> {
  String? _selectedRecipientId;
  final TextEditingController _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Salary", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF00796B), // Teal Header
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00796B), width: 1.5), // Teal Border
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Staff/Coach", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildDropdown(), // Fetches from CoachProfile/StaffProfile
              const SizedBox(height: 25),
              const Text("Amount", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.money, color: Color(0xFF00796B)), // Teal Icon
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handlePayment(),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text("PAY SALARY"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B), // Teal Button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
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
          value: _selectedRecipientId,
          hint: const Text("Select Staff"),
          items: [], // Map your staff/coach list here
          onChanged: (val) => setState(() => _selectedRecipientId = val),
        ),
      ),
    );
  }

  void _handlePayment() {
    // Call your ApiClient.post('/payments/salary/', ...) here
  }
}