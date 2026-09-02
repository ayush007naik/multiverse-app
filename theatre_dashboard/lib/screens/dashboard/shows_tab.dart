import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:intl/intl.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';
import '../../widgets/common/neon_button.dart';
import '../../widgets/show/add_show_dialog.dart';
import '../../widgets/show/live_seat_status_dialog.dart';

class ShowsTab extends StatelessWidget {
  const ShowsTab({super.key});

  static DateTime? safeStartTime(Map<String, dynamic> data) {
    final raw = data['startTime'];
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);

    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SHOW MANAGEMENT', style: Theme.of(context).textTheme.titleLarge),
                NeonButton(
                  text: 'CREATE NEW SHOW',
                  icon: Icons.calendar_month,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AddShowDialog(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: theatreService.getShows(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
                  }

                  final allShows = snapshot.data?.docs ?? [];

                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);

                  final validShows = allShows.where((doc) => safeStartTime(doc.data()) != null).toList();

                  final upcomingShows = validShows.where((doc) {
                    final startTime = safeStartTime(doc.data())!;
                    final startDay = DateTime(startTime.year, startTime.month, startTime.day);
                    return startDay.isAfter(today);
                  }).toList();

                  final currentShows = validShows.where((doc) {
                    final startTime = safeStartTime(doc.data())!;
                    final startDay = DateTime(startTime.year, startTime.month, startTime.day);
                    return startDay.isAtSameMomentAs(today);
                  }).toList();

                  final pastShows = validShows.where((doc) {
                    final startTime = safeStartTime(doc.data())!;
                    final startDay = DateTime(startTime.year, startTime.month, startTime.day);
                    return startDay.isBefore(today);
                  }).toList();

                  return Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          labelColor: CyberpunkTheme.primaryNeon,
                          unselectedLabelColor: Colors.white54,
                          indicator: BoxDecoration(
                            color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          tabs: [
                            Tab(text: 'UPCOMING (${upcomingShows.length})'),
                            Tab(text: 'CURRENT (${currentShows.length})'),
                            Tab(text: 'PAST (${pastShows.length})'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildShowList(context, upcomingShows, 'No upcoming shows'),
                            _buildShowList(context, currentShows, 'No current shows'),
                            _buildShowList(context, pastShows, 'No past shows'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowList(BuildContext context, List<QueryDocumentSnapshot> shows, String emptyText) {
    if (shows.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.builder(
      itemCount: shows.length,
      itemBuilder: (context, index) {
        final showDoc = shows[index];
        final showData = showDoc.data();
        return _buildShowListItem(context, showDoc.id, showData);
      },
    );
  }

  Widget _buildShowListItem(BuildContext context, String showId, Map<String, dynamic> show) {
    final startTime = safeStartTime(show) ?? DateTime.now();
    final theatreService = Provider.of<TheatreService>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyberpunkTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(startTime).toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('dd').format(startTime),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: CyberpunkTheme.primaryNeon),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  show['movieTitle'] ?? 'Movie Title',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Screen: ${show['screen']} • Time: ${DateFormat('hh:mm a').format(startTime)}',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          _buildPricingInfo(show['pricing'] ?? {}),
          const SizedBox(width: 24),
          _buildSeatInfo(show['availableSeats'] ?? 0, show['totalSeats'] ?? 0),
          const SizedBox(width: 24),
          NeonButton(
            text: 'VIEW SEATS',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => LiveSeatStatusDialog(
                  showId: showId,
                  showData: show,
                ),
              );
            },
            color: Colors.white54,
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white54),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AddShowDialog(
                  showId: showId,
                  showData: show,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: CyberpunkTheme.surface,
                  title: const Text('Delete Show?'),
                  content: const Text('This will permanently remove this show. Are you sure?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await theatreService.deleteShow(showId);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPricingInfo(Map<dynamic, dynamic> pricing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: pricing.entries.map((e) {
        return Text(
          '${e.key}: ₹${e.value}',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        );
      }).toList(),
    );
  }

  Widget _buildSeatInfo(int available, int total) {
    double percent = total > 0 ? available / total : 0;
    Color color = percent > 0.5 ? Colors.greenAccent : (percent > 0.2 ? Colors.amberAccent : Colors.redAccent);

    return Column(
      children: [
        Text('$available / $total', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const Text('SEATS', style: TextStyle(fontSize: 10, color: Colors.white24)),
      ],
    );
  }
}
