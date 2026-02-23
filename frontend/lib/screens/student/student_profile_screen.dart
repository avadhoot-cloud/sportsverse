import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';
import 'package:sportsverse_app/api/student_api.dart';
import 'package:sportsverse_app/api/coach_api.dart';
import 'package:sportsverse_app/models/user.dart';

// ─── DUPR helpers (same scale as dashboard) ───────────────────────────────────
String _duprTierLabel(double r) {
  if (r >= 6.0) return 'Elite';
  if (r >= 4.5) return 'Advanced';
  if (r >= 3.0) return 'Intermediate';
  return 'Beginner';
}
Color _duprTierColor(double r) {
  if (r >= 6.0) return const Color(0xFFE65100);
  if (r >= 4.5) return const Color(0xFF2E7D32);
  if (r >= 3.0) return const Color(0xFF1565C0);
  return const Color(0xFF6A1B9A);
}

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _parentEmailController = TextEditingController();
  String _selectedGender = 'M';
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user != null) {
      _firstNameController.text = user.firstName ?? '';
      _lastNameController.text = user.lastName ?? '';
      _emailController.text = user.email ?? '';
      _phoneController.text = user.phoneNumber ?? '';
      _addressController.text = user.address ?? '';
      _parentNameController.text = user.parentName ?? '';
      _parentPhoneController.text = user.parentPhoneNumber ?? '';
      _parentEmailController.text = user.parentEmail ?? '';
      _selectedGender = user.gender ?? 'M';
      _selectedDateOfBirth = user.dateOfBirth != null 
          ? DateTime.parse(user.dateOfBirth!) 
          : null;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      
      if (image != null) {
        print('📸 Frontend: Selected image: ${image.path}');
        print('📸 Frontend: Image name: ${image.name}');
        print('📸 Frontend: Image mime type: ${image.mimeType}');
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print('📸 Frontend: Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      
      if (image != null) {
        print('📸 Frontend: Captured image: ${image.path}');
        print('📸 Frontend: Image name: ${image.name}');
        print('📸 Frontend: Image mime type: ${image.mimeType}');
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print('📸 Frontend: Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _takePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Prepare profile data
      Map<String, dynamic> profileData = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'phone_number': _phoneController.text,
        'address': _addressController.text,
        'gender': _selectedGender,
        'parent_name': _parentNameController.text,
        'parent_phone_number': _parentPhoneController.text,
        'parent_email': _parentEmailController.text,
      };

      // Add date of birth if selected
      if (_selectedDateOfBirth != null) {
        profileData['date_of_birth'] = _selectedDateOfBirth!.toIso8601String().split('T')[0];
      }

      // Upload profile photo if selected
      if (_selectedImage != null) {
        try {
          final photoUrl = await StudentApi.uploadProfilePhoto(_selectedImage!.path);
          profileData['profile_photo'] = photoUrl;
        } catch (e) {
          print('Error uploading photo: $e');
          // Continue without photo if upload fails
        }
      }

      // Update profile
      print('💾 Updating profile with data: $profileData');
      final updatedProfile = await StudentApi.updateProfile(profileData);
      print('💾 Profile update response: $updatedProfile');
      
      // Debug: Check database state
      print('🔍 Checking database state after update...');
      try {
        final debugData = await StudentApi.debugProfile();
        print('🔍 Database debug data: $debugData');
      } catch (e) {
        print('🔍 Debug check failed: $e');
      }
      
      // Update AuthProvider with new user data
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      print('💾 Creating User object from response...');
      final updatedUser = User.fromJson(updatedProfile);
      print('💾 User object created successfully: ${updatedUser.username}');
      authProvider.updateUser(updatedUser);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _logout() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.logout();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: const Color(0xFF006C62),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _toggleEdit,
                )
              else
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveProfile,
                ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _showLogoutConfirmation,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photo Section
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color(0xFF006C62),
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty)
                                  ? NetworkImage(user.profilePhoto!)
                                  : null,
                          child: _selectedImage == null && (user?.profilePhoto == null || (user?.profilePhoto != null && user!.profilePhoto!.isEmpty))
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showImagePicker,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF006C62),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Personal Information Section
                  _buildSectionHeader('Personal Information'),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: 'First Name',
                          enabled: _isEditing,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'First name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          enabled: _isEditing,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Last name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    enabled: _isEditing,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Gender and Date of Birth
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          label: 'Gender',
                          value: _selectedGender,
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('Male')),
                            DropdownMenuItem(value: 'F', child: Text('Female')),
                            DropdownMenuItem(value: 'O', child: Text('Other')),
                          ],
                          onChanged: _isEditing ? (value) {
                            setState(() {
                              _selectedGender = value!;
                            });
                          } : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateField(
                          label: 'Date of Birth',
                          value: _selectedDateOfBirth,
                          onTap: _isEditing ? _selectDateOfBirth : null,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _addressController,
                    label: 'Address',
                    enabled: _isEditing,
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Parent/Guardian Information
                  _buildSectionHeader('Parent/Guardian Information'),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _parentNameController,
                    label: 'Parent/Guardian Name',
                    enabled: _isEditing,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _parentPhoneController,
                    label: 'Parent/Guardian Phone',
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _parentEmailController,
                    label: 'Parent/Guardian Email',
                    enabled: _isEditing,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  
                  const SizedBox(height: 32),

                  // ── DUPR Rating Section ─────────────────────────────────────
                  _buildSectionHeader('My DUPR Rating'),
                  const SizedBox(height: 4),
                  const Text(
                    'Your internal skill rating for each sport',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _buildDuprSection(),

                  const SizedBox(height: 32),

                  // Action Buttons
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006C62),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Save Changes'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _loadProfileData(); // Reset form
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF006C62),
                              side: const BorderSide(color: Color(0xFF006C62)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C3E50),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF006C62)),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF006C62)),
        ),
        filled: onChanged == null,
        fillColor: onChanged == null ? Colors.grey.shade100 : null,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF006C62)),
          ),
          filled: onTap == null,
          fillColor: onTap == null ? Colors.grey.shade100 : null,
        ),
        child: Text(
          value != null
              ? '${value.day}/${value.month}/${value.year}'
              : 'Select date',
          style: TextStyle(
            color: value != null ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // ── DUPR Rating Section ────────────────────────────────────────────────────

  Widget _buildDuprSection() {
    // Provisional defaults – replaced by real API data in PR2
    const double singlesRating = 4.000;
    const double doublesRating = 4.000;
    const int matchesSingles = 0;
    const int matchesDoubles = 0;
    const int reliability = 0;
    final bool isProvisional = matchesSingles < 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two rating tiles side-by-side
        Row(
          children: [
            Expanded(child: _duprRatingTile("Singles", singlesRating, matchesSingles)),
            const SizedBox(width: 12),
            Expanded(child: _duprRatingTile("Doubles", doublesRating, matchesDoubles)),
          ],
        ),
        const SizedBox(height: 14),

        // Reliability bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7F4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Rating Reliability",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text("$reliability / 100",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF006C62))),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: reliability / 100,
                  backgroundColor: const Color(0xFF006C62).withOpacity(0.1),
                  color: const Color(0xFF006C62),
                  minHeight: 8,
                ),
              ),
              if (isProvisional) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 13, color: Color(0xFF006C62)),
                    const SizedBox(width: 6),
                    Text(
                      "Play ${10 - matchesSingles} more match(es) to establish rating",
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF006C62)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Recent changes (placeholder until PR2)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Recent Rating Changes",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: coachApi.getMyRatingHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator()));
                  }
                  final entries = snapshot.data ?? [];
                  if (entries.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Icon(Icons.history, color: Colors.grey, size: 32),
                            SizedBox(height: 8),
                            Text("No matches recorded yet",
                                style: TextStyle(color: Colors.grey, fontSize: 12)),
                            SizedBox(height: 4),
                            Text(
                                "Your rating history will appear here once\nyou play your first rated match.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: entries.map((e) {
                      final delta = (e['delta'] as num).toDouble();
                      final isPos = delta >= 0;
                      final format = e['format'] as String? ?? '';
                      final date = e['date'] as String? ?? '';
                      final oldR = (e['old_rating'] as num).toDouble();
                      final newR = (e['new_rating'] as num).toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: isPos ? Colors.green.shade50 : Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPos ? Icons.trending_up : Icons.trending_down,
                                color: isPos ? Colors.green : Colors.red,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$format match',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  Text(date,
                                      style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(newR.toStringAsFixed(3),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${isPos ? '+' : ''}${delta.toStringAsFixed(3)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isPos ? Colors.green.shade700 : Colors.red.shade700)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _duprRatingTile(String format, double rating, int matches) {
    final color = _duprTierColor(rating);
    final tier = _duprTierLabel(rating);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(format,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 6),
          Text(rating.toStringAsFixed(3),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black87)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tier,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10)),
              ),
              const Spacer(),
              Text("$matches matches",
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
