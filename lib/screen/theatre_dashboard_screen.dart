import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/logging_service.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/logout_service.dart';
import 'login_screen.dart';

class TheatreDashboardScreen extends StatefulWidget {
  const TheatreDashboardScreen({super.key});

  @override
  State<TheatreDashboardScreen> createState() => _TheatreDashboardScreenState();
}

class _TheatreDashboardScreenState extends State<TheatreDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;
  Map<String, dynamic>? _theatreData;

  // ── Movie search state (simple & clean) ──
  bool _showSearchPanel = false;
  String _searchQuery = '';
  final _movieSearchController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _moviesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTheatreData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _movieSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadTheatreData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('theatres').doc(uid).get();
    if (mounted) setState(() => _theatreData = doc.data());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _theatreData?['name'] ?? 'Theatre',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              _theatreData?['city'] ?? '',
              style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 13),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF4D4F),
          labelColor: const Color(0xFFFF4D4F),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'My Shows'),
            Tab(text: 'My Requests'),
            Tab(text: 'Bookings'),
            Tab(text: 'Profile'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShowsTab(),
          _buildRequestsTab(),
          _buildBookingsTab(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  // ── SHOWS TAB ── (Active shows from shows collection with ADD EXISTING / REQUEST NEW)
  Widget _buildShowsTab() {
    final uid = _auth.currentUser?.uid;
    return Column(
      children: [
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: _showSearchPanel ? 'MY SHOWS' : 'ADD EXISTING',
                  icon: _showSearchPanel ? Icons.arrow_back : Icons.search,
                  color: _showSearchPanel
                      ? Colors.green
                      : const Color(0xFFFF4D4F),
                  onTap: () {
                    setState(() {
                      _showSearchPanel = !_showSearchPanel;
                      if (_showSearchPanel) {
                        _searchQuery = '';
                        _movieSearchController.clear();
                        _moviesFuture = _fetchMovies();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'REQUEST NEW',
                  icon: Icons.add_circle_outline,
                  color: const Color(0xFF7D4CFF),
                  onTap: () => _showRequestMovieDialog(),
                ),
              ),
            ],
          ),
        ),
        // Search panel OR Active shows
        Expanded(
          child: _showSearchPanel
              ? _buildInlineSearchPanel()
              : _buildShowsGrid(uid),
        ),
      ],
    );
  }

  // ── Fetch movies (called once when panel opens) ──
  Future<List<Map<String, dynamic>>> _fetchMovies() async {
    Log.i('TheatreDashboardScreen', 'Fetching all movies from Firestore...');
    final snapshot = await _firestore.collection('movies').get();
    Log.i('TheatreDashboardScreen', 'Got ${snapshot.docs.length} documents');
    final movies = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      data['_docId'] = doc.id;
      movies.add(data);
      Log.i('TheatreDashboardScreen', '  -> "${data['title'] ?? data['movieName']}" status=${data['status']} isActive=${data['isActive']}');
    }
    return movies;
  }

  // ── Search panel UI ──
  Widget _buildInlineSearchPanel() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _movieSearchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search movies...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFFF4D4F)),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Movie results via FutureBuilder
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _moviesFuture,
            builder: (context, snapshot) {
              // Loading
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFFF4D4F)),
                      SizedBox(height: 12),
                      Text(
                        'Loading movies...',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              // Error
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            setState(() => _moviesFuture = _fetchMovies()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D4F),
                        ),
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                );
              }
              // Data
              final allMovies = snapshot.data ?? [];
              Log.i('TheatreDashboardScreen', 'FutureBuilder: ${allMovies.length} total movies');

              // Filter
              var movies = allMovies;
              if (_searchQuery.isNotEmpty) {
                movies = movies.where((m) {
                  final title = (m['title'] ?? m['movieName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return title.contains(_searchQuery.toLowerCase());
                }).toList();
              }

              // Empty
              if (movies.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.movie_filter,
                        size: 48,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No movies match "$_searchQuery"'
                            : 'No movies found (${allMovies.length} in database)',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _showSearchPanel = false);
                          _showRequestMovieDialog(
                            initialTitle: _movieSearchController.text,
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('REQUEST NEW MOVIE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D4F),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Movie grid
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.6,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: movies.length,
                itemBuilder: (context, index) {
                  final movie = movies[index];
                  final movieId = movie['_docId'] ?? '';
                  return GestureDetector(
                    onTap: () {
                      setState(() => _showSearchPanel = false);
                      _showCreateShowDialog(movieId, movie);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFF4D4F).withValues(alpha: 0.3),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: movie['posterUrl'] ?? movie['poster'] ?? '',
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Center(
                                    child: Icon(
                                      Icons.movie,
                                      size: 30,
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    color: Colors.green.withValues(alpha: 0.8),
                                    child: const Center(
                                      child: Text(
                                        'TAP TO ADD',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  movie['title'] ?? movie['movieName'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${movie['language'] ?? ''} \u2022 ${movie['genre'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── SHOWS GRID (original shows list) ──
  Widget _buildShowsGrid(String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('shows')
          .where('theatreId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
          );
        }

        final shows = snapshot.data?.docs ?? [];
        final movieIds = <String>{};
        final movies = <Map<String, dynamic>>[];
        for (var doc in shows) {
          final data = doc.data();
          final mId = data['movieId'];
          if (mId != null && !movieIds.contains(mId)) {
            movieIds.add(mId);
            movies.add({
              'id': mId,
              'title': data['movieTitle'] ?? 'Unknown',
              'posterUrl': data['moviePosterUrl'] ?? '',
            });
          }
        }

        if (movies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.movie_outlined, color: Colors.grey[700], size: 64),
                const SizedBox(height: 16),
                const Text(
                  'No active shows',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap "ADD EXISTING" to search global movies',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            return _buildShowMovieCard(movies[index]);
          },
        );
      },
    );
  }

  Widget _buildShowMovieCard(Map<String, dynamic> data) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('movies').doc(data['id']).get(),
      builder: (context, snapshot) {
        final movieData =
            snapshot.data?.data() ?? data;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: (movieData['posterUrl'] ?? '').toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: movieData['posterUrl'],
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.movie, color: Colors.grey, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movieData['title'] ?? data['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${movieData['language'] ?? ''} \u2022 ${movieData['genre'] ?? ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── REQUESTS TAB ── (Movie requests submitted by this theatre)
  Widget _buildRequestsTab() {
    final uid = _auth.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('movie_requests')
          .where('requestedByTheatreId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
          );
        }
        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  color: Colors.grey[700],
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No movie requests',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap "REQUEST NEW" to submit a movie for admin approval',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index].data();
            final id = requests[index].id;
            return _buildRequestTile(id, request);
          },
        );
      },
    );
  }

  Widget _buildRequestTile(String id, Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    final Color statusColor = status == 'approved'
        ? Colors.greenAccent
        : status == 'rejected'
        ? Colors.redAccent
        : Colors.amberAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: request['posterUrl'] ?? '',
              width: 50,
              height: 75,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 50,
                height: 75,
                color: const Color(0xFF2A2A2A),
                child: const Icon(Icons.movie, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request['title'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${request['language'] ?? ''} \u2022 ${request['genre'] ?? ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                if (request['adminRemarks'] != null &&
                    request['adminRemarks'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Admin: ${request['adminRemarks']}',
                      style: TextStyle(
                        color: statusColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (status == 'pending')
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: () => _deleteRequest(id),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteRequest(String id) async {
    await _firestore.collection('movie_requests').doc(id).delete();
  }

  // ── BOOKINGS TAB ──
  Widget _buildBookingsTab() {
    final uid = _auth.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('movie_bookings')
          .where('theatreId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final bookings = snapshot.data?.docs ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  color: Colors.grey[700],
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No bookings yet',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final data = bookings[index].data();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      color: Color(0xFFFF4D4F),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['movieTitle'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${data['showTime']} • Seats: ${(data['seats'] as List?)?.join(', ') ?? ''}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${data['totalAmount'] ?? 0}',
                    style: const TextStyle(
                      color: Color(0xFFFF4D4F),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── PROFILE TAB ──
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
            child: const Icon(Icons.movie, color: Color(0xFFFF4D4F), size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            _theatreData?['name'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _theatreData?['city'] ?? '',
            style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 15),
          ),
          const SizedBox(height: 24),
          _profileTile(
            Icons.location_on_outlined,
            'Address',
            _theatreData?['address'] ?? '',
          ),
          _profileTile(
            Icons.phone_outlined,
            'Phone',
            _theatreData?['phone'] ?? '',
          ),
          _profileTile(
            Icons.event_seat_outlined,
            'Total Seats',
            '${_theatreData?['totalSeats'] ?? 0}',
          ),
          _profileTile(
            Icons.currency_rupee,
            'Ticket Price',
            '₹${_theatreData?['ticketPrice'] ?? 0}',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await LogoutService.signOutOnly();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF4D4F)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout, color: Color(0xFFFF4D4F)),
              label: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CREATE SHOW DIALOG ── (After selecting a global movie)
  Future<void> _showCreateShowDialog(
    String movieId,
    Map<String, dynamic> movie,
  ) async {
    String? selectedScreen;
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    final priceController = TextEditingController(text: '250');
    final uid = _auth.currentUser?.uid;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.green),
          ),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CREATE SHOW: ${movie['title'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: selectedScreen,
                  decoration: const InputDecoration(
                    labelText: 'Screen',
                    prefixIcon: Icon(Icons.screenshot_monitor),
                  ),
                  dropdownColor: const Color(0xFF2A2A2A),
                  items:
                      ['Screen 1', 'Screen 2', 'Screen 3', 'IMAX', 'Gold Class']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedScreen = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                          );
                          if (d != null) setDialogState(() => selectedDate = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(selectedDate),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (t != null) setDialogState(() => startTime = t);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(
                            startTime.format(context),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ticket Price (\u20B9)',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (selectedScreen == null) return;
                      final startDT = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        startTime.hour,
                        startTime.minute,
                      );
                      await _firestore.collection('shows').add({
                        'movieId': movieId,
                        'movieTitle': movie['title'] ?? '',
                        'moviePosterUrl': movie['posterUrl'] ?? '',
                        'theatreId': uid,
                        'screen': selectedScreen,
                        'startTime': Timestamp.fromDate(startDT),
                        'endTime': Timestamp.fromDate(
                          startDT.add(const Duration(hours: 3)),
                        ),
                        'pricing': {
                          'Standard':
                              double.tryParse(priceController.text) ?? 250.0,
                        },
                        'totalSeats': 80,
                        'availableSeats': 80,
                        'isActive': true,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Show created!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('CREATE SHOW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── REQUEST MOVIE DIALOG ── (Request new movie for admin approval with duplicate check)
  Future<void> _showRequestMovieDialog({String initialTitle = ''}) async {
    final titleController = TextEditingController(text: initialTitle);
    final langController = TextEditingController();
    final genreController = TextEditingController();
    final durationController = TextEditingController();
    final certController = TextEditingController();
    final descController = TextEditingController();
    final trailerController = TextEditingController();
    DateTime releaseDate = DateTime.now();
    Uint8List? posterBytes;
    final picker = ImagePicker();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF7D4CFF)),
          ),
          child: Container(
            width: 550,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.add_to_queue,
                        color: Color(0xFF7D4CFF),
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'REQUEST NEW MOVIE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Submit for admin approval',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _dialogField2(titleController, 'Movie Title', Icons.movie),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField2(
                          langController,
                          'Language',
                          Icons.language,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogField2(
                          genreController,
                          'Genre',
                          Icons.category,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField2(
                          durationController,
                          'Duration (mins)',
                          Icons.timer,
                          isNumber: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogField2(
                          certController,
                          'Certificate (U/A)',
                          Icons.verified_user,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _dialogField2(
                    descController,
                    'Description',
                    Icons.description,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  _dialogField2(
                    trailerController,
                    'Trailer URL',
                    Icons.play_circle_fill,
                  ),
                  const SizedBox(height: 12),
                  // Date picker
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: releaseDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setDialogState(() => releaseDate = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Release Date',
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: Color(0xFF7D4CFF),
                        ),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(releaseDate),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Poster picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 600,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setDialogState(() {
                          posterBytes = bytes;
                        });
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: posterBytes != null
                              ? const Color(0xFF7D4CFF)
                              : const Color(0xFF333333),
                        ),
                      ),
                      child: posterBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.memory(
                                posterBytes!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, color: Colors.grey, size: 36),
                                Text(
                                  'Tap to select poster',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: submitting
                          ? null
                          : () async {
                              if (titleController.text.isEmpty) return;
                              if (posterBytes == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Poster required'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              setDialogState(() => submitting = true);

                              // Duplicate check
                              final allMovies = await _firestore
                                  .collection('movies')
                                  .get();
                              final lowerName = titleController.text
                                  .toLowerCase()
                                  .trim();
                              final similar = allMovies.docs.where((doc) {
                                final t =
                                    ((doc.data()['title'] ?? '') as String)
                                        .toLowerCase()
                                        .trim();
                                return t == lowerName ||
                                    t.contains(lowerName) ||
                                    lowerName.contains(t);
                              }).toList();

                              if (similar.isNotEmpty && context.mounted) {
                                final proceed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1A1A1A),
                                    title: const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.amber,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Similar Movie Found',
                                          style: TextStyle(color: Colors.amber),
                                        ),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: similar
                                          .take(3)
                                          .map(
                                            (d) => Text(
                                              '\u2022 ${d.data()['title']}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('CANCEL'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(ctx, false);
                                          Navigator.pop(context);
                                          setState(() {
                                            _showSearchPanel = true;
                                            _searchQuery = '';
                                            _movieSearchController.clear();
                                            _moviesFuture = _fetchMovies();
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        child: const Text('USE EXISTING'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber,
                                        ),
                                        child: const Text(
                                          'CONTINUE',
                                          style: TextStyle(color: Colors.black),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (proceed != true) {
                                  setDialogState(() => submitting = false);
                                  return;
                                }
                              }

                              // Upload poster
                              try {
                                final uid = _auth.currentUser?.uid ?? 'unknown';
                                final ref = FirebaseStorage.instance.ref().child(
                                  'movie-requests/posters/${uid}_${DateTime.now().millisecondsSinceEpoch}.png',
                                );
                                await ref.putData(
                                  posterBytes!,
                                  const SettableMetadata(contentType: 'image/png'),
                                );
                                final posterUrl = await ref.getDownloadURL();

                                // Get theatre name
                                final theatreDoc = await _firestore
                                    .collection('theatres')
                                    .doc(uid)
                                    .get();
                                final theatreName =
                                    theatreDoc.data()?['name'] ??
                                    theatreDoc.data()?['cinemaName'] ??
                                    'Unknown';

                                // Create request
                                await _firestore
                                    .collection('movie_requests')
                                    .add({
                                      'title': titleController.text.trim(),
                                      'language': langController.text.trim(),
                                      'genre': genreController.text.trim(),
                                      'duration':
                                          int.tryParse(
                                            durationController.text.trim(),
                                          ) ??
                                          0,
                                      'certificate': certController.text.trim(),
                                      'description': descController.text.trim(),
                                      'posterUrl': posterUrl,
                                      'bannerUrl': '',
                                      'trailerUrl': trailerController.text
                                          .trim(),
                                      'releaseDate': Timestamp.fromDate(
                                        releaseDate,
                                      ),
                                      'requestedByTheatreId': uid,
                                      'requestedByTheatreName': theatreName,
                                      'status': 'pending',
                                      'adminRemarks': '',
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                // Notify admin
                                await _firestore
                                    .collection('admin_notifications')
                                    .add({
                                      'type': 'new_movie_request',
                                      'title': 'New Movie Request',
                                      'body':
                                          '$theatreName requested "${titleController.text.trim()}"',
                                      'requestedByTheatreId': uid,
                                      'requestedByTheatreName': theatreName,
                                      'read': false,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Request submitted!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                              setDialogState(() => submitting = false);
                            },
                      icon: submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, size: 18),
                      label: Text(
                        submitting ? 'Submitting...' : 'SUBMIT REQUEST',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7D4CFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField2(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFF7D4CFF), size: 20),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _profileTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF4D4F), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
