import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/watch_connection_provider.dart';

class WatchScanScreen extends ConsumerStatefulWidget {
  const WatchScanScreen({super.key});

  @override
  ConsumerState<WatchScanScreen> createState() => _WatchScanScreenState();
}

class _WatchScanScreenState extends ConsumerState<WatchScanScreen> {
  
  @override
  void initState() {
    super.initState();
    // Delay slightly before kicking off the scan
    Future.microtask(() => ref.read(watchConnectionProvider.notifier).startScan());
  }

  @override
  void deactivate() {
    ref.read(watchConnectionProvider.notifier).stopScan();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final watchState = ref.watch(watchConnectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect Watch & Track')),
      body: SafeArea(
        child: Column(
          children: [
            if (watchState.errorMessage != null)
              Container(
                color: Colors.redAccent,
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                child: Text(watchState.errorMessage!, style: const TextStyle(color: Colors.white)),
              ),
              
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    watchState.status == WatchConnectionState.scanning 
                        ? 'Scanning...' 
                        : (watchState.status == WatchConnectionState.connected ? 'Connected' : 'Disconnected'),
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  if (watchState.status == WatchConnectionState.scanning)
                    const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5A0))),
                ],
              ),
            ),
            
            Expanded(
              child: StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.scanResults,
                initialData: const [],
                builder: (c, snapshot) {
                  final results = snapshot.data ?? [];
                  if (results.isEmpty && watchState.status != WatchConnectionState.connected) {
                    return const Center(child: Text('No devices found yet.', style: TextStyle(color: Colors.white54)));
                  }
                  
                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final r = results[index];
                      // Filter tightly or show all BLE bounds
                      final name = r.device.platformName.isNotEmpty ? r.device.platformName : 'Unknown Device';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.watch, color: Color(0xFF00E5A0)),
                          title: Text(name),
                          subtitle: Text(r.device.remoteId.str),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: watchState.status == WatchConnectionState.connecting 
                                ? null 
                                : () => ref.read(watchConnectionProvider.notifier).connectToDevice(r.device),
                            child: const Text('Pair'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  if (watchState.status == WatchConnectionState.scanning) {
                    ref.read(watchConnectionProvider.notifier).stopScan();
                  } else {
                    ref.read(watchConnectionProvider.notifier).startScan();
                  }
                },
                icon: Icon(watchState.status == WatchConnectionState.scanning ? Icons.stop : Icons.search, color: const Color(0xFF0D1117)),
                label: Text(watchState.status == WatchConnectionState.scanning ? 'Stop Scan' : 'Scan Again', style: const TextStyle(color: Color(0xFF0D1117))),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
