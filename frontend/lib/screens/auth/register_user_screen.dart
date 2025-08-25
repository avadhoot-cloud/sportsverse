// sportsverse/frontend/sportsverse_app/lib/screens/auth/register_user_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedUserType = 'COACH'; // Default to Coach
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;

  // Student-specific controllers
  final _parentNameController = TextEditingController();
  final _parentPhoneNumberController = TextEditingController();
  final _parentEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-generate username suggestion when first/last name changes
    _firstNameController.addListener(_generateUsernameSuggestion);
    _lastNameController.addListener(_generateUsernameSuggestion);
  }

  void _generateUsernameSuggestion() {
    if (_firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty) {
      // Generate username like: firstName.lastName.userType.timestamp
      final firstName = _firstNameController.text.toLowerCase().trim();
      final lastName = _lastNameController.text.toLowerCase().trim();
      final userType = _selectedUserType.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch
          .toString()
          .substring(8); // Last 5 digits

      final suggestion = '${firstName}_${lastName}_${userType}_$timestamp';

      // Only update if the field is empty or contains a previous suggestion
      if (_usernameController.text.isEmpty ||
          _usernameController.text.contains('_${userType}_')) {
        _usernameController.text = suggestion;
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_generateUsernameSuggestion);
    _lastNameController.removeListener(_generateUsernameSuggestion);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _parentNameController.dispose();
    _parentPhoneNumberController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  void _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match.', Colors.red);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.registerCoachStudentStaff(
        userType: _selectedUserType,
        username: _usernameController.text,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phoneNumber: _phoneNumberController.text.isNotEmpty
            ? _phoneNumberController.text
            : null,
        gender: _selectedGender,
        dateOfBirth: _selectedDateOfBirth != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!)
            : null,
        parentName:
            _selectedUserType == 'STUDENT' &&
                _parentNameController.text.isNotEmpty
            ? _parentNameController.text
            : null,
        parentPhoneNumber:
            _selectedUserType == 'STUDENT' &&
                _parentPhoneNumberController.text.isNotEmpty
            ? _parentPhoneNumberController.text
            : null,
        parentEmail:
            _selectedUserType == 'STUDENT' &&
                _parentEmailController.text.isNotEmpty
            ? _parentEmailController.text
            : null,
      );
      _showSnackBar('User registered successfully!', Colors.green);
      _formKey.currentState!.reset(); // Clear form
      setState(() {
        _selectedDateOfBirth = null;
        _selectedGender = null;
        _usernameController.clear(); // Clear auto-generated username
      });
    } catch (e) {
      String errorMessage = authProvider.errorMessage ?? e.toString();

      // Show more user-friendly error messages
      if (errorMessage.contains('This username is already taken')) {
        errorMessage = 'Username is already taken. Try a different username.';
        _generateUsernameSuggestion(); // Auto-generate a new suggestion
      } else if (errorMessage.contains(
        'A user with this email already exists',
      )) {
        errorMessage =
            'Email is already registered. Try a different email or leave it empty.';
      }

      _showSnackBar(errorMessage, Colors.red);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Register New User',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return authProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          value: _selectedUserType,
                          decoration: const InputDecoration(
                            labelText: 'User Type',
                            prefixIcon: Icon(Icons.group),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'COACH',
                              child: Text('Coach'),
                            ),
                            DropdownMenuItem(
                              value: 'STUDENT',
                              child: Text('Student'),
                            ),
                            DropdownMenuItem(
                              value: 'STAFF',
                              child: Text('Staff'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedUserType = value!;
                              _generateUsernameSuggestion(); // Regenerate username with new user type
                            });
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter username.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email (Optional for Students)',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (_selectedUserType != 'STUDENT' &&
                                (value == null || value.isEmpty)) {
                              return 'Email is required for Coaches/Staff.';
                            }
                            if (value != null &&
                                value.isNotEmpty &&
                                !RegExp(
                                  r'^[^@]+@[^@]+\.[^@]+',
                                ).hasMatch(value)) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password.';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters long.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm password.';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter first name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter last name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _phoneNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number (Optional)',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16.0),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: const InputDecoration(
                            labelText: 'Gender (Optional)',
                            prefixIcon: Icon(Icons.wc),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('Male')),
                            DropdownMenuItem(value: 'F', child: Text('Female')),
                            DropdownMenuItem(value: 'O', child: Text('Other')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedGender = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16.0),
                        ListTile(
                          title: Text(
                            _selectedDateOfBirth == null
                                ? 'Select Date of Birth (Required for Students)'
                                : 'Date of Birth: ${DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!)}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectDate(context),
                        ),
                        if (_selectedUserType == 'STUDENT') ...[
                          const SizedBox(height: 24.0),
                          Text(
                            'Parent Details (For Student)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16.0),
                          TextFormField(
                            controller: _parentNameController,
                            decoration: const InputDecoration(
                              labelText: 'Parent Name (Optional)',
                              prefixIcon: Icon(Icons.person_2),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          TextFormField(
                            controller: _parentPhoneNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Parent Phone Number (Optional)',
                              prefixIcon: Icon(Icons.phone_android),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16.0),
                          TextFormField(
                            controller: _parentEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Parent Email (Optional)',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                        const SizedBox(height: 24.0),
                        ElevatedButton(
                          onPressed: _registerUser,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: Colors.blue.shade200,
                          ),
                          child: const Text('Register User'),
                        ),
                      ],
                    ),
                  ),
                );
        },
      ),
    );
  }
}
