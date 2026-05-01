import 'package:flutter/material.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_card.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  static const List<Map<String, dynamic>> _events = [
    {
      'title': 'Inter-Batch Tournament',
      'type': 'TOURNAMENT',
      'sport': 'Cricket',
      'day': '05',
      'month': 'MAR',
      'time': '9:00 AM',
      'venue': 'Main Ground, Elite Academy',
      // We will map colors dynamically in build based on type
    },
    {
      'title': 'Friendly Match – Blue vs Green',
      'type': 'MATCH',
      'sport': 'Badminton',
      'day': '12',
      'month': 'MAR',
      'time': '10:30 AM',
      'venue': 'Indoor Court 2',
    },
    {
      'title': 'Skills Assessment Day',
      'type': 'ASSESSMENT',
      'sport': 'All Sports',
      'day': '20',
      'month': 'MAR',
      'time': '8:00 AM',
      'venue': 'Academy Main Hall',
    },
    {
      'title': 'Season Closing Ceremony',
      'type': 'EVENT',
      'sport': 'All Sports',
      'day': '31',
      'month': 'MAR',
      'time': '6:00 PM',
      'venue': 'Elite Academy Auditorium',
    },
  ];

  Color _getColorForType(String type, EliteTheme theme) {
    switch (type) {
      case 'TOURNAMENT':
        return theme.error;
      case 'MATCH':
        return theme.accent; // Lime
      case 'ASSESSMENT':
        return Colors.purple.shade400;
      default:
        return theme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: const GlassHeader(title: "Events & Matches"),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: theme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surfaceContainerLowest.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: Icon(Icons.event, color: theme.surfaceContainerLowest, size: 32)
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Upcoming Events", style: theme.display2.copyWith(color: theme.surfaceContainerLowest)),
                      const SizedBox(height: 4),
                      Text("${_events.length} events this month", style: theme.body.copyWith(color: theme.surfaceContainerLowest.withOpacity(0.8))),
                    ],
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text("Schedule", style: theme.display2),
            ),
            const SizedBox(height: 16),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _events.length,
              itemBuilder: (context, i) => _buildEventCard(_events[i], theme),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> e, EliteTheme theme) {
    final color = _getColorForType(e['type'] as String, theme);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: EliteCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date block
            Container(
              width: 60,
              height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(e['day'] as String, style: theme.display2.copyWith(color: color)),
                  Text(e['month'] as String, style: theme.caption.copyWith(color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e['title'] as String, style: theme.subtitle),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(e['type'] as String,
                            style: theme.caption.copyWith(color: color, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: theme.secondaryText),
                      const SizedBox(width: 4),
                      Text(e['time'] as String, style: theme.caption.copyWith(color: theme.secondaryText)),
                      const SizedBox(width: 16),
                      Icon(Icons.location_on, size: 14, color: theme.secondaryText),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(e['venue'] as String,
                            style: theme.caption.copyWith(color: theme.secondaryText),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
