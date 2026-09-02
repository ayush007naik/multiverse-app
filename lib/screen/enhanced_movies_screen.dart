import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/premium_ui_widgets.dart';
import 'movie_booking_screen.dart';

// Enhanced Movies Screen with futuristic MULTIVERSE UI
// Features: Premium neon black UI, orange + purple glowing gradients,
// cyberpunk/futuristic aesthetics, glassmorphism cards, smooth animations

class EnhancedMoviesScreen extends StatefulWidget {
  const EnhancedMoviesScreen({super.key});

  @override
  State<EnhancedMoviesScreen> createState() => _EnhancedMoviesScreenState();
}

class _EnhancedMoviesScreenState extends State<EnhancedMoviesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep space black
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0A0A),
                  Color(0xFF121212),
                  Color(0xFF1A0B2E), // Purple cosmic
                  Color(0xFF0D0D0D),
                ],
                stops: [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMoviesList('approved'),
                      _buildMoviesList('upcoming'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Text(
            'MOVIES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              shadows: [
                Shadow(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.8),
                  blurRadius: 15,
                  offset: const Offset(0, 0),
                ),
                Shadow(
                  color: const Color(0xFF6A26E3).withValues(alpha: 0.8),
                  blurRadius: 15,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF5722).withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Color(0xFFFF5722),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF5722).withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5722).withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFFF5722),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 1.0,
        ),
        tabs: const [
          Tab(text: 'NOW SHOWING'),
          Tab(text: 'COMING SOON'),
        ],
      ),
    );
  }

  Widget _buildMoviesList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('movies')
          .where('status', isEqualTo: status)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5722)),
          );
        }
        final movies = snapshot.data?.docs ?? [];
        if (movies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.movie_outlined,
                  color: Colors.white.withValues(alpha: 0.1),
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  status == 'approved'
                      ? 'No movies showing now'
                      : 'No upcoming movies',
                  style: const TextStyle(color: Colors.white38, fontSize: 18),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          physics: const BouncingScrollPhysics(),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final data = movies[index].data();
            final movieId = movies[index].id;
            return FadeSlideAnimation(
              delay: Duration(milliseconds: 100 * index),
              child: _buildMovieCard(data, movieId, status),
            );
          },
        );
      },
    );
  }

  Widget _buildMovieCard(
    Map<String, dynamic> data,
    String movieId,
    String status,
  ) {
    return GestureDetector(
      onTap: status == 'approved'
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MovieBookingScreen(
                  movie: Map<String, dynamic>.from(data)..['id'] = movieId,
                ),
              ),
            )
          : null,
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 24),
        padding: EdgeInsets.zero,
        borderRadius: 28,
        borderColor: Colors.white.withValues(alpha: 0.1),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(28),
              ),
              child: Stack(
                children: [
                  data['posterUrl'] != null && data['posterUrl'].isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: data['posterUrl'],
                          width: 140,
                          height: 210,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox.shrink(),
                          errorWidget: (_, __, ___) => _posterPlaceholder(),
                        )
                      : _posterPlaceholder(),
                  if (data['rating'] != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF5722,
                              ).withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${data['rating']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          data['genre'] ?? '',
                          style: const TextStyle(
                            color: Color(0xFFFF5722),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A26E3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            data['language']?.toString().split(',').first ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: Colors.white38,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${data['duration'] ?? ''}m',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Icon(
                          Icons.language_rounded,
                          color: Colors.white38,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          data['language']?.toString().split(',').first ?? '',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    status == 'approved'
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5722),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF5722,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'BOOK NOW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'COMING SOON',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      width: 140,
      height: 210,
      color: Colors.white.withValues(alpha: 0.05),
      child: const Icon(Icons.movie_rounded, color: Colors.white10, size: 48),
    );
  }
}
