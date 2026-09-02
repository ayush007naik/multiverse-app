import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';
import 'counter_booking_process.dart';

class CounterBookingTab extends StatefulWidget {
  const CounterBookingTab({super.key});

  @override
  State<CounterBookingTab> createState() => _CounterBookingTabState();
}

class _CounterBookingTabState extends State<CounterBookingTab> {
  String? _selectedShowId;
  Map<String, dynamic>? _selectedShowData;

  static DateTime? _safeTime(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  static String? _posterUrl(Map<String, dynamic> show) {
    final raw = show['moviePoster'] ?? show['moviePosterUrl'];
    if (raw == null) return null;
    final url = raw.toString().trim();
    if (url.isEmpty || url.startsWith('https://via.placeholder.com')) return null;
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);

    if (_selectedShowId != null && _selectedShowData != null) {
      return CounterBookingProcess(
        showId: _selectedShowId!,
        showData: _selectedShowData!,
        onBack: () {
          setState(() {
            _selectedShowId = null;
            _selectedShowData = null;
          });
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: StreamBuilder<QuerySnapshot>(
        stream: theatreService.getShows(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
          }

          final shows = snapshot.data?.docs ?? [];
          // Filter shows that are upcoming or still ongoing (not ended yet)
          final upcomingShows = shows.where((doc) {
            final data = doc.data();
            final startTime = _safeTime(data, 'startTime');
            if (startTime == null) return false;
            final endTime = _safeTime(data, 'endTime') ?? startTime.add(const Duration(hours: 3));
            return endTime.isAfter(DateTime.now());
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('COUNTER BOOKING', style: Theme.of(context).textTheme.titleLarge),
                  const Text('Select a show to start walk-in booking', style: TextStyle(color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 32),
              
              // NEW: "NOW SHOWING" Top Banner
              if (upcomingShows.isNotEmpty)
                _buildNowShowingBanner(upcomingShows.first.data()),

              if (upcomingShows.isEmpty)
                const Expanded(
                  child: Center(child: Text('No active shows scheduled for today.')),
                )
              else
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: upcomingShows.length,
                    itemBuilder: (context, index) {
                      final showDoc = upcomingShows[index];
                      final showData = showDoc.data();
                      return _buildShowCard(context, showDoc.id, showData);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNowShowingBanner(Map<String, dynamic> show) {
    final posterUrl = _posterUrl(show);
    final startTime = _safeTime(show, 'startTime') ?? DateTime.now();

    return Container(
      height: 220,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 32),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: CyberpunkTheme.surface,
        boxShadow: [
          BoxShadow(
            color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: -10,
          )
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterUrl != null)
            Image.network(
              posterUrl,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: CyberpunkTheme.primaryNeon,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NOW SHOWING',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  show['movieTitle']?.toString().toUpperCase() ?? 'MOVIE',
                  style: GoogleFonts.orbitron(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2, height: 1),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.videocam_outlined, color: CyberpunkTheme.primaryNeon, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Screen ${show['screen']} • ${DateFormat('hh:mm a').format(startTime)}',
                      style: GoogleFonts.poppins(color: CyberpunkTheme.primaryNeon, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowCard(BuildContext context, String showId, Map<String, dynamic> show) {
    final startTime = _safeTime(show, 'startTime') ?? DateTime.now();
    final posterUrl = _posterUrl(show);
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedShowId = showId;
          _selectedShowData = show;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CyberpunkTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: posterUrl != null 
                ? Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: Colors.white24),
                  )
                : const Icon(Icons.movie, color: Colors.white24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (show['movieTitle'] ?? 'Movie Title').toString().toUpperCase(),
                    style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('hh:mm a').format(startTime)} • Screen ${show['screen']}',
                    style: GoogleFonts.poppins(color: CyberpunkTheme.primaryNeon, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${show['availableSeats']} seats left',
                    style: TextStyle(
                      color: (show['availableSeats'] ?? 0) < 10 ? Colors.redAccent : Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
