// sportsverse/frontend/sportsverse_app/lib/screens/academy_admin/add_student_enrollment_screen.dart

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/batch_api.dart';
import 'package:sportsverse_app/models/batch.dart';

class AddStudentEnrollmentScreen extends StatefulWidget {
  const AddStudentEnrollmentScreen({super.key});

  @override
  State<AddStudentEnrollmentScreen> createState() =>
      _AddStudentEnrollmentScreenState();
}

class _AddStudentEnrollmentScreenState
    extends State<AddStudentEnrollmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Student Information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _parentEmailController = TextEditingController();

  DateTime? _dateOfBirth;
  String _gender = 'M';

  // Enrollment Information
  List<Batch> batches = [];
  Batch? _selectedBatch;
  String _enrollmentType = 'SESSION_BASED';
  final _totalSessionsController = TextEditingController();
  DateTime? _endDate;

  bool isLoading = false;
  bool isLoadingBatches = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final loadedBatches = await batchApi.getBatches();
      setState(() {
        batches = loadedBatches.where((batch) => batch.isActive).toList();
        isLoadingBatches = false;
      });
    } catch (e) {
      setState(() {
        isLoadingBatches = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load batches: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
    _totalSessionsController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isDateOfBirth) async {
    final initialDate = isDateOfBirth
        ? DateTime.now().subtract(
            const Duration(days: 365 * 10),
          ) // 10 years ago
        : _endDate ?? DateTime.now().add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: isDateOfBirth ? DateTime(1950) : DateTime.now(),
      lastDate: isDateOfBirth ? DateTime.now() : DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isDateOfBirth) {
          _dateOfBirth = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Build payload without nulls (DRF optional fields usually disallow null)
      final Map<String, dynamic> studentEnrollmentData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'date_of_birth': _dateOfBirth!.toIso8601String().split('T')[0],
        'address': _addressController.text, // allow blank string
        'batch': _selectedBatch!.id,
        'enrollment_type': _enrollmentType,
      };

      if (_emailController.text.isNotEmpty) {
        studentEnrollmentData['email'] = _emailController.text.trim();
      }
      if (_phoneController.text.isNotEmpty) {
        studentEnrollmentData['phone_number'] = _phoneController.text.trim();
      }
      if (_gender != null && _gender!.isNotEmpty) {
        studentEnrollmentData['gender'] = _gender;
      }
      if (_parentNameController.text.isNotEmpty) {
        studentEnrollmentData['parent_name'] = _parentNameController.text.trim();
      }
      if (_parentPhoneController.text.isNotEmpty) {
        studentEnrollmentData['parent_phone_number'] = _parentPhoneController.text.trim();
      }
      if (_parentEmailController.text.isNotEmpty) {
        studentEnrollmentData['parent_email'] = _parentEmailController.text.trim();
      }

      if (_enrollmentType == 'SESSION_BASED') {
        studentEnrollmentData['total_sessions'] = int.parse(_totalSessionsController.text);
      } else if (_enrollmentType == 'DURATION_BASED' && _endDate != null) {
        studentEnrollmentData['end_date'] = _endDate!.toIso8601String().split('T')[0];
      }

      await batchApi.createStudentEnrollment(studentEnrollmentData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Student enrolled successfully! Enrollment will start when first attendance is taken.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to enroll student: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student & Enrollment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      body: isLoadingBatches
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildStudentBasicInfoPage(),
                  _buildStudentContactInfoPage(),
                  _buildEnrollmentInfoPage(),
                ],
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentPage > 0)
              ElevatedButton(
                onPressed: _previousPage,
                child: const Text('Previous'),
              )
            else
              const SizedBox(),

            if (_currentPage < 2)
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Next'),
              )
            else
              ElevatedButton(
                onPressed: isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enroll Student'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Student Basic Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name *',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'First name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name *',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Last name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          ListTile(
            title: const Text('Date of Birth *'),
            subtitle: Text(
              _dateOfBirth != null
                  ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                  : 'Select date of birth',
            ),
            leading: const Icon(Icons.cake),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context, true),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(Icons.wc),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'M', child: Text('Male')),
              DropdownMenuItem(value: 'F', child: Text('Female')),
              DropdownMenuItem(value: 'O', child: Text('Other')),
            ],
            onChanged: (value) {
              setState(() {
                _gender = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentContactInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email (Optional)',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number (Optional)',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address (Optional)',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          const Text(
            'Parent/Guardian Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _parentNameController,
            decoration: const InputDecoration(
              labelText: 'Parent/Guardian Name',
              prefixIcon: Icon(Icons.family_restroom),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _parentPhoneController,
            decoration: const InputDecoration(
              labelText: 'Parent/Guardian Phone',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _parentEmailController,
            decoration: const InputDecoration(
              labelText: 'Parent/Guardian Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enrollment Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          DropdownButtonFormField<Batch>(
            value: _selectedBatch,
            decoration: const InputDecoration(
              labelText: 'Select Batch *',
              prefixIcon: Icon(Icons.batch_prediction),
              border: OutlineInputBorder(),
            ),
            items: batches.map((batch) {
              return DropdownMenuItem(
                value: batch,
                child: Text(
                  '${batch.name} (${batch.branchName} - ${batch.sportName})',
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBatch = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select a batch';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _enrollmentType,
            decoration: const InputDecoration(
              labelText: 'Enrollment Type *',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'SESSION_BASED',
                child: Text('Session Based'),
              ),
              DropdownMenuItem(
                value: 'DURATION_BASED',
                child: Text('Duration Based'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _enrollmentType = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          if (_enrollmentType == 'SESSION_BASED')
            TextFormField(
              controller: _totalSessionsController,
              decoration: const InputDecoration(
                labelText: 'Total Sessions *',
                hintText: '20',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (_enrollmentType == 'SESSION_BASED' &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Total sessions is required for session-based enrollment';
                }
                if (value != null &&
                    value.isNotEmpty &&
                    int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),

          if (_enrollmentType == 'DURATION_BASED')
            ListTile(
              title: const Text('End Date (Optional)'),
              subtitle: Text(
                _endDate != null
                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                    : 'Select end date (defaults to 30 days from first attendance)',
              ),
              leading: const Icon(Icons.calendar_today),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDate(context, false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.info, color: Colors.blue, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Enrollment Start Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'The enrollment will officially start when the first attendance is taken. Until then, the student will be registered but enrollment status will show as "Not Started".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
