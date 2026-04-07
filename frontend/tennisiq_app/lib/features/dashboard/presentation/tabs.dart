import 'package:flutter/material.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Dashboard (Analytics Overview)', style: TextStyle(color: Colors.white, fontSize: 18)));
  }
}

class StartSessionTab extends StatelessWidget {
  const StartSessionTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Start Session (Camera/Watch)', style: TextStyle(color: Colors.white, fontSize: 18)));
  }
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Session History', style: TextStyle(color: Colors.white, fontSize: 18)));
  }
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
