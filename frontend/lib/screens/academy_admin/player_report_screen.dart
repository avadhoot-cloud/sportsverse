import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:sportsverse_app/api/api_client.dart';
import 'dart:convert';

class PlayerReportScreen extends StatefulWidget {
  const PlayerReportScreen({super.key});

  @override
  State<PlayerReportScreen> createState() => _PlayerReportScreenState();
}

class _PlayerReportScreenState extends State<PlayerReportScreen> {
  final TextEditingController _titleController = TextEditingController();

  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  String? _filePath;

  String? _selectedBranch;
  String? _selectedBatch;
  List<int> _selectedStudentIds = [];
  bool _isUploading = false;

  List<dynamic> _branches = [];
  List<dynamic> _batches = [];
  List<dynamic> _students = [];

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await apiClient.get('/api/organizations/branches/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() => _branches = data);
      }
    } catch (e) {
      debugPrint("Branch Fetch Failed: $e");
    }
  }

  Future<void> _fetchBatches(String branchId) async {
    try {
      final response = await apiClient.get('/api/organizations/batches/?branch=$branchId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _batches = data;
          _selectedBatch = null;
          _students = [];
        });
      }
    } catch (e) {
      debugPrint("Batch Fetch Failed: $e");
    }
  }

  Future<void> _fetchStudents(String batchId) async {
    try {
      final response = await apiClient.get('/api/organizations/enrollments/?batch=$batchId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _students = data.map((e) => {
            'id': e['student'],
            'first_name': e['student_name'],
            'last_name': e['student_last_name'],
          }).toList();
          _selectedStudentIds = [];
        });
      }
    } catch (e) {
      debugPrint("Student Fetch Failed: $e");
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      withData: kIsWeb,
    );

    if (result != null) {
      final file = result.files.first;
      setState(() {
        _selectedFile = file;
        _fileBytes = file.bytes;
        _filePath = file.path;
      });
    }
  }

  bool get _hasFile =>
      _selectedFile != null && (_fileBytes != null || (_filePath != null && _filePath!.isNotEmpty));

  Future<dio_pkg.MultipartFile> _buildReportMultipart() async {
    final filename = _selectedFile!.name;
    if (_fileBytes != null) {
      return dio_pkg.MultipartFile.fromBytes(_fileBytes!, filename: filename);
    }
    if (!kIsWeb && _filePath != null) {
      return dio_pkg.MultipartFile.fromFile(_filePath!, filename: filename);
    }
    throw Exception('Could not read selected file');
  }

  Future<void> _handleReportUpload() async {
    if (_titleController.text.trim().isEmpty) {
      _showMessage('Please enter a report title', Colors.orange);
      return;
    }
    if (_selectedBranch == null || _selectedBatch == null) {
      _showMessage('Please select branch and batch', Colors.orange);
      return;
    }
    if (_selectedStudentIds.isEmpty) {
      _showMessage('Please select at least one student', Colors.orange);
      return;
    }
    if (!_hasFile) {
      _showMessage('Please select a file to upload', Colors.orange);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final dio = dio_pkg.Dio();
      final String? token = apiClient.getToken();
      final multipart = await _buildReportMultipart();

      final formData = dio_pkg.FormData.fromMap({
        'title': _titleController.text.trim(),
        'branch': _selectedBranch,
        'batch': _selectedBatch,
        'student_ids': _selectedStudentIds.join(','),
        'report_file': multipart,
      });

      final response = await dio.post(
        '${ApiClient.baseUrl}/api/reports/upload/',
        data: formData,
        options: dio_pkg.Options(
          headers: {
            'Authorization': 'Token $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          _showMessage('Report uploaded successfully!', Colors.green);
          _resetForm();
        }
      }
    } on dio_pkg.DioException catch (e) {
      final serverMessage = e.response?.data ?? e.message;
      if (mounted) {
        _showMessage('Upload failed: $serverMessage', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Upload failed: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _selectedFile = null;
      _fileBytes = null;
      _filePath = null;
      _selectedStudentIds = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('Upload Student Reports'),
        backgroundColor: const Color(0xFF137A74),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildUploadReportSection(),
      ),
    );
  }

  Widget _buildUploadReportSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF137A74), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF137A74),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Text(
              'Send Report to Student Database',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputLabel('Report Title'),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Monthly Performance',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInputLabel('File Attachment'),
                _buildFilePickerUI(),
                const SizedBox(height: 16),
                _buildDropdown('Select Branch', _branches, _selectedBranch, (val) {
                  setState(() {
                    _selectedBranch = val;
                    _selectedBatch = null;
                    _students = [];
                  });
                  if (val != null) _fetchBatches(val);
                }),
                const SizedBox(height: 16),
                _buildDropdown('Select Batch', _batches, _selectedBatch, (val) {
                  setState(() {
                    _selectedBatch = val;
                    _selectedStudentIds = [];
                  });
                  if (val != null) _fetchStudents(val);
                }),
                const SizedBox(height: 16),
                _buildInputLabel('Select Individual Students'),
                _buildStudentChips(),
                const SizedBox(height: 24),
                _buildUploadButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List items, String? value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: items.any((i) => i['id'].toString() == value) ? value : null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10),
          ),
          items: items.map((i) => DropdownMenuItem<String>(
            value: i['id'].toString(),
            child: Text(
              i['name'] ?? i['first_name'] ?? 'Unknown',
              overflow: TextOverflow.ellipsis,
            ),
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildFilePickerUI() {
    return InkWell(
      onTap: _pickFile,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedFile == null ? 'Choose PDF or Image' : _selectedFile!.name,
                style: TextStyle(color: _selectedFile == null ? Colors.grey : Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_hasFile)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentChips() {
    if (_students.isEmpty) {
      return const Text(
        'Select a Batch to see students',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 8,
      children: _students.map((s) {
        final int id = s['id'];
        final bool isSelected = _selectedStudentIds.contains(id);
        final name = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
        return FilterChip(
          label: Text(name.isEmpty ? 'Student #$id' : name),
          selected: isSelected,
          onSelected: (bool selected) {
            setState(() {
              if (selected) {
                _selectedStudentIds.add(id);
              } else {
                _selectedStudentIds.remove(id);
              }
            });
          },
          selectedColor: const Color(0xFF137A74).withOpacity(0.2),
          checkmarkColor: const Color(0xFF137A74),
        );
      }).toList(),
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF137A74),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _isUploading ? null : _handleReportUpload,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.cloud_upload, color: Colors.white),
        label: Text(
          _isUploading ? 'Uploading...' : 'Push Report to Student Portal',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Color(0xFF137A74),
        ),
      ),
    );
  }
}
