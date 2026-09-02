import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:db_compat/db_compat.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';
import 'search_movie_dialog.dart';

class RequestMovieDialog extends StatefulWidget {
  final String? initialTitle;
  const RequestMovieDialog({super.key, this.initialTitle});

  @override
  State<RequestMovieDialog> createState() => _RequestMovieDialogState();
}

class _RequestMovieDialogState extends State<RequestMovieDialog> {
  static const _orange = Color(0xFFFF5722);
  static const _darkSurface = Color(0xFF1E1E1E);
  static const _hintGrey = Color(0xFFAAAAAA);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final _langController = TextEditingController();
  final _genreController = TextEditingController();
  final _durationController = TextEditingController();
  final _certController = TextEditingController();
  final _descController = TextEditingController();
  final _trailerController = TextEditingController();

  DateTime _releaseDate = DateTime.now();
  final _picker = ImagePicker();

  Uint8List? _posterBytes;
  
  bool _saving = false;
  bool _checkingDuplicates = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  Future<void> _pickPoster() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _posterBytes = bytes);
    }
  }

  Future<String> _uploadImage(Uint8List bytes, String folder) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance.ref().child('movie-requests/$folder/${uid}_$ts.png');
    await ref.putData(bytes, const SettableMetadata(contentType: 'image/png'));
    return await ref.getDownloadURL();
  }

  Future<void> _checkDuplicatesAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_posterBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poster image is required')));
      return;
    }

    // Check for similar movies in global database
    setState(() => _checkingDuplicates = true);
    final movieName = _titleController.text.trim();

    try {
      final theatreService = Provider.of<TheatreService>(context, listen: false);
      final similarMovies = await theatreService.findSimilarMovies(movieName);

      if (mounted) setState(() => _checkingDuplicates = false);

      if (similarMovies.isNotEmpty && mounted) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: CyberpunkTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.amberAccent),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 28),
                SizedBox(width: 12),
                Expanded(child: Text('Possible Existing Movie Found', style: TextStyle(color: Colors.amberAccent, fontSize: 16))),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Similar movies already exist in the global database:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ...similarMovies.take(5).map((doc) {
                    final data = doc.data();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              data['posterUrl'] ?? '',
                              width: 40, height: 60, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 40, height: 60, color: Colors.white10,
                                child: const Icon(Icons.movie, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['title'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${data['language'] ?? 'N/A'} \u2022 ${data['genre'] ?? 'N/A'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx, false);
                  Navigator.pop(context);
                  showDialog(context: context, builder: (c) => const SearchMovieDialog());
                },
                icon: const Icon(Icons.search, size: 16),
                label: const Text('USE EXISTING'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CyberpunkTheme.primaryNeon,
                  side: const BorderSide(color: CyberpunkTheme.primaryNeon),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: const Text('CONTINUE REQUEST', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        );

        if (shouldContinue != true) return;
      }

      // Proceed with submission
      _submit();
    } catch (e) {
      if (mounted) setState(() => _checkingDuplicates = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking duplicates: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CyberpunkTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _orange, width: 1),
      ),
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.add_to_queue, color: _orange, size: 28),
                  const SizedBox(width: 12),
                  Text('REQUEST NEW MOVIE', style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Submit details for a movie not found in our global database. Admin will verify and approve.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 28),

                Row(children: [
                  Expanded(child: _buildTextField(_titleController, 'Movie Title', Icons.movie)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_langController, 'Language (e.g. Hindi, English)', Icons.language)),
                ]),
                const SizedBox(height: 16),

                Row(children: [
                  Expanded(child: _buildTextField(_genreController, 'Genre', Icons.category)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_durationController, 'Duration (mins)', Icons.timer, isNumber: true)),
                ]),
                const SizedBox(height: 16),

                Row(children: [
                  Expanded(child: _buildTextField(_certController, 'Certificate (e.g. U/A)', Icons.verified_user)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDatePicker()),
                ]),
                const SizedBox(height: 16),

                _buildTextField(_descController, 'Description / Synopsis', Icons.description, maxLines: 3),
                const SizedBox(height: 20),

                const Text('IMAGES', style: TextStyle(color: _orange, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 12),
                SizedBox(
                  width: 250,
                  child: _buildImagePicker('Poster (2:3)', Icons.image, _posterBytes, _pickPoster, 2 / 3),
                ),
                const SizedBox(height: 16),

                _buildTextField(_trailerController, 'Trailer URL (YouTube/Vimeo)', Icons.play_circle_fill),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('CANCEL', style: TextStyle(color: _hintGrey)),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      onPressed: (_saving || _checkingDuplicates) ? null : _checkDuplicatesAndSubmit,
                      icon: (_saving || _checkingDuplicates)
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 18),
                      label: Text(_checkingDuplicates ? 'Checking...' : _saving ? 'Submitting...' : 'SUBMIT REQUEST'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(String label, IconData icon, Uint8List? bytes, VoidCallback onTap, double aspectRatio) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bytes != null ? _orange.withValues(alpha: 0.5) : const Color(0xFF444444)),
        ),
        child: Column(children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: bytes != null
                ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(11)), child: Image.memory(bytes, fit: BoxFit.cover))
                : Icon(icon, color: _hintGrey, size: 40),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(context: context, initialDate: _releaseDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (date != null) setState(() => _releaseDate = date);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Release Date', prefixIcon: Icon(Icons.calendar_today, size: 20)),
        child: Text(DateFormat('yyyy-MM-dd').format(_releaseDate)),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_posterBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poster image is required')));
      return;
    }

    setState(() => _saving = true);
    try {
      final posterUrl = await _uploadImage(_posterBytes!, 'posters');

      final movieData = {
        'title': _titleController.text.trim(),
        'language': _langController.text.trim(),
        'genre': _genreController.text.trim(),
        'duration': int.parse(_durationController.text.trim()),
        'certificate': _certController.text.trim(),
        'description': _descController.text.trim(),
        'posterUrl': posterUrl,
        'bannerUrl': '',
        'trailerUrl': _trailerController.text.trim(),
        'releaseDate': Timestamp.fromDate(_releaseDate),
      };

      await Provider.of<TheatreService>(context, listen: false).requestNewMovie(movieData);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
