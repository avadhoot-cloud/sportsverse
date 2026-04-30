import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:sportsverse_app/api/api_client.dart';

class SendVideoScreen extends StatefulWidget {
  const SendVideoScreen({super.key});

  @override
  State<SendVideoScreen> createState() => _SendVideoScreenState();
}

class _SendVideoScreenState extends State<SendVideoScreen> {
  final TextEditingController _titleController = TextEditingController();
  
  PlatformFile? _pickedFile; 
  bool _isUploading = false;

  List<dynamic> _branches = [];
  List<dynamic> _batches = [];
  List<dynamic> _students = [];

  String? _selectedBranch;
  String? _selectedBatch;
  List<int> _selectedStudentIds = [];

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  // --- API FETCHERS ---

  Future<void> _fetchBranches() async {
    try {
      final dio = dio_pkg.Dio();
      final String? token = apiClient.getToken(); 

      final response = await dio.get(
        "${ApiClient.baseUrl}/api/organizations/branches/",
        options: dio_pkg.Options(headers: {"Authorization": "Token $token"}),
      );
      
      setState(() => _branches = response.data);
      debugPrint("✅ Branches Unlocked");
    } catch (e) { 
      debugPrint("❌ Branch Fetch Error: $e"); 
    }
  }

  Future<void> _fetchBatches(String branchId) async {
    try {
      final dio = dio_pkg.Dio();
      final String? token = apiClient.getToken();

      final response = await dio.get(
        "${ApiClient.baseUrl}/api/organizations/batches/?branch=$branchId",
        options: dio_pkg.Options(headers: {"Authorization": "Token $token"}),
      );

      setState(() {
        _batches = response.data;
        _selectedBatch = null;
        _students = [];
        _selectedStudentIds = [];
      });
    } catch (e) { debugPrint("❌ Batch Error: $e"); }
  }

Future<void> _fetchStudents(String batchId) async {
    try {
      final dio = dio_pkg.Dio();
      final String? token = apiClient.getToken();

      // DYNAMIC: Filtering students by the specific batchId selected in Step 2
      final response = await dio.get(
        "${ApiClient.baseUrl}/api/accounts/students/?batch=$batchId",
        options: dio_pkg.Options(headers: {"Authorization": "Token $token"}),
      );

      setState(() {
        _students = response.data; // This now contains ONLY students in this batch
        _selectedStudentIds = [];  // Reset selections when batch changes
      });
      
      debugPrint("✅ Fetched ${_students.length} students for Batch $batchId");
    } catch (e) { 
      debugPrint("❌ Student Fetch Error: $e"); 
    }
  }
  // --- LOGIC ---

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true, 
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

Future<void> _upload() async {
    if (_pickedFile == null || _selectedBatch == null || _selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select Video, Branch, and Batch"))
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final dio = dio_pkg.Dio();
      final String? token = apiClient.getToken();

      dio_pkg.MultipartFile multipartFile;
      if (kIsWeb) {
        multipartFile = dio_pkg.MultipartFile.fromBytes(_pickedFile!.bytes!, filename: _pickedFile!.name);
      } else {
        multipartFile = await dio_pkg.MultipartFile.fromFile(_pickedFile!.path!, filename: _pickedFile!.name);
      }

      // FIX: Added 'organization' and 'branch' which the server requested (400 error)
      dio_pkg.FormData formData = dio_pkg.FormData.fromMap({
        "title": _titleController.text,
        "organization": 1, // Assuming Org ID 1 for now, or fetch from your user profile
        "branch": _selectedBranch, 
        "batch": _selectedBatch,
        "target_students": _selectedStudentIds, 
        "video_file": multipartFile,
      });

      final response = await dio.post(
        "${ApiClient.baseUrl}/api/academy-contents/videos/", 
        data: formData,
        options: dio_pkg.Options(headers: {"Authorization": "Token $token"}),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video Sent!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } on dio_pkg.DioException catch (e) {
      debugPrint("❌ SERVER ERROR: ${e.response?.data}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.response?.data}"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Send Video"), 
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Video Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController, 
              decoration: const InputDecoration(labelText: "Title (e.g. Batting Drills)", border: OutlineInputBorder())
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickVideo, 
                icon: const Icon(Icons.video_library),
                label: Text(_pickedFile == null ? "Select Video" : "Selected: ${_pickedFile!.name}"),
              ),
            ),
            const Divider(height: 40),
            const Text("Recipients", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            _buildDropdown("Select Branch", _branches, _selectedBranch, (val) {
              setState(() => _selectedBranch = val);
              if (val != null) _fetchBatches(val);
            }),
            const SizedBox(height: 20),
            _buildDropdown("Select Batch", _batches, _selectedBatch, (val) {
              setState(() => _selectedBatch = val);
              if (val != null) _fetchStudents(val);
            }),
            const SizedBox(height: 20),
            if (_students.isNotEmpty) ...[
               const Text("Target Specific Students (Optional)", style: TextStyle(fontSize: 12, color: Colors.grey)),
               const SizedBox(height: 10),
               _buildStudentSelection(),
            ],
            const SizedBox(height: 40),
            _buildUploadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List items, String? value, Function(String?) onChanged) {
    bool exists = items.any((i) => i['id']?.toString() == value);
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      value: exists ? value : null,
      items: items.map((i) => DropdownMenuItem<String>(
        value: i['id'].toString(), 
        child: Text(i['name'] ?? i['first_name'] ?? i['branch_name'] ?? "No Name")
      )).toList(),
      onChanged: onChanged,
    );
  }

Widget _buildStudentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Step 3: Target Specific Students (Optional)", 
          style: TextStyle(fontWeight: FontWeight.bold)),
        const Text("Only students enrolled in this batch are shown below:", 
          style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: _students.map((student) {
            final isSelected = _selectedStudentIds.contains(student['id']);
            
            // DYNAMIC NAME: Pulls from the Serializer we updated earlier
            String displayName = student['first_name'] ?? 
                                student['user']?['first_name'] ?? 
                                "Student #${student['id']}";

            return FilterChip(
              label: Text(displayName),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedStudentIds.add(student['id']);
                  } else {
                    _selectedStudentIds.remove(student['id']);
                  }
                });
              },
              selectedColor: const Color(0xFF00796B).withOpacity(0.2),
              checkmarkColor: const Color(0xFF00796B),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00796B), 
          padding: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
        ),
        onPressed: _isUploading ? null : _upload,
        child: _isUploading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
          : const Text("UPLOAD & SEND VIDEO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}