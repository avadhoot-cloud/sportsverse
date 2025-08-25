// sportsverse/frontend/sportsverse_app/lib/screens/auth/register_academy_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/api/auth_api.dart'; // To get sports list
import 'package:sportsverse_app/models/user.dart'; // For Sport model
import 'package:sportsverse_app/providers/auth_provider.dart';

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
  final _slugController = TextEditingController(); // For organization_slug
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
      Navigator.pop(context); // Go back to login screen
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Your Academy', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.blue.shade100,
                              backgroundImage: _academyLogo != null ? FileImage(_academyLogo!) : null,
                              child: _academyLogo == null
                                  ? Icon(Icons.camera_alt, size: 40, color: Colors.blue.shade700)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Organization Full Name',
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter full organization name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _academyNameController,
                          decoration: const InputDecoration(
                            labelText: 'Academy Display Name',
                            prefixIcon: Icon(Icons.school),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter academy display name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Academy Location',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter academy location.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _mobileNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter mobile number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _emailAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Academy Email Address',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter academy email.';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _slugController,
                          decoration: const InputDecoration(
                            labelText: 'Academy URL Identifier (e.g., "my-academy")',
                            prefixIcon: Icon(Icons.link),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a unique URL identifier.';
                            }
                            if (!RegExp(r'^[a-z0-9-]+$').hasMatch(value)) {
                              return 'Only lowercase letters, numbers, and hyphens allowed.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24.0),
                        Text(
                          'Sports Offered',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        _isLoadingSports
                            ? const Center(child: CircularProgressIndicator())
                            : _sportsErrorMessage != null
                                ? Text(_sportsErrorMessage!, style: const TextStyle(color: Colors.red))
                                : Wrap(
                                    spacing: 8.0,
                                    children: _availableSports.map((sport) {
                                      final isSelected = _selectedSportIds.contains(sport.id);
                                      return ChoiceChip(
                                        label: Text(sport.name),
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
                                        selectedColor: Colors.blue.shade200,
                                        backgroundColor: Colors.grey.shade200,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      );
                                    }).toList(),
                                  ),
                        const SizedBox(height: 24.0),
                        Text(
                          'Academy Admin Details',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _adminUsernameController,
                          decoration: const InputDecoration(
                            labelText: 'Admin Username',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter admin username.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _adminEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Admin Email',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter admin email.';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _adminFirstNameController,
                          decoration: const InputDecoration(
                            labelText: 'Admin First Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter admin first name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _adminLastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Admin Last Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter admin last name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _adminPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Admin Password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter admin password.';
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
                            labelText: 'Confirm Admin Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm admin password.';
                            }
                            if (value != _adminPasswordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24.0),
                        ElevatedButton(
                          onPressed: _registerAcademy,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: Colors.green.shade200,
                          ),
                          child: const Text('Register Academy'),
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