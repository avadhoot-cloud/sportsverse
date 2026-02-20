import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'dart:convert';

class CoachEnrollScreen extends StatefulWidget {
  const CoachEnrollScreen({super.key});

  @override
  State<CoachEnrollScreen> createState() => _CoachEnrollScreenState();
}

class _CoachEnrollScreenState extends State<CoachEnrollScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isSubmitting = false;

  Future<void> _enrollCoach() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await apiClient.post(
        '/api/coaches/enroll/',
        {
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'password': _passwordController.text,
        },
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Coach Enrolled Successfully!")),
          );
          Navigator.pop(context, true); // Return true to refresh list
        }
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error['message'] ?? 'Failed to enroll'}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enroll New Coach"),
        backgroundColor: const Color(0xFF00796B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_firstNameController, "First Name", Icons.person),
              const SizedBox(height: 15),
              _buildTextField(_lastNameController, "Last Name", Icons.person_outline),
              const SizedBox(height: 15),
              _buildTextField(_emailController, "Email Address", Icons.email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 15),
              _buildTextField(_phoneController, "Phone Number", Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 15),
              _buildTextField(_passwordController, "Login Password", Icons.lock, isPassword: true),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _enrollCoach,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("ENROLL COACH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value!.isEmpty ? "Required field" : null,
    );
  }
}