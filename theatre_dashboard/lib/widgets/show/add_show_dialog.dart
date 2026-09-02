import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:intl/intl.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';

class AddShowDialog extends StatefulWidget {
  final String? showId;
  final Map<String, dynamic>? showData;
  final Map<String, dynamic>? preselectedMovie;

  const AddShowDialog({super.key, this.showId, this.showData, this.preselectedMovie});

  @override
  State<AddShowDialog> createState() => _AddShowDialogState();
}

class _AddShowDialogState extends State<AddShowDialog> {
  static const _orange = Color(0xFFFF5722);
  static const _darkSurface = Color(0xFF1E1E1E);
  static const _hintGrey = Color(0xFFAAAAAA);

  final _formKey = GlobalKey<FormState>();
  String? _selectedMovieId;
  String? _selectedMovieTitle;
  String? _selectedMoviePosterUrl;
  String? _selectedScreen;
  List<String> _availableScreens = ['Screen 1'];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);

  // Seat layout data
  bool _loadingLayout = true;
  int _rows = 8;
  int _seatsPerRow = 10;
  List<int> _rowSeats = [];
  List<String> _rowLabels = [];
  List<String> _rowCategories = [];
  final Map<String, dynamic> _extraSeatLayout = {};
  final Map<String, TextEditingController> _priceControllers = {};
  Map<String, Color> _categoryColors = {
    'Platinum': const Color(0xFFFF5F00),
    'Gold': const Color(0xFFFFD700),
    'Silver': const Color(0xFF78909C),
    'Recliner': const Color(0xFF00E5FF),
  };

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.showData != null) {
      _selectedMovieId = widget.showData!['movieId'];
      _selectedMovieTitle = widget.showData!['movieTitle'];
      _selectedScreen = widget.showData!['screen'];
      final rawStart = widget.showData!['startTime'];
      if (rawStart is Timestamp) {
        final start = rawStart.toDate();
        _selectedDate = DateTime(start.year, start.month, start.day);
        _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
      }
    } else if (widget.preselectedMovie != null) {
      _selectedMovieId = widget.preselectedMovie!['id'];
      _selectedMovieTitle = widget.preselectedMovie!['title'];
    }
    _loadSeatLayout();
  }

  Future<void> _loadSeatLayout() async {
    try {
      if (widget.showData != null && widget.showData!['seatLayout'] != null) {
        final seatLayout = widget.showData!['seatLayout'] as Map<String, dynamic>;
        _rows = (seatLayout['rows'] ?? 8) as int;
        _seatsPerRow = (seatLayout['seatsPerRow'] ?? 10) as int;
        _rowSeats = (seatLayout['rowSeats'] as List?)?.map((e) => int.parse(e.toString())).toList() ?? List.generate(_rows, (i) => _seatsPerRow);
        _rowLabels = (seatLayout['rowLabels'] as List).map((e) => e.toString()).toList();
        _rowCategories = (seatLayout['rowCategories'] as List).map((e) => e.toString()).toList();
        _applySavedColors(seatLayout['categoryColors'] as Map?);

        final pricing = widget.showData!['pricing'] as Map<String, dynamic>? ?? {};
        pricing.forEach((cat, price) {
          _priceControllers[cat] = TextEditingController(text: price.toString());
        });
      } else {
        final theatreService = Provider.of<TheatreService>(context, listen: false);
        final snap = await theatreService.getTheatreProfile().first;
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;

          // Load available screens from theatre profile.
          // The profile may store 'screens' as a List of names or an int count.
          final rawScreens = data['screens'];
          if (rawScreens is List && rawScreens.isNotEmpty) {
            _availableScreens = rawScreens.map((e) => e.toString()).toList();
          } else if (rawScreens is num) {
            final count = rawScreens.toInt().clamp(1, 26);
            _availableScreens = List.generate(count, (i) => 'Screen ${i + 1}');
          }

          final screenLayouts = data['screenLayouts'] as Map<String, dynamic>?;
          if (screenLayouts != null && screenLayouts.isNotEmpty) {
            // Show every screen that has a saved layout from the Seat Layout tab
            for (final key in screenLayouts.keys) {
              if (!_availableScreens.contains(key)) _availableScreens.add(key);
            }
            // Default to the first screen that actually has a saved layout
            if (_selectedScreen == null || !_availableScreens.contains(_selectedScreen)) {
              _selectedScreen = screenLayouts.keys.first;
            }
          } else {
            _selectedScreen ??= _availableScreens.first;
          }

          final screenName = _selectedScreen ?? _availableScreens.first;

          Map<String, dynamic>? seatLayout;
          if (screenLayouts != null && screenLayouts[screenName] != null) {
            seatLayout = Map<String, dynamic>.from(screenLayouts[screenName] as Map);
          } else {
            seatLayout = data['seatLayout'] as Map<String, dynamic>?;
          }

          _rows = (seatLayout?['rows'] ?? data['rowCount'] ?? 8) as int;
          _seatsPerRow = (seatLayout?['seatsPerRow'] ?? data['seatsPerRow'] ?? 10) as int;

          final savedRowSeats = seatLayout?['rowSeats'] as List?;
          if (savedRowSeats != null) {
            _rowSeats = savedRowSeats.map((e) => int.parse(e.toString())).toList();
          } else {
            _rowSeats = List.generate(_rows, (i) => _seatsPerRow);
          }

          final savedLabels = seatLayout?['rowLabels'] as List? ?? data['rowLabels'] as List?;
          _rowLabels = savedLabels?.map((e) => e.toString()).toList() ??
              List.generate(_rows, (i) => String.fromCharCode(65 + i));

          final savedCats = seatLayout?['rowCategories'] as List?;
          if (savedCats != null) {
            _rowCategories = savedCats.map((e) => e.toString()).toList();
          } else {
            final third = _rows / 3;
            _rowCategories = List.generate(_rows, (i) {
              if (i < third) return 'Platinum';
              if (i < third * 2) return 'Gold';
              return 'Silver';
            });
          }

          if (seatLayout != null) {
            _applySavedColors(seatLayout['categoryColors'] as Map?);
            for (final key in seatLayout.keys) {
              if (!['rows', 'seatsPerRow', 'rowSeats', 'rowLabels', 'rowCategories'].contains(key)) {
                _extraSeatLayout[key] = seatLayout[key];
              }
            }
          }
        }
      }
    } catch (_) {}

    if (_rows < 1) _rows = 8;
    if (_seatsPerRow < 1) _seatsPerRow = 10;
    if (_rowSeats.length != _rows) {
      _rowSeats = List.generate(
        _rows,
        (i) => i < _rowSeats.length ? _rowSeats[i] : _seatsPerRow,
      );
    }
    if (_rowLabels.length != _rows) {
      _rowLabels = List.generate(
        _rows,
        (i) => i < _rowLabels.length ? _rowLabels[i] : String.fromCharCode(65 + i),
      );
    }
    if (_rowCategories.length != _rows) {
      final third = _rows / 3;
      _rowCategories = List.generate(
        _rows,
        (i) {
          if (i < _rowCategories.length) return _rowCategories[i];
          if (i < third) return 'Platinum';
          if (i < third * 2) return 'Gold';
          return 'Silver';
        },
      );
    }

    // Get unique categories in order
    final uniqueCats = <String>[];
    for (final cat in _rowCategories) {
      if (!uniqueCats.contains(cat)) uniqueCats.add(cat);
    }

    // Create price controllers for each category if not already created
    for (final cat in uniqueCats) {
      if (!_priceControllers.containsKey(cat)) {
        final defaultPrice = cat == 'Platinum' ? '400' : cat == 'Gold' ? '250' : cat == 'Recliner' ? '500' : '150';
        _priceControllers[cat] = TextEditingController(text: defaultPrice);
      }
    }

    if (mounted) setState(() => _loadingLayout = false);
  }

  void _applySavedColors(Map? saved) {
    if (saved == null || saved.isEmpty) return;
    final colors = <String, Color>{};
    saved.forEach((key, value) {
      final intVal = int.tryParse(value.toString());
      if (intVal != null) colors[key.toString()] = Color(intVal);
    });
    if (colors.isNotEmpty) _categoryColors = colors;
  }

  @override
  void dispose() {
    for (final c in _priceControllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);

    return Dialog(
      backgroundColor: CyberpunkTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _orange)),
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.calendar_month, color: _orange, size: 28),
                  const SizedBox(width: 12),
                  Text(widget.showData == null ? 'CREATE NEW SHOW' : 'EDIT SHOW', style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 28),

                // Movie Selection (only movies added to this theatre's My Shows)
                StreamBuilder<QuerySnapshot>(
                  stream: theatreService.getMyMovies(),
                  builder: (context, snapshot) {
                    final movies = snapshot.data?.docs ?? [];
                    if (movies.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No movies in My Shows. Add a movie from Movie Management first.', style: TextStyle(color: _hintGrey)),
                      );
                    }
                    final itemValues = movies
                        .map((m) => (m.data())['movieId']?.toString())
                        .whereType<String>()
                        .toSet();
                    final hasSelection = _selectedMovieId != null && itemValues.contains(_selectedMovieId);
                    return DropdownButtonFormField<String>(
                      initialValue: hasSelection ? _selectedMovieId : null,
                      decoration: const InputDecoration(labelText: 'Select Movie (Added to My Shows)', prefixIcon: Icon(Icons.movie)),
                      dropdownColor: _darkSurface,
                      items: movies.map((m) {
                        final data = m.data();
                        final movieId = data['movieId']?.toString();
                        if (movieId == null) return null;
                        return DropdownMenuItem(value: movieId, child: Text(data['movieTitle'] ?? 'Untitled'));
                      }).whereType<DropdownMenuItem<String>>().toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final movie = movies.firstWhere((m) => (m.data())['movieId']?.toString() == val);
                        final data = movie.data();
                        setState(() {
                          _selectedMovieId = val;
                          _selectedMovieTitle = data['movieTitle'];
                          _selectedMoviePosterUrl = data['moviePosterUrl'];
                        });
                      },
                      validator: (val) => val == null ? 'Required' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Screen Selection
                DropdownButtonFormField<String>(
                  initialValue: _selectedScreen,
                  decoration: const InputDecoration(labelText: 'Select Screen', prefixIcon: Icon(Icons.screenshot_monitor)),
                  dropdownColor: _darkSurface,
                  items: _availableScreens.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedScreen = val);
                    _loadSeatLayout();
                  },
                  validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: 6),
                Text(
                  'You can create/update seat layouts in the Seat Layout tab',
                  style: TextStyle(color: _hintGrey.withValues(alpha: 0.7), fontSize: 11),
                ),
                const SizedBox(height: 16),

                Row(children: [
                  Expanded(child: _buildDatePicker()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTimePicker()),
                ]),
                const SizedBox(height: 28),

                // ── Seat Layout Info + Pricing ──
                if (_loadingLayout)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _orange)))
                else ...[
                  const Text('SEAT PRICING', style: TextStyle(color: _orange, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    '$_rows rows × $_seatsPerRow seats = ${_rows * _seatsPerRow} total seats',
                    style: const TextStyle(color: _hintGrey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ..._buildCategoryPricingCards(),
                ],

                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      child: const Text('CANCEL', style: TextStyle(color: _hintGrey)),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18),
                      label: Text(_submitting ? (widget.showId == null ? 'Creating...' : 'Updating...') : (widget.showId == null ? 'CREATE SHOW' : 'UPDATE SHOW')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.showId == null ? const Color(0xFF4CAF50) : CyberpunkTheme.primaryNeon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  List<Widget> _buildCategoryPricingCards() {
    // Group rows by category
    final Map<String, List<int>> categoryRows = {};
    for (int i = 0; i < _rows; i++) {
      final cat = _rowCategories[i];
      categoryRows.putIfAbsent(cat, () => []).add(i);
    }

    final widgets = <Widget>[];
    for (final entry in categoryRows.entries) {
      final cat = entry.key;
      final rowsList = entry.value;
      final seats = rowsList.fold(0, (total, i) => total + _rowSeats[i]);
      final color = _categoryColors[cat] ?? Colors.grey;
      final rowLabelStr = rowsList.map((i) => _rowLabels[i]).join(', ');

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            // Category info
            Expanded(
              flex: 2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4), border: Border.all(color: color)),
                  ),
                  const SizedBox(width: 8),
                  Text(cat, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Rows: $rowLabelStr',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '${rowsList.length} rows | $seats total seats',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ]),
            ),
            // Price input
            Expanded(
              child: SizedBox(
                width: 120,
                child: TextFormField(
                  controller: _priceControllers[cat],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Price (₹)',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color.withValues(alpha: 0.3))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color.withValues(alpha: 0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
              ),
            ),
          ]),
        ),
      );
    }
    return widgets;
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
        if (date != null) setState(() => _selectedDate = date);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today)),
        child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
      ),
    );
  }

  Widget _buildTimePicker() {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(context: context, initialTime: _startTime);
        if (time != null) setState(() => _startTime = time);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Start Time', prefixIcon: Icon(Icons.access_time)),
        child: Text(_startTime.format(context)),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final startDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _startTime.hour, _startTime.minute,
      );

      // Build pricing map from actual categories
      final pricing = <String, double>{};
      for (final entry in _priceControllers.entries) {
        pricing[entry.key] = double.parse(entry.value.text);
      }

      final totalSeats = _rowSeats.fold(0, (total, item) => total + item);

      final showData = {
        'movieId': _selectedMovieId,
        'movieTitle': _selectedMovieTitle,
        'moviePosterUrl': _selectedMoviePosterUrl ?? '',
        'screen': _selectedScreen,
        'startTime': startDateTime,
        'endTime': startDateTime.add(const Duration(hours: 3)),
        'pricing': pricing,
        'totalSeats': totalSeats,
        'availableSeats': totalSeats,
        'seatLayout': {
          'rows': _rows,
          'seatsPerRow': _seatsPerRow,
          'rowSeats': _rowSeats,
          'rowLabels': _rowLabels,
          'rowCategories': _rowCategories,
          'categoryColors': _categoryColors.map((k, v) => MapEntry(k, v.toARGB32())),
          ..._extraSeatLayout,
        },
        'isActive': true,
      };

      final theatreService = Provider.of<TheatreService>(context, listen: false);
      if (widget.showId == null) {
        await theatreService.createShow(showData);
      } else {
        await theatreService.updateShow(widget.showId!, showData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
