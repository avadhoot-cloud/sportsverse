// lib/screens/academy_admin/salary_details_screen.dart
import 'package:flutter/material.dart';

class SalaryDetailsScreen extends StatelessWidget {
  const SalaryDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Salary History", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF00796B),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            // Matching the fields from CoachSalaryTransaction/StaffSalaryTransaction
            columns: const [
              DataColumn(label: Text('Recipient')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Period')), // mapped to payment_period
              DataColumn(label: Text('Status')), // mapped to is_paid
            ],
            rows: [
              DataRow(cells: [
                const DataCell(Text('Coach Rahul')),
                const DataCell(Text('₹30,000')),
                const DataCell(Text('Jan 2026')), // payment_period
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Paid', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}