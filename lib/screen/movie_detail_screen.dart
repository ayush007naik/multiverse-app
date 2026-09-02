import 'dart:async';
import 'package:db_compat/db_compat.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/video_urls.dart';
import '../widgets/premium_ui_widgets.dart';
import 'movie_booking_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Map<String, dynamic>? _liveMovie;
  StreamSubscription? _movieSub;

  @override
  void initState() {
    super.initState();
    _liveMovie = widget.movie;
    _listenToMovieUpdates();
  }

  void _listenToMovieUpdates() {
    final movieId = widget.movie['id']?.toString();
    if (movieId == null) return;

    _movieSub = FirebaseFirestore.instance
        .collection('movies')
        .doc(movieId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final data = snapshot.data()!;
            data['id'] = snapshot.id;
            setState(() {
              _liveMovie = data;
            });
          }
        });
  }

  @override
  void dispose() {
    _movieSub?.cancel();
    super.dispose();
  }

  Future<void> _openTrailer() async {
    final trailer =
        movie['trailerUrl'] ??
        movie['trailer'] ??
        movie['trailerLink'] ??
        movie['youtubeUrl'] ??
        movie['videoUrl'];
    final url = trailer?.toString().trim() ?? '';
    if (url.isEmpty) return;
    final ytId = youtubeVideoId(url);
    final target = ytId != null ? 'https://www.youtube.com/watch?v=$ytId' : url;
    final uri = Uri.tryParse(target);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Map<String, dynamic> get movie => _liveMovie ?? widget.movie;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Hero Image / Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                movie['poster'] != null &&
                        movie['poster'].toString().startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: movie['poster'],
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.grey[900]),
                      )
                    : Image.asset(
                        movie['poster'] ?? 'assets/banners/banner4.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey[900]),
                      ),
                // Premium Cinematic Gradient
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black54,
                        Colors.black,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                expandedHeight: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.35,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Movie Title & Rating
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              movie['title']?.toUpperCase() ?? 'PUSHPA 2',
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
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
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.black,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  movie['rating']?.toString() ?? '8.9',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Meta Info (Genre, Duration, Language) - Responsive Wrap
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildMetaChip(movie['genre'] ?? 'Action • Thriller'),
                          _buildDot(),
                          _buildMetaChip(movie['duration'] ?? '3h 10m'),
                          _buildDot(),
                          _buildMetaChip(movie['language'] ?? 'Hindi'),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // Trailer Button
                      NeonButton(
                        text: 'WATCH TRAILER',
                        onPressed: _openTrailer,
                        isSecondary: true,
                        glowColor: const Color(0xFF7D4CFF),
                        height: 50,
                      ),
                      const SizedBox(height: 30),

                      // Description
                      Text(
                        'SYNOPSIS',
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFFFF7A1A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        movie['description'] ??
                            'Pushpa Raj is back! The rule begins as the clash between Pushpa and Bhanwar Singh Shekhawat continues in this epic conclusion to the saga. Expect high-octane action, mind-bending twists, and the rise of a legend.',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Cast
                      Text(
                        'TOP CAST',
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 5,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Column(
                                children: [
                                  const CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.white10,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white30,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Actor ${index + 1}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white60,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 120), // Bottom spacing for button
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Booking CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black,
                  ],
                ),
              ),
              child: NeonButton(
                text: 'BOOK TICKETS NOW',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MovieBookingScreen(movie: movie),
                    ),
                  );
                },
                glowColor: const Color(0xFFFF7A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: Colors.white54,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Colors.white24,
        shape: BoxShape.circle,
      ),
    );
  }
}
