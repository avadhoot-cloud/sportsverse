import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio_pkg;

class SendVideoScreen extends StatefulWidget {
  const SendVideoScreen({super.key});

  @override
  State<SendVideoScreen> createState() => _SendVideoScreenState();
}

class _SendVideoScreenState extends State<SendVideoScreen> {
  final TextEditingController _titleController = TextEditingController();
  File? _videoFile;
  bool _isUploading = false;

  List<dynamic> _branches = [];
  List<dynamic> _batches = [];
  List<dynamic> _students = [];

  String? _selectedBranch;
  String? _selectedBatch;
  List<int> _selectedStudentIds = []; // THIS HOLDS THE TARGETED STUDENTS

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  // --- API FETCHERS ---
  Future<void> _fetchBranches() async {
    try {
      final dio = dio_pkg.Dio();
      final response = await dio.get("http://10.0.2.2:8000/api/organizations/branches/");
      setState(() => _branches = response.data);
    } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _fetchBatches(String branchId) async {
    try {
      final dio = dio_pkg.Dio();
      final response = await dio.get("http://10.0.2.2:8000/api/organizations/batches/?branch=$branchId");
      setState(() {
        _batches = response.data;
        _selectedBatch = null;
        _students = [];
        _selectedStudentIds = [];
      });
    } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _fetchStudents(String batchId) async {
    try {
      final dio = dio_pkg.Dio();
      final response = await dio.get("http://10.0.2.2:8000/api/accounts/students/?batch=$batchId");
      setState(() => _students = response.data);
    } catch (e) { debugPrint("Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Send Targeted Video"), backgroundColor: const Color(0xFF00796B)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField("Video Title", _titleController),
            const SizedBox(height: 20),
            _buildFilePicker(),
            const Divider(height: 40),
            
            const Text("Step 1: Select Branch", style: TextStyle(fontWeight: FontWeight.bold)),
            _buildDropdown(_branches, _selectedBranch, (val) {
              setState(() => _selectedBranch = val);
              if (val != null) _fetchBatches(val);
            }),

            const Text("Step 2: Select Batch", style: TextStyle(fontWeight: FontWeight.bold)),
            _buildDropdown(_batches, _selectedBatch, (val) {
              setState(() => _selectedBatch = val);
              if (val != null) _fetchStudents(val);
            }),

            if (_students.isNotEmpty) ...[
              const Text("Step 3: Target Specific Students (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
              const Text("If none selected, all students in batch will receive it.", style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _students.map((student) {
                  final isSelected = _selectedStudentIds.contains(student['id']);
                  return FilterChip(
                    label: Text(student['first_name']),
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
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 40),
            _buildUploadButton(),
          ],
        ),
      ),
    );
  }

  // UI Helper methods...
  Widget _buildDropdown(List<dynamic> items, String? value, Function(String?) onChanged) {
    bool exists = items.any((i) => i['id'].toString() == value);
    return DropdownButton<String>(
      isExpanded: true,
      value: exists ? value : null,
      items: items.map((i) => DropdownMenuItem<String>(
        value: i['id'].toString(), 
        child: Text(i['name'] ?? i['first_name'] ?? "No Name")
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(controller: controller, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
  }

  Widget _buildFilePicker() {
    return ElevatedButton.icon(
      onPressed: () async {
        FilePickerResult? r = await FilePicker.platform.pickFiles(type: FileType.video);
        if (r != null) setState(() => _videoFile = File(r.files.single.path!));
      },
      icon: const Icon(Icons.video_call),
      label: Text(_videoFile == null ? "Select Video File" : "Video Selected"),
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), padding: const EdgeInsets.all(15)),
        onPressed: _isUploading ? null : _upload,
        child: _isUploading ? const CircularProgressIndicator() : const Text("UPLOAD & SEND", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _upload() async {
    if (_videoFile == null || _selectedBatch == null) return;
    setState(() => _isUploading = true);
    try {
      final dio = dio_pkg.Dio();
      dio_pkg.FormData formData = dio_pkg.FormData.fromMap({
        "title": _titleController.text,
        "batch": _selectedBatch,
        "target_students": _selectedStudentIds, // SENDING TARGET DATA
        "video_file": await dio_pkg.MultipartFile.fromFile(_videoFile!.path),
      });
      await dio.post("http://10.0.2.2:8000/api/academy-contents/videos/", data: formData);
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }
}