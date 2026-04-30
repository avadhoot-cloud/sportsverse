// sportsverse/frontend/sportsverse_app/lib/screens/auth/register_academy_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/api/auth_api.dart'; // To get sports list
import 'package:sportsverse_app/models/user.dart'; // For Sport model
import 'package:sportsverse_app/providers/auth_provider.dart';

import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_button.dart';
import 'package:sportsverse_app/widgets/elite_text_input.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RegisterAcademyScreen extends StatefulWidget {
  const RegisterAcademyScreen({super.key});

  @override
  State<RegisterAcademyScreen> createState() => _RegisterAcademyScreenState();
}

class _RegisterAcademyScreenState extends State<RegisterAcademyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _academyNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _emailAddressController = TextEditingController();
  final _slugController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminFirstNameController = TextEditingController();
  final _adminLastNameController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  File? _academyLogo;
  List<Sport> _availableSports = [];
  List<int> _selectedSportIds = [];
  bool _isLoadingSports = true;
  String? _sportsErrorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSports();
  }

  Future<void> _fetchSports() async {
    setState(() {
      _isLoadingSports = true;
      _sportsErrorMessage = null;
    });
    try {
      _availableSports = await authApi.getSports();
    } catch (e) {
      _sportsErrorMessage = 'Failed to load sports: ${e.toString()}';
    } finally {
      setState(() {
        _isLoadingSports = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _academyLogo = File(pickedFile.path);
      });
    }
  }

  void _registerAcademy() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSportIds.isEmpty) {
      _showSnackBar('Please select at least one sport offered.', Colors.red);
      return;
    }

    if (_adminPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match.', Colors.red);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.registerAcademy(
        organizationFullName: _fullNameController.text,
        organizationAcademyName: _academyNameController.text,
        organizationLocation: _locationController.text,
        organizationMobileNumber: _mobileNumberController.text,
        organizationEmailAddress: _emailAddressController.text,
        organizationSlug: _slugController.text,
        sportsOfferedIds: _selectedSportIds,
        adminUsername: _adminUsernameController.text,
        adminEmail: _adminEmailController.text,
        adminFirstName: _adminFirstNameController.text,
        adminLastName: _adminLastNameController.text,
        adminPassword: _adminPasswordController.text,
        academyLogoFile: _academyLogo,
      );
      _showSnackBar('Academy registered successfully! Please login.', Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar(authProvider.errorMessage ?? 'Registration failed.', Colors.red);
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
      appBar: const GlassHeader(title: 'REGISTER ACADEMY'),
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
                            'LAUNCH YOUR\nACADEMY.',
                            style: theme.display1.copyWith(
                              height: 1.1,
                              color: theme.surfaceContainerLowest,
                            ),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                          const SizedBox(height: 16.0),
                          Text(
                            'Partner with SportsVerse to manage your elite athletes.',
                            style: theme.body.copyWith(color: theme.surfaceContainerLowest.withOpacity(0.7)),
                          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                          const SizedBox(height: 40.0),

                          Center(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: theme.surfaceContainer,
                                    backgroundImage: _academyLogo != null ? FileImage(_academyLogo!) : null,
                                    child: _academyLogo == null
                                        ? Icon(Icons.camera_alt, size: 40, color: theme.primary)
                                        : null,
                                  ),
                                  if (_academyLogo != null)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: theme.royalAccent,
                                        child: Icon(Icons.edit, size: 18, color: theme.surfaceContainerLowest),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32.0),

                          EliteTextInput(
                            controller: _fullNameController,
                            labelText: 'Organization Full Name',
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _academyNameController,
                            labelText: 'Academy Display Name',
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _locationController,
                            labelText: 'Academy Location',
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _mobileNumberController,
                            labelText: 'Mobile Number',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _emailAddressController,
                            labelText: 'Academy Email Address',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _slugController,
                            labelText: 'Academy URL Identifier',
                          ),
                          const SizedBox(height: 32.0),

                          Text(
                            'SPORTS OFFERED',
                            style: theme.subhead.copyWith(color: theme.surfaceContainerLowest),
                          ),
                          const SizedBox(height: 16.0),
                          _isLoadingSports
                              ? Center(child: CircularProgressIndicator(color: theme.royalAccent))
                              : _sportsErrorMessage != null
                                  ? Text(_sportsErrorMessage!, style: TextStyle(color: theme.errorText))
                                  : Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: _availableSports.map((sport) {
                                        final isSelected = _selectedSportIds.contains(sport.id);
                                        return FilterChip(
                                          label: Text(
                                            sport.name.toUpperCase(),
                                            style: theme.caption.copyWith(
                                              color: isSelected ? theme.primary : theme.surfaceContainerLowest,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                _selectedSportIds.add(sport.id);
                                              } else {
                                                _selectedSportIds.remove(sport.id);
                                              }
                                            });
                                          },
                                          selectedColor: theme.royalAccent,
                                          backgroundColor: theme.primary.withOpacity(0.3),
                                          checkmarkColor: theme.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        );
                                      }).toList(),
                                    ),
                          const SizedBox(height: 32.0),

                          Text(
                            'ACADEMY ADMIN',
                            style: theme.subhead.copyWith(color: theme.surfaceContainerLowest),
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _adminUsernameController,
                            labelText: 'Admin Username',
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _adminEmailController,
                            labelText: 'Admin Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _adminFirstNameController,
                            labelText: 'Admin First Name',
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _adminLastNameController,
                            labelText: 'Admin Last Name',
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _adminPasswordController,
                            labelText: 'Admin Password',
                            obscureText: true,
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _confirmPasswordController,
                            labelText: 'Confirm Password',
                            obscureText: true,
                          ),
                          const SizedBox(height: 40.0),
                          EliteButton(
                            text: 'Register Academy',
                            isLoading: authProvider.isLoading,
                            onPressed: _registerAcademy,
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