import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';
import 'request_movie_dialog.dart';

class SearchMovieDialog extends StatefulWidget {
  const SearchMovieDialog({super.key});

  @override
  State<SearchMovieDialog> createState() => _SearchMovieDialogState();
}

class _SearchMovieDialogState extends State<SearchMovieDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);

    return Dialog(
      backgroundColor: CyberpunkTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CyberpunkTheme.primaryNeon, width: 1),
      ),
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SELECT MOVIE', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search movies in global database...',
                prefixIcon: const Icon(Icons.search, color: CyberpunkTheme.primaryNeon),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear), 
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      }
                    ) 
                  : null,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: theatreService.getGlobalMovies(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading movies: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
                  }

                  final movies = snapshot.data?.docs.where((doc) {
                    final data = doc.data();
                    final title = (data['title'] ?? '').toString().toLowerCase();
                    return title.contains(_searchQuery);
                  }).toList() ?? [];

                  // Sort client-side since we removed server-side orderBy to avoid index issues
                  movies.sort((a, b) {
                    final aTitle = ((a.data())['title'] ?? '').toString();
                    final bTitle = ((b.data())['title'] ?? '').toString();
                    return aTitle.compareTo(bTitle);
                  });

                  if (movies.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.movie_filter, size: 64, color: Colors.white24),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? 'No approved movies found.' : 'Movie not found in global database.',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) => RequestMovieDialog(initialTitle: _searchController.text),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('REQUEST NEW MOVIE'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CyberpunkTheme.primaryNeon,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movieDoc = movies[index];
                      final movie = movieDoc.data();
                      return _buildGlobalMovieCard(movieDoc.id, movie);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Can't find your movie?", style: TextStyle(color: Colors.white54)),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => const RequestMovieDialog(),
                    );
                  },
                  child: const Text('REQUEST ADDITION', style: TextStyle(color: CyberpunkTheme.primaryNeon)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalMovieCard(String movieId, Map<String, dynamic> movie) {
    return InkWell(
      onTap: () async {
        final theatreService = Provider.of<TheatreService>(context, listen: false);
        final messenger = ScaffoldMessenger.of(context);
        final title = (movie['title'] ?? 'Movie').toString();
        try {
          await theatreService.addMyMovie({
            'movieId': movieId,
            'movieTitle': title,
            'moviePosterUrl': movie['posterUrl']?.toString(),
          });
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Failed to add "$title": $e'), backgroundColor: Colors.red),
            );
          }
          return;
        }
        if (!mounted) return;
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('"$title" added to My Shows. Go to Shows Management to schedule date & time.'),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: movie['posterUrl'] != null && movie['posterUrl'].toString().isNotEmpty
                  ? Image.network(
                      movie['posterUrl'],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.movie, size: 40)),
                    )
                  : Container(
                      color: Colors.black26,
                      child: const Center(child: Icon(Icons.movie, size: 40)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie['title'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${movie['language']} • ${movie['genre']}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
