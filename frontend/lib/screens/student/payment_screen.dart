import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/student_provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final provider = Provider.of<StudentProvider>(context, listen: false);
      provider.loadPayments();
      provider.loadPaymentSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();

    // DYNAMIC CALCULATION: Summing up all unpaid amounts from the payments list
    double pendingTotal = provider.payments
        .where((p) => !p.isPaid)
        .fold(0.0, (sum, p) => sum + p.amount);

    final totalDueStr = pendingTotal.toStringAsFixed(2);
    final nextDue = provider.paymentSummary['next_due_date'] ?? "Not Scheduled";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text("Payments & Invoices", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: provider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => provider.loadPayments(),
            child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubscriptionCard(totalDueStr, nextDue),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text("Transaction History", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    _buildTransactionList(provider),
                  ],
                ),
              ),
          ),
    );
  }

  Widget _buildSubscriptionCard(String amount, String dueDate) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3D2F), Color(0xFF2D5A46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B3D2F).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Outstanding", style: TextStyle(color: Colors.white70, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                child: const Text("Fee Status", style: TextStyle(color: Colors.white, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 15),
          Text("₹ $amount", 
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardInfo("Next Due Date", dueDate),
              _cardInfo("Status", double.parse(amount) > 0 ? "Pending" : "Fully Paid"),
            ],
          )
        ],
      ),
    );
  }

  Widget _cardInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildTransactionList(StudentProvider provider) {
    final transactions = provider.payments;

    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: Text("No transaction history available."),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        bool isPaid = tx.isPaid;

        // FIXED: Using your model fields 'paidDate' and 'dueDate'
        String displayDate = isPaid 
            ? (tx.paidDate != null ? tx.paidDate.toString().split(' ')[0] : "Paid")
            : "Due: ${tx.dueDate.toString().split(' ')[0]}";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                child: Icon(
                  isPaid ? Icons.check : Icons.access_time, 
                  color: isPaid ? Colors.green : Colors.orange, size: 18
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.notes ?? "Academy Fee", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(displayDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("₹${tx.amount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(isPaid ? "SUCCESS" : "UNPAID", 
                    style: TextStyle(
                      color: isPaid ? Colors.green : Colors.red, 
                      fontSize: 10, 
                      fontWeight: FontWeight.bold
                    )),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}