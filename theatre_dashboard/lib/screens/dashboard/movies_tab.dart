import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';
import '../../widgets/common/neon_button.dart';
import '../../widgets/movie/search_movie_dialog.dart';
import '../../widgets/movie/request_movie_dialog.dart';

class MoviesTab extends StatefulWidget {
  const MoviesTab({super.key});

  @override
  State<MoviesTab> createState() => _MoviesTabState();
}

class _MoviesTabState extends State<MoviesTab> with SingleTickerProviderStateMixin {
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MOVIE MANAGEMENT', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                    'Add existing movies to create shows, or request new movies for admin approval',
                    style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'Rajdhani'),
                  ),
                ],
              ),
              Row(
                children: [
                  NeonButton(
                    text: 'ADD EXISTING',
                    icon: Icons.search,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const SearchMovieDialog(),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  NeonButton(
                    text: 'REQUEST NEW',
                    icon: Icons.add_circle_outline,
                    color: CyberpunkTheme.secondaryNeon,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const RequestMovieDialog(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: CyberpunkTheme.primaryNeon,
            labelColor: CyberpunkTheme.primaryNeon,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'MY SHOWS'),
              Tab(text: 'MY REQUESTS'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ActiveMoviesView(),
                _MovieRequestsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveMoviesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);
    return StreamBuilder<QuerySnapshot>(
      stream: theatreService.getMyMovies(),
      builder: (context, lineupSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: theatreService.getMyActiveMovies(),
          builder: (context, showsSnap) {
            if (lineupSnap.connectionState == ConnectionState.waiting ||
                showsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
            }

            final lineupDocs = lineupSnap.data?.docs ?? [];
            final showDocs = showsSnap.data?.docs ?? [];

            // Merge theatre lineup with movies that already have shows
            final movieIds = <String>{};
            final movies = <Map<String, dynamic>>[];

            for (final doc in lineupDocs) {
              final data = doc.data();
              final mId = data['movieId'];
              if (mId != null && !movieIds.contains(mId)) {
                movieIds.add(mId);
                movies.add({
                  'id': mId,
                  'title': data['movieTitle'] ?? 'Unknown',
                  'posterUrl': data['moviePosterUrl'],
                  'lineupDocId': doc.id,
                });
              }
            }

            for (final doc in showDocs) {
              final data = doc.data();
              final mId = data['movieId'];
              if (mId != null && !movieIds.contains(mId)) {
                movieIds.add(mId);
                movies.add({
                  'id': mId,
                  'title': data['movieTitle'] ?? 'Unknown',
                  'posterUrl': data['moviePosterUrl'],
                  'lineupDocId': null,
                });
              }
            }

            return Column(
              children: [
                Expanded(
                  child: movies.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.movie_outlined, size: 64, color: Colors.white24),
                              const SizedBox(height: 16),
                              const Text('No movies added yet. Tap "Add Existing" to add movies to your lineup!', style: TextStyle(color: Colors.white54)),
                              const SizedBox(height: 24),
                              NeonButton(
                                text: 'ADD EXISTING MOVIE',
                                onPressed: () => showDialog(context: context, builder: (context) => const SearchMovieDialog()),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 24,
                            mainAxisSpacing: 24,
                          ),
                          itemCount: movies.length,
                          itemBuilder: (context, index) {
                            final movie = movies[index];
                            return _buildMovieCard(context, movie);
                          },
                        ),
                ),
                const SizedBox(height: 16),
                _buildShowsHint(context),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShowsHint(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, color: CyberpunkTheme.primaryNeon),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              'Go to Shows Management screen to make shows of date and time.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _removeMovie(BuildContext context, Map<String, dynamic> movie) async {
    final docId = movie['lineupDocId'];
    if (docId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberpunkTheme.surface,
        title: const Text('Remove Movie?'),
        content: Text('Remove "${movie['title']}" from My Shows?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!context.mounted) return;
      await Provider.of<TheatreService>(context, listen: false).removeMyMovie(docId);
    }
  }

  Widget _buildMovieCard(BuildContext context, Map<String, dynamic> movie) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('movies').doc(movie['id']).get(),
      builder: (context, snapshot) {
        final movieData = snapshot.data?.data() ?? movie;

        return Container(
          decoration: BoxDecoration(
            color: CyberpunkTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    movieData['posterUrl'] != null && movieData['posterUrl'].toString().isNotEmpty
                        ? Image.network(
                            movieData['posterUrl'],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black26,
                              child: const Center(child: Icon(Icons.movie, size: 50)),
                            ),
                          )
                        : Container(
                            color: Colors.black26,
                            child: const Center(child: Icon(Icons.movie, size: 50)),
                          ),
                    if (movie['lineupDocId'] != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _removeMovie(context, movie),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movieData['title'] ?? 'Unknown Title',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _movieMeta(movieData),
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  String _movieMeta(Map<String, dynamic> movieData) {
    final lang = (movieData['language'] ?? '').toString();
    final genre = (movieData['genre'] ?? '').toString();
    return [if (lang.isNotEmpty) lang, if (genre.isNotEmpty) genre].join(' • ');
  }
}

class _MovieRequestsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);
    return StreamBuilder<QuerySnapshot>(
      stream: theatreService.getMyMovieRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(child: Text('No movie requests submitted.', style: TextStyle(color: Colors.white54)));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index].data();
            final id = requests[index].id;
            return _buildRequestTile(context, id, request);
          },
        );
      },
    );
  }

  Widget _buildRequestTile(BuildContext context, String id, Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    final Color statusColor = status == 'approved' 
        ? Colors.greenAccent 
        : status == 'rejected' 
            ? Colors.redAccent 
            : Colors.amberAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberpunkTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              request['posterUrl'] ?? '',
              width: 60,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60, height: 90, color: Colors.white10, child: const Icon(Icons.movie)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request['title'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${request['language']} • ${request['genre']}', style: const TextStyle(color: Colors.white54)),
                if (request['adminRemarks'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Admin: ${request['adminRemarks']}', style: TextStyle(color: statusColor.withValues(alpha: 0.8), fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          if (status == 'pending')
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => Provider.of<TheatreService>(context, listen: false).deleteMovie(id),
            ),
        ],
      ),
    );
  }
}
