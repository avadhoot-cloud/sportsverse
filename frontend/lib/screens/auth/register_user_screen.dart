// sportsverse/frontend/sportsverse_app/lib/screens/auth/register_user_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';

import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_button.dart';
import 'package:sportsverse_app/widgets/elite_text_input.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    _firstNameController.addListener(_generateUsernameSuggestion);
    _lastNameController.addListener(_generateUsernameSuggestion);
  }

  void _generateUsernameSuggestion() {
    if (_firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty) {
      final firstName = _firstNameController.text.toLowerCase().trim();
      final lastName = _lastNameController.text.toLowerCase().trim();
      final userType = _selectedUserType.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch
          .toString()
          .substring(8);

      final suggestion = '${firstName}_${lastName}_${userType}_$timestamp';

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
      _formKey.currentState!.reset();
      setState(() {
        _selectedDateOfBirth = null;
        _selectedGender = null;
        _usernameController.clear();
      });
    } catch (e) {
      String errorMessage = authProvider.errorMessage ?? e.toString();
      if (errorMessage.contains('This username is already taken')) {
        errorMessage = 'Username is already taken. Try a different username.';
        _generateUsernameSuggestion();
      } else if (errorMessage.contains('A user with this email already exists')) {
        errorMessage = 'Email is already registered. Try a different email.';
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassHeader(title: 'REGISTER USER'),
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/login_screen.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.primary.withOpacity(0.4),
                      theme.primary.withOpacity(0.95),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: theme.mobileMargin),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32.0),
                          Text(
                            'JOIN THE\nACADEMY.',
                            style: theme.display1.copyWith(
                              height: 1.1,
                              color: theme.surfaceContainerLowest,
                            ),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                          const SizedBox(height: 16.0),
                          Text(
                            'Enter your details to create an account.',
                            style: theme.body.copyWith(color: theme.surfaceContainerLowest.withOpacity(0.7)),
                          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                          const SizedBox(height: 40.0),
                          
                          // Dropdown for User Type
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.surfaceContainer,
                              borderRadius: BorderRadius.circular(24.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                value: _selectedUserType,
                                decoration: InputDecoration(
                                  labelText: 'User Type',
                                  labelStyle: theme.subhead.copyWith(color: theme.primary),
                                  border: InputBorder.none,
                                ),
                                dropdownColor: theme.surfaceContainerLowest,
                                items: const [
                                  DropdownMenuItem(value: 'COACH', child: Text('Coach')),
                                  DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedUserType = value!;
                                    _generateUsernameSuggestion();
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),

                          EliteTextInput(
                            controller: _usernameController,
                            labelText: 'Username',
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _emailController,
                            labelText: 'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _passwordController,
                            labelText: 'Password',
                            obscureText: true,
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _confirmPasswordController,
                            labelText: 'Confirm Password',
                            obscureText: true,
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _firstNameController,
                            labelText: 'First Name',
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _lastNameController,
                            labelText: 'Last Name',
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _phoneNumberController,
                            labelText: 'Phone Number (Optional)',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16.0),

                          // Gender Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.surfaceContainer,
                              borderRadius: BorderRadius.circular(24.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                value: _selectedGender,
                                decoration: InputDecoration(
                                  labelText: 'Gender (Optional)',
                                  labelStyle: theme.subhead.copyWith(color: theme.primary),
                                  border: InputBorder.none,
                                ),
                                dropdownColor: theme.surfaceContainerLowest,
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
                            ),
                          ),
                          const SizedBox(height: 16.0),

                          // Date of Birth Picker
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.surfaceContainer,
                                borderRadius: BorderRadius.circular(24.0),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedDateOfBirth == null
                                          ? 'Select Date of Birth'
                                          : 'Date of Birth: ${DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!)}',
                                      style: theme.body,
                                    ),
                                  ),
                                  Icon(Icons.calendar_today, color: theme.primary, size: 20),
                                ],
                              ),
                            ),
                          ),
                          
                          if (_selectedUserType == 'STUDENT') ...[
                            const SizedBox(height: 32.0),
                            Text(
                              'PARENT DETAILS',
                              style: theme.subhead.copyWith(color: theme.surfaceContainerLowest),
                            ),
                            const SizedBox(height: 16.0),
                            EliteTextInput(
                              controller: _parentNameController,
                              labelText: 'Parent Name',
                            ),
                            const SizedBox(height: 16.0),
                            EliteTextInput(
                              controller: _parentPhoneNumberController,
                              labelText: 'Parent Phone Number',
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16.0),
                            EliteTextInput(
                              controller: _parentEmailController,
                              labelText: 'Parent Email',
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                          
                          const SizedBox(height: 40.0),
                          EliteButton(
                            text: 'Register User',
                            isLoading: authProvider.isLoading,
                            onPressed: _registerUser,
                            variant: EliteButtonVariant.royal,
                          ),
                          const SizedBox(height: 40.0),
                        ],
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
