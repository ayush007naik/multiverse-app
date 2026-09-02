import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cinema_service.dart';
import '../widgets/trailer_player.dart';
import 'movie_seat_selection_screen.dart';
import '../core/logging_service.dart';

/// Step 1 of the booking flow: movie info, nearby theatres and show timings.
/// Tapping BOOK NOW after picking a show opens seat selection.
class MovieBookingScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const MovieBookingScreen({super.key, required this.movie});

  @override
  State<MovieBookingScreen> createState() => _MovieBookingScreenState();
}

class _MovieBookingScreenState extends State<MovieBookingScreen> {
  int _selectedDateIndex = 0;
  int _selectedTheatreIndex = 0;
  String _selectedShowId = '';
  String _selectedTime = '';

  // Real-time cinema data from Firebase
  List<Map<String, dynamic>> _cinemas = [];
  bool _isLoadingCinemas = true;

  // ✅ Loading optimization variables
  final Map<String, dynamic> _timingsCache = {}; // Cache show timings by key

  // Dates (dynamic - next 5 days from today)
  List<String> _dates = [];
  List<DateTime> _dateObjects = []; // Store actual DateTime objects

  @override
  void initState() {
    super.initState();
    _generateDates();
    _loadUserLocationAndCinemas();
  }

  // Generate next 5 days dynamically
  void _generateDates() {
    final now = DateTime.now();
    _dates = List.generate(5, (index) {
      final date = now.add(Duration(days: index));
      final day = date.day.toString().padLeft(2, '0');
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '$day ${months[date.month - 1]}';
    });
    _dateObjects = List.generate(5, (index) => now.add(Duration(days: index)));
  }

  // Load cinemas for this movie (no location filtering - show all theatres with shows)
  Future<void> _loadUserLocationAndCinemas() async {
    try {
      // Try to get user position, but don't block on location permission
      Position? position;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
        }
      } catch (e) {
        Log.w(
          'MovieBookingScreen',
          'Location unavailable, showing all cinemas: $e',
        );
        position = null;
      }

      if (mounted) {
        setState(() {});
      }

      // Fetch cinemas from Firebase (Theatres collection)
      // ✅ Safely convert movie ID to string
      final movieId = _safeMovieId();
      Log.i('MovieBookingScreen', 'Fetching cinemas for movie: $movieId');

      final cinemas = await CinemaService.getNearbyCinemas(
        movieId: movieId,
        userPosition: position,
      );

      Log.i('MovieBookingScreen', 'Found ${cinemas.length} cinemas');

      if (mounted) {
        setState(() {
          _cinemas = cinemas;
          _isLoadingCinemas = false;

          // Auto-select first theatre if available
          if (_cinemas.isNotEmpty) {
            _loadShowTimings(0, autoSelect: true);
          }
        });
      }
    } catch (e) {
      Log.e('MovieBookingScreen', 'Error loading cinemas: $e');
      if (mounted) {
        setState(() {
          _isLoadingCinemas = false;
        });
      }
    }
  }

  // Load show timings for a cinema
  Future<void> _loadShowTimings(
    int cinemaIndex, {
    bool autoSelect = false,
  }) async {
    final cinema = _cinemas[cinemaIndex];
    final dateObj = _dateObjects[_selectedDateIndex];
    final dateKey =
        '${dateObj.year}-${dateObj.month.toString().padLeft(2, '0')}-${dateObj.day.toString().padLeft(2, '0')}';

    // ✅ Create cache key
    final cacheKey = '${cinema['id']}_$dateKey';

    // ✅ Check if already cached
    if (_timingsCache.containsKey(cacheKey)) {
      final cachedTimings = _timingsCache[cacheKey] as List<dynamic>;
      if (mounted) {
        setState(() {
          cinema['timings'] = cachedTimings;
          if (autoSelect && cachedTimings.isNotEmpty) {
            _selectedShowId = cachedTimings[0]['id'];
            _selectedTime = cachedTimings[0]['time'];
          } else if (autoSelect) {
            _selectedShowId = '';
            _selectedTime = '';
          }
        });
      }
      return;
    }

    // Safely convert movie ID to string
    final movieId = _safeMovieId();

    try {
      final timings = await CinemaService.getShowTimings(
        theatreId: cinema['id'],
        movieId: movieId,
        date: dateKey,
      );

      // ✅ Cache the timings
      _timingsCache[cacheKey] = timings;

      if (mounted) {
        setState(() {
          cinema['timings'] = timings;
          if (autoSelect && timings.isNotEmpty) {
            _selectedShowId = timings[0]['id'];
            _selectedTime = timings[0]['time'];
          } else if (autoSelect) {
            _selectedShowId = '';
            _selectedTime = '';
          }
        });
      }
    } catch (e) {
      Log.e('MovieBookingScreen', 'Error loading show timings: $e');
      if (mounted) {}
    }
  }

  // ✅ Helper method to safely get movie ID (handles int or String in Firebase)
  String _safeMovieId() {
    final id = widget.movie['id'] ?? widget.movie['movieId'];
    if (id == null) return '';
    if (id is int) return id.toString();
    return id.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SELECT SHOW',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              physics: const BouncingScrollPhysics(),
              children: [
                // Movie info
                _buildMovieInfoHeader(),
                const SizedBox(height: 16),

                // Date Selector
                _buildDateSelector(),
                const SizedBox(height: 16),

                // Theatre list
                _buildTheatreSelector(),
              ],
            ),
          ),

          // Book Now Section
          _buildBookNowSection(),
        ],
      ),
    );
  }

  // Movie info header (poster + title + meta)
  Widget _buildMovieInfoHeader() {
    final title = widget.movie['title']?.toString() ?? 'Movie';
    final genre = widget.movie['genre']?.toString() ?? 'Drama';
    final duration = widget.movie['duration']?.toString() ?? '';
    final language = widget.movie['language']?.toString() ?? '';
    final rating = widget.movie['rating']?.toString() ?? '';
    final description = widget.movie['description']?.toString() ?? '';
    final trailerUrl = _trailerUrl();
    final poster = _posterUrl();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7D4CFF).withValues(alpha: 0.14),
            const Color(0xFFFF7A1A).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: poster != null
                    ? CachedNetworkImage(
                        imageUrl: poster,
                        width: 96,
                        height: 140,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _posterPlaceholder(),
                        errorWidget: (_, __, ___) => _posterPlaceholder(),
                      )
                    : _posterPlaceholder(),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetaChip(genre),
                        if (duration.isNotEmpty) _buildMetaChip(duration),
                        if (language.isNotEmpty) _buildMetaChip(language),
                      ],
                    ),
                    if (rating.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.black,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'RATING',
                              style: GoogleFonts.poppins(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Synopsis
          if (description.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'ABOUT THE MOVIE',
              style: GoogleFonts.orbitron(
                color: const Color(0xFFFF7A1A),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13.5,
                height: 1.55,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 18),

          // Trailer preview (16:9)
          if (trailerUrl != null)
            TrailerPlayer(url: trailerUrl)
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white24,
                        size: 34,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'NO TRAILER AVAILABLE',
                        style: GoogleFonts.orbitron(
                          color: Colors.white30,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Trailer URL from movie data
  String? _trailerUrl() {
    final t = widget.movie['trailerUrl'] ??
        widget.movie['trailer'] ??
        widget.movie['trailerLink'] ??
        widget.movie['youtubeUrl'] ??
        widget.movie['videoUrl'];
    if (t == null) return null;
    final s = t.toString().trim();
    return s.isEmpty ? null : s;
  }

  // Poster URL fallback across movie map shapes
  String? _posterUrl() {
    final posterUrl = widget.movie['posterUrl'];
    if (posterUrl != null && posterUrl.toString().isNotEmpty) {
      return posterUrl.toString();
    }
    final poster = widget.movie['poster'];
    if (poster != null && poster.toString().startsWith('http')) {
      return poster.toString();
    }
    final posterAsset = widget.movie['posterAsset'];
    if (posterAsset != null && posterAsset.toString().isNotEmpty) {
      return posterAsset.toString();
    }
    return null;
  }

  Widget _posterPlaceholder() {
    return Container(
      width: 96,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.movie_rounded,
        color: Colors.white24,
        size: 40,
      ),
    );
  }

  Widget _buildMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          bool selected = _selectedDateIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDateIndex = index;
              });
              if (_cinemas.isNotEmpty) {
                _loadShowTimings(_selectedTheatreIndex, autoSelect: true);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFF7A1A)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF7A1A).withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                _dates[index],
                style: GoogleFonts.poppins(
                  color: selected ? Colors.white : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTheatreSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT CINEMA',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 15),

        // Loading state
        if (_isLoadingCinemas)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF7A1A),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading cinemas...',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        // Empty state - No cinemas found
        else if (_cinemas.isEmpty)
          _buildEmptyState()
        // Real cinemas from Firebase
        else
          ...List.generate(_cinemas.length, (index) {
            bool selected = _selectedTheatreIndex == index;
            var cinema = _cinemas[index];
            return GestureDetector(
              onTap: () => setState(() {
                _selectedTheatreIndex = index;
                _loadShowTimings(index, autoSelect: true);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFF7A1A)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A1A).withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.theaters_rounded,
                            color: Color(0xFFFF7A1A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cinema['cinemaName'] ?? 'Cinema',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cinema['distance'] != null
                                    ? '${cinema['city']} • ${cinema['distance']} km away'
                                    : '${cinema['city']}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFFFF7A1A),
                            size: 24,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Show formats
                    Wrap(
                      spacing: 8,
                      children:
                          (cinema['formats'] as List<dynamic>? ?? ['2D'])
                              .map(
                                (format) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF7D4CFF,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF7D4CFF,
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    format.toString(),
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF7D4CFF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 12),

                    // Show timings
                    Text(
                      'SHOWTIMES',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _buildShowTimeButtons(index),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // Empty state widget
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7D4CFF).withValues(alpha: 0.05),
            const Color(0xFFFF7A1A).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Animated cinema icon
          TweenAnimationBuilder(
            duration: const Duration(seconds: 2),
            tween: Tween<double>(begin: 0.8, end: 1.0),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7D4CFF), Color(0xFFFF7A1A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7D4CFF).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.movie_filter_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'No Shows Available',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'No theatres are showing this movie right now',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadUserLocationAndCinemas,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'REFRESH',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A1A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build show time buttons for a cinema
  List<Widget> _buildShowTimeButtons(int cinemaIndex) {
    final timings = _cinemas[cinemaIndex]['timings'] as List<dynamic>? ?? [];

    if (timings.isEmpty) {
      return [
        Text(
          'No shows for this date',
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
        ),
      ];
    }

    return timings.map<Widget>((timing) {
      final time = timing['time'] ?? '';
      final isSelected = _selectedShowId == timing['id'];

      return GestureDetector(
        onTap: () => setState(() {
          _selectedTheatreIndex = cinemaIndex;
          _selectedShowId = timing['id'];
          _selectedTime = time;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF7A1A)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF7A1A) : Colors.white10,
            ),
          ),
          child: Text(
            time,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBookNowSection() {
    final selectedCinema =
        _cinemas.isNotEmpty && _selectedTheatreIndex < _cinemas.length
        ? _cinemas[_selectedTheatreIndex]['cinemaName'] ?? 'Cinema'
        : '';

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        18,
        24,
        MediaQuery.of(context).padding.bottom + 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedShowId.isNotEmpty
                        ? selectedCinema.toUpperCase()
                        : 'SELECT A SHOW',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedShowId.isNotEmpty ? _selectedTime : 'Choose a timing',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _selectedShowId.isEmpty || _cinemas.isEmpty
                    ? null
                    : () {
                        final timing = _selectedTiming();
                        if (timing == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MovieSeatSelectionScreen(
                              movie: widget.movie,
                              cinema: _cinemas[_selectedTheatreIndex],
                              showId: _selectedShowId,
                              time: _selectedTime,
                              date: _dateObjects[_selectedDateIndex],
                              seatLayout: timing['seatLayout'],
                              pricing: timing['pricing'],
                            ),
                          ),
                        );
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: _selectedShowId.isEmpty
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFFF7A1A), Color(0xFFFF512F)],
                          ),
                    color: _selectedShowId.isEmpty
                        ? Colors.grey.withValues(alpha: 0.3)
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _selectedShowId.isNotEmpty
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFFF7A1A,
                              ).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'BOOK NOW',
                      style: GoogleFonts.orbitron(
                        color: _selectedShowId.isEmpty
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Find the selected timing's seat layout + pricing
  Map<String, dynamic>? _selectedTiming() {
    final cinema = _cinemas[_selectedTheatreIndex];
    final timings = cinema['timings'] as List<dynamic>? ?? [];
    for (final t in timings) {
      if (t['id'] == _selectedShowId) {
        return Map<String, dynamic>.from(t as Map);
      }
    }
    return null;
  }
}
