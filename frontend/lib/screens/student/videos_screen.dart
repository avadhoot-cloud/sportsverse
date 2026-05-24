import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/api/student_api.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await StudentApi.getTrainingVideos();
      if (mounted) {
        setState(() {
          _videos = videos;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _videoUrl(Map<String, dynamic> v) {
    final file = v['video_file']?.toString() ?? '';
    if (file.isEmpty) return '';
    if (file.startsWith('http')) return file;
    final base = ApiClient.baseUrl.endsWith('/')
        ? ApiClient.baseUrl.substring(0, ApiClient.baseUrl.length - 1)
        : ApiClient.baseUrl;
    return '$base$file';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text(
          'Training Videos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B3D2F)))
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : RefreshIndicator(
                  onRefresh: _loadVideos,
                  child: _videos.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No training videos assigned yet')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _videos.length,
                          itemBuilder: (context, index) {
                            final v = _videos[index];
                            final title = v['title']?.toString() ?? 'Training Video';
                            final batch = v['batch_name']?.toString() ?? 'Batch';
                            final branch = v['branch_name']?.toString() ?? '';
                            final uploaded = v['uploaded_at']?.toString().split('T').first ?? '';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B3D2F).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.play_circle_fill, color: Color(0xFF1B3D2F)),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  [batch, branch, uploaded].where((s) => s.isNotEmpty).join(' · '),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  final url = _videoUrl(v);
                                  if (url.isNotEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Video: $url')),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
