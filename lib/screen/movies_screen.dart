import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen>
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
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          '🎬 Movies',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF4D4F),
          labelColor: const Color(0xFFFF4D4F),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Now Showing'),
            Tab(text: 'Coming Soon'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMoviesList('now_showing'),
          _buildMoviesList('coming_soon'),
        ],
      ),
    );
  }

  Widget _buildMoviesList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('movies')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D4F)));
        }

        final movies = snapshot.data?.docs ?? [];

        if (movies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.movie_outlined, color: Colors.grey[700], size: 64),
                const SizedBox(height: 16),
                Text(
                  status == 'now_showing'
                      ? 'No movies showing now'
                      : 'No upcoming movies',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final data = movies[index].data() as Map<String, dynamic>;
            final movieId = movies[index].id;
            return _buildMovieCard(data, movieId, status);
          },
        );
      },
    );
  }

  Widget _buildMovieCard(
      Map<String, dynamic> data, String movieId, String status) {
    return GestureDetector(
      onTap: status == 'now_showing'
          ? () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(
            movieId: movieId,
            movieData: data,
          ),
        ),
      )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            // Poster
            ClipRRect(
              borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(16)),
              child: data['posterUrl'] != null && data['posterUrl'].isNotEmpty
                  ? Image.network(
                data['posterUrl'],
                width: 100,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPosterPlaceholder(),
              )
                  : _buildPosterPlaceholder(),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['genre'] ?? '',
                      style: const TextStyle(
                          color: Color(0xFFFF4D4F), fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Colors.grey, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${data['duration'] ?? ''} min',
                          style:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${data['rating'] ?? ''}',
                          style:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['language'] ?? '',
                      style:
                      const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    if (status == 'now_showing')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Book Tickets',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Coming Soon',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
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

  Widget _buildPosterPlaceholder() {
    return Container(
      width: 100,
      height: 140,
      color: const Color(0xFF2A2A2A),
      child: const Icon(Icons.movie, color: Colors.grey, size: 40),
    );
  }
}

// ══════════════════════════════════════
// MOVIE DETAIL SCREEN
// ══════════════════════════════════════
class MovieDetailScreen extends StatelessWidget {
  final String movieId;
  final Map<String, dynamic> movieData;

  const MovieDetailScreen({
    super.key,
    required this.movieId,
    required this.movieData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: CustomScrollView(
        slivers: [
          // App Bar with poster
          SliverAppBar(
            expandedHeight: 250,
            backgroundColor: const Color(0xFF0D0D0D),
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: movieData['posterUrl'] != null
                  ? Image.network(
                movieData['posterUrl'],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: const Icon(Icons.movie,
                      color: Colors.grey, size: 80),
                ),
              )
                  : Container(
                color: const Color(0xFF1A1A1A),
                child:
                const Icon(Icons.movie, color: Colors.grey, size: 80),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Genre
                  Text(
                    movieData['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _infoChip(movieData['genre'] ?? ''),
                      const SizedBox(width: 8),
                      _infoChip('${movieData['duration'] ?? ''} min'),
                      const SizedBox(width: 8),
                      _infoChip(movieData['language'] ?? ''),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${movieData['rating'] ?? 'N/A'} / 10',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (movieData['description'] != null) ...[
                    const Text(
                      'About',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movieData['description'],
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Select Theatre
                  const Text(
                    'Select Theatre & Show',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Theatres list
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('movies')
                        .doc(movieId)
                        .collection('theatres')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final theatres = snapshot.data?.docs ?? [];

                      if (theatres.isEmpty) {
                        return const Center(
                          child: Text('No theatres available',
                              style: TextStyle(color: Colors.grey)),
                        );
                      }

                      return Column(
                        children: theatres.map((theatre) {
                          final tData =
                          theatre.data() as Map<String, dynamic>;
                          return _buildTheatreCard(
                              context, tData, theatre.id, movieId);
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }

  Widget _buildTheatreCard(BuildContext context, Map<String, dynamic> tData,
      String theatreId, String movieId) {
    final shows = List<String>.from(tData['showTimes'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tData['name'] ?? '',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            tData['address'] ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // Show times
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shows.map((time) {
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeatSelectionScreen(
                      movieId: movieId,
                      theatreId: theatreId,
                      showTime: time,
                      movieTitle: tData['name'] ?? '',
                      theatreName: tData['name'] ?? '',
                      ticketPrice: (tData['ticketPrice'] ?? 150).toDouble(),
                      totalSeats: tData['totalSeats'] ?? 50,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFF4D4F)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    time,
                    style: const TextStyle(
                        color: Color(0xFFFF4D4F),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
// SEAT SELECTION SCREEN
// ══════════════════════════════════════
class SeatSelectionScreen extends StatefulWidget {
  final String movieId;
  final String theatreId;
  final String showTime;
  final String movieTitle;
  final String theatreName;
  final double ticketPrice;
  final int totalSeats;

  const SeatSelectionScreen({
    super.key,
    required this.movieId,
    required this.theatreId,
    required this.showTime,
    required this.movieTitle,
    required this.theatreName,
    required this.ticketPrice,
    required this.totalSeats,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  List<int> _selectedSeats = [];
  List<int> _bookedSeats = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBookedSeats();
  }

  Future<void> _loadBookedSeats() async {
    final doc = await FirebaseFirestore.instance
        .collection('movies')
        .doc(widget.movieId)
        .collection('theatres')
        .doc(widget.theatreId)
        .collection('bookings')
        .doc(widget.showTime.replaceAll(':', '_'))
        .get();

    if (doc.exists) {
      setState(() {
        _bookedSeats = List<int>.from(doc.data()?['bookedSeats'] ?? []);
      });
    }
  }

  void _toggleSeat(int seatNumber) {
    if (_bookedSeats.contains(seatNumber)) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedSeats.contains(seatNumber)) {
        _selectedSeats.remove(seatNumber);
      } else {
        _selectedSeats.add(seatNumber);
      }
    });
  }

  Future<void> _confirmBooking() async {
    if (_selectedSeats.isEmpty) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('movies')
          .doc(widget.movieId)
          .collection('theatres')
          .doc(widget.theatreId)
          .collection('bookings')
          .doc(widget.showTime.replaceAll(':', '_'));

      // Update booked seats
      final updatedBooked = [..._bookedSeats, ..._selectedSeats];
      await bookingRef.set(
        {'bookedSeats': updatedBooked},
        SetOptions(merge: true),
      );

      // Save user booking
      await FirebaseFirestore.instance.collection('movie_bookings').add({
        'userId': user?.uid,
        'movieId': widget.movieId,
        'movieTitle': widget.movieTitle,
        'theatreId': widget.theatreId,
        'theatreName': widget.theatreName,
        'showTime': widget.showTime,
        'seats': _selectedSeats,
        'totalAmount': _selectedSeats.length * widget.ticketPrice,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        _showBookingSuccess();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showBookingSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Booking Confirmed!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.movieTitle}\n${widget.theatreName}\n${widget.showTime}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Seats: ${_selectedSeats.join(', ')}',
              style: const TextStyle(
                  color: Color(0xFFFF4D4F), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ₹${(_selectedSeats.length * widget.ticketPrice).toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D4F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seatsPerRow = 8;
    final rows = (widget.totalSeats / seatsPerRow).ceil();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.movieTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text('${widget.theatreName} • ${widget.showTime}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Screen indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  width: 200,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('SCREEN',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Colors.grey[800]!, 'Available'),
                const SizedBox(width: 20),
                _legendItem(const Color(0xFFFF4D4F), 'Selected'),
                const SizedBox(width: 20),
                _legendItem(Colors.grey[600]!, 'Booked'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Seats Grid
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: seatsPerRow,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: widget.totalSeats,
                itemBuilder: (context, index) {
                  final seatNumber = index + 1;
                  final isBooked = _bookedSeats.contains(seatNumber);
                  final isSelected = _selectedSeats.contains(seatNumber);

                  return GestureDetector(
                    onTap: () => _toggleSeat(seatNumber),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isBooked
                            ? Colors.grey[700]
                            : isSelected
                            ? const Color(0xFFFF4D4F)
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF4D4F)
                              : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$seatNumber',
                          style: TextStyle(
                            color: isBooked ? Colors.grey[500] : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom - Price & Book
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedSeats.length} seat${_selectedSeats.length != 1 ? 's' : ''} selected',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Text(
                        '₹${(_selectedSeats.length * widget.ticketPrice).toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _selectedSeats.isEmpty || _isLoading
                      ? null
                      : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    disabledBackgroundColor: const Color(0xFF333333),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Text(
                    'Confirm',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
