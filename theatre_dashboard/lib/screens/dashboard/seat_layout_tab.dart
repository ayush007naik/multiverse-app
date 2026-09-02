import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import '../../services/theatre_service.dart';

class SeatLayoutTab extends StatefulWidget {
  const SeatLayoutTab({super.key});

  @override
  State<SeatLayoutTab> createState() => _SeatLayoutTabState();
}

class _SeatLayoutTabState extends State<SeatLayoutTab> {
  static const _orange = Color(0xFFFF5722);
  static const _darkSurface = Color(0xFF1E1E1E);
  static const _hintGrey = Color(0xFFAAAAAA);

  // ── Screen Management ──
  List<String> _screens = <String>[];
  int _selectedScreenIndex = 0;
  final Map<String, Map<String, dynamic>> _screenLayouts = {};

  // ── Design State (current screen) ──
  int _rows = 8;
  int _seatsPerRow = 10;
  List<int> _rowSeats = List.generate(8, (i) => 10);
  List<String> _rowLabels = List.generate(8, (i) => String.fromCharCode(65 + i));
  List<String> _rowCategories = List.generate(8, (i) {
    if (i < 3) return 'Platinum';
    if (i < 6) return 'Gold';
    return 'Silver';
  });
  int _centerAisleAfter = 0;
  int _centerAisleWidth = 40;
  int _centerAisleRowLimit = 8;
  int _walkPathAfterRow = 0;
  int _walkPathWidth = 40;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  Map<String, Color> _categoryColors = {
    'Platinum': const Color(0xFFFF5F00),
    'Gold': const Color(0xFFFFD700),
    'Silver': const Color(0xFF78909C),
    'Recliner': const Color(0xFF00E5FF),
  };

  static const List<Color> _colorPalette = [
    Color(0xFFFF5F00),
    Color(0xFFFFD700),
    Color(0xFF78909C),
    Color(0xFF00E5FF),
    Color(0xFFFF5722),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFFF44336),
    Color(0xFF00BCD4),
    Color(0xFFFFC107),
    Color(0xFF8BC34A),
    Color(0xFF3F51B5),
    Color(0xFFFF9800),
    Color(0xFF795548),
    Colors.white,
    Colors.white70,
  ];

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    setState(() => _loading = true);
    try {
      final theatreService = Provider.of<TheatreService>(context, listen: false);
      final snap = await FirebaseFirestore.instance.collection('theatres').doc(theatreService.currentUid).get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;

        // Load screen list from theatre profile.
        // The profile may store 'screens' as a List of names or an int count.
        final rawScreens = data['screens'];
        if (rawScreens is List && rawScreens.isNotEmpty) {
          _screens = rawScreens.map((e) => e.toString()).toList();
        } else if (rawScreens is num) {
          final count = rawScreens.toInt().clamp(1, 26);
          _screens = List.generate(count, (i) => 'Screen ${i + 1}');
        }

        // Load per-screen layouts
        final savedLayouts = data['screenLayouts'] as Map<String, dynamic>?;
        if (savedLayouts != null && savedLayouts.isNotEmpty) {
          for (final entry in savedLayouts.entries) {
            _screenLayouts[entry.key] = Map<String, dynamic>.from(entry.value as Map);
            if (!_screens.contains(entry.key)) _screens.add(entry.key);
          }
        }

        // Load legacy single seatLayout as a fallback so existing data is never lost
        final legacy = data['seatLayout'] as Map<String, dynamic>?;
        if (legacy != null) {
          if (_screens.isEmpty) _screens.add('Screen 1');
          if (!_screenLayouts.containsKey(_screens.first)) {
            _screenLayouts[_screens.first] = Map<String, dynamic>.from(legacy);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [_loadLayouts] Error: $e');
    }
    if (_screens.isNotEmpty) {
      _applyLayout(_screens[_selectedScreenIndex]);
    } else {
      _resetToDefaults();
    }
    setState(() => _loading = false);
  }

  void _applyLayout(String screenName) {
    final layout = _screenLayouts[screenName];
    if (layout == null) {
      _resetToDefaults();
      return;
    }
    _rows = (layout['rows'] ?? 8) as int;
    _seatsPerRow = (layout['seatsPerRow'] ?? 10) as int;

    final savedRowSeats = layout['rowSeats'] as List?;
    if (savedRowSeats != null) {
      _rowSeats = savedRowSeats.map((e) => int.parse(e.toString())).toList();
    } else {
      _rowSeats = List.generate(_rows, (i) => _seatsPerRow);
    }

    final savedLabels = layout['rowLabels'] as List?;
    _rowLabels = savedLabels?.map((e) => e.toString()).toList() ??
        List.generate(_rows, (i) => String.fromCharCode(65 + i));

    _centerAisleAfter = (layout['centerAisleAfter'] ?? 0) as int;
    _centerAisleRowLimit = (layout['centerAisleRowLimit'] ?? _rows) as int;
    _walkPathAfterRow = (layout['walkPathAfterRow'] ?? 0) as int;
    _walkPathWidth = (layout['walkPathWidth'] ?? 40) as int;
    _centerAisleWidth = (layout['centerAisleWidth'] ?? 40) as int;

    final savedCats = layout['rowCategories'] as List?;
    if (savedCats != null) {
      _rowCategories = savedCats.map((e) => e.toString()).toList();
    } else {
      _rowCategories = List.generate(_rows, (i) {
        final third = _rows / 3;
        if (i < third) return 'Platinum';
        if (i < third * 2) return 'Gold';
        return 'Silver';
      });
    }

    final savedColors = layout['categoryColors'] as Map?;
    if (savedColors != null && savedColors.isNotEmpty) {
      final colors = <String, Color>{};
      savedColors.forEach((key, value) {
        final intVal = int.tryParse(value.toString());
        if (intVal != null) colors[key.toString()] = Color(intVal);
      });
      if (colors.isNotEmpty) _categoryColors = colors;
    }

    while (_rowLabels.length < _rows) {
      _rowLabels.add(String.fromCharCode(65 + _rowLabels.length));
    }
    while (_rowCategories.length < _rows) {
      _rowCategories.add('Silver');
    }
    while (_rowSeats.length < _rows) {
      _rowSeats.add(_seatsPerRow);
    }
    if (_walkPathAfterRow >= _rows) _walkPathAfterRow = _rows - 1;
    if (_centerAisleRowLimit > _rows) _centerAisleRowLimit = _rows;
  }

  void _resetToDefaults() {
    _rows = 8;
    _seatsPerRow = 10;
    _rowSeats = List.generate(8, (i) => 10);
    _rowLabels = List.generate(8, (i) => String.fromCharCode(65 + i));
    _rowCategories = List.generate(8, (i) {
      if (i < 3) return 'Platinum';
      if (i < 6) return 'Gold';
      return 'Silver';
    });
    _categoryColors = {
      'Platinum': const Color(0xFFFF5F00),
      'Gold': const Color(0xFFFFD700),
      'Silver': const Color(0xFF78909C),
      'Recliner': const Color(0xFF00E5FF),
    };
    _centerAisleAfter = 0;
    _centerAisleWidth = 40;
    _centerAisleRowLimit = 8;
    _walkPathAfterRow = 0;
    _walkPathWidth = 40;
  }

  void _selectScreen(int index) {
    if (index == _selectedScreenIndex) return;
    _saveCurrentToMap();
    setState(() {
      _selectedScreenIndex = index;
      _dirty = false;
    });
    _applyLayout(_screens[index]);
  }

  void _saveCurrentToMap() {
    final screenName = _screens[_selectedScreenIndex];
    _screenLayouts[screenName] = {
      'rows': _rows,
      'seatsPerRow': _seatsPerRow,
      'rowSeats': _rowSeats,
      'rowLabels': _rowLabels,
      'rowCategories': _rowCategories,
      'categoryColors': _categoryColors.map((k, v) => MapEntry(k, v.toARGB32())),
      'centerAisleAfter': _centerAisleAfter,
      'centerAisleWidth': _centerAisleWidth,
      'centerAisleRowLimit': _centerAisleRowLimit,
      'walkPathAfterRow': _walkPathAfterRow,
      'walkPathWidth': _walkPathWidth,
    };
  }

  Future<void> _addScreen() async {
    final name = 'Screen ${_screens.length + 1}';
    setState(() {
      _screens.add(name);
      _screenLayouts[name] = {};
      _selectedScreenIndex = _screens.length - 1;
      _resetToDefaults();
      _dirty = true;
    });
  }

  Future<void> _renameScreen(int index) async {
    final controller = TextEditingController(text: _screens[index]);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkSurface,
        title: const Text('Rename Screen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          style: const TextStyle(color: Colors.white),
          cursorColor: _orange,
          decoration: InputDecoration(
            labelText: 'Screen Name',
            labelStyle: const TextStyle(color: _hintGrey),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _orange.withValues(alpha: 0.4))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _orange)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: _hintGrey))),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('RENAME', style: TextStyle(color: _orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == _screens[index]) return;
    if (_screens.contains(newName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screen "$newName" already exists'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    setState(() {
      final oldName = _screens[index];
      _screens[index] = newName;
      final layout = _screenLayouts.remove(oldName);
      if (layout != null) _screenLayouts[newName] = layout;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final theatreService = Provider.of<TheatreService>(context, listen: false);

      _saveCurrentToMap();

      // Build screenLayouts map for Firestore
      final Map<String, dynamic> firestoreLayouts = {};
      for (final entry in _screenLayouts.entries) {
        final layout = Map<String, dynamic>.from(entry.value);
        final rowSeats = (layout['rowSeats'] as List?)?.map((e) => e).toList() ??
            List.generate(layout['rows'] as int? ?? 8, (i) => layout['seatsPerRow'] as int? ?? 10);
        final totalSeats = rowSeats.fold<int>(0, (sum, item) => sum + (int.tryParse(item.toString()) ?? 0));
        layout['totalSeats'] = totalSeats;
        firestoreLayouts[entry.key] = layout;
      }

      await theatreService.updateTheatreProfile({
        'screens': _screens,
        'screenLayouts': firestoreLayouts,
      });
      _dirty = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Layout saved for ${_screens[_selectedScreenIndex]}'),
              backgroundColor: const Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updateRows(int newRows) {
    if (newRows < 1 || newRows > 26) return;
    setState(() {
      _rows = newRows;
      while (_rowLabels.length < _rows) {
        _rowLabels.add(String.fromCharCode(65 + _rowLabels.length));
      }
      while (_rowCategories.length < _rows) {
        _rowCategories.add('Silver');
      }
      while (_rowSeats.length < _rows) {
        _rowSeats.add(_seatsPerRow);
      }

      _rowLabels = _rowLabels.sublist(0, _rows);
      _rowCategories = _rowCategories.sublist(0, _rows);
      _rowSeats = _rowSeats.sublist(0, _rows);
      if (_walkPathAfterRow >= _rows) _walkPathAfterRow = _rows - 1;
      if (_centerAisleRowLimit > _rows) _centerAisleRowLimit = _rows;
      _dirty = true;
    });
  }

  void _updateSeats(int newSeats) {
    if (newSeats < 1 || newSeats > 30) return;
    setState(() {
      _seatsPerRow = newSeats;
      for (int i = 0; i < _rowSeats.length; i++) {
        _rowSeats[i] = newSeats;
      }
      _dirty = true;
    });
  }

  void _updateRowSpecificSeats(int rowIndex, int newSeats) {
    if (newSeats < 1 || newSeats > 30) return;
    setState(() {
      _rowSeats[rowIndex] = newSeats;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _orange));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Icon(Icons.event_seat, color: _orange, size: 28),
            const SizedBox(width: 12),
            const Text('SEAT LAYOUT DESIGN', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const Spacer(),
            if (_screens.isNotEmpty) ...[
              if (_dirty) Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: _orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Text('Unsaved', style: TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save Layout'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          // Screen Selector
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...List.generate(_screens.length, (i) {
                  final isSelected = i == _selectedScreenIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _selectScreen(i),
                      onLongPress: () => _renameScreen(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? _orange : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? _orange : const Color(0xFF444444)),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _screens[i],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _renameScreen(i),
                                child: const Icon(Icons.edit, size: 14, color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: _addScreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: _orange, size: 18),
                          SizedBox(width: 4),
                          Text('Add Screen', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_screens.isEmpty)
            Expanded(child: _buildEmptyState())
          else
            Expanded(child: _buildDesignTab()),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: _orange.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.event_seat, color: _orange, size: 44),
          ),
          const SizedBox(height: 20),
          const Text('No screens yet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add a screen to start designing your seat layout.', style: TextStyle(color: _hintGrey, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addScreen,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('ADD SCREEN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(children: [
              _buildControlCard(),
              const SizedBox(height: 16),
              _buildCategoryCard(),
              const SizedBox(height: 16),
              _buildStatsCard(),
            ]),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: _buildDesignPreview()),
      ],
    );
  }

  Widget _buildControlCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CONFIGURATION', style: TextStyle(color: _orange, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 16),
        const Text('Number of Rows', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          _stepperBtn(Icons.remove, () => _updateRows(_rows - 1)),
          Expanded(child: Center(child: Text('$_rows', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))),
          _stepperBtn(Icons.add, () => _updateRows(_rows + 1)),
        ]),
        const Center(child: Text('1 to 26 rows (A-Z)', style: TextStyle(color: _hintGrey, fontSize: 11))),
        const SizedBox(height: 16),
        const Text('Default Seats Per Row', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          _stepperBtn(Icons.remove, () => _updateSeats(_seatsPerRow - 1)),
          Expanded(child: Center(child: Text('$_seatsPerRow', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))),
          _stepperBtn(Icons.add, () => _updateSeats(_seatsPerRow + 1)),
        ]),
        const Center(child: Text('Sets default for all rows', style: TextStyle(color: _hintGrey, fontSize: 11))),
        const SizedBox(height: 16),
        const Text('Walk Path Between Rows', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          const Text('After row', style: TextStyle(color: _hintGrey, fontSize: 12)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.remove, () => setState(() { _walkPathAfterRow = (_walkPathAfterRow - 1).clamp(0, _rows - 1); _dirty = true; })),
          const SizedBox(width: 8),
          Text(_walkPathAfterRow == 0 ? 'OFF' : _rowLabels[_walkPathAfterRow - 1], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.add, () => setState(() { _walkPathAfterRow = (_walkPathAfterRow + 1).clamp(0, _rows - 1); _dirty = true; })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Width', style: TextStyle(color: _hintGrey, fontSize: 12)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.remove, () => setState(() { _walkPathWidth = (_walkPathWidth - 8).clamp(16, 120); _dirty = true; })),
          const SizedBox(width: 8),
          Text('$_walkPathWidth', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.add, () => setState(() { _walkPathWidth = (_walkPathWidth + 8).clamp(16, 120); _dirty = true; })),
        ]),
        const Center(child: Text('0 = No walk path, or select a row number', style: TextStyle(color: _hintGrey, fontSize: 11))),
        const SizedBox(height: 16),
        const Text('Column Walk Path (Center Aisle)', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          const Text('After seat', style: TextStyle(color: _hintGrey, fontSize: 12)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.remove, () => setState(() { _centerAisleAfter = (_centerAisleAfter - 1).clamp(0, _seatsPerRow - 1); _dirty = true; })),
          const SizedBox(width: 8),
          Text(_centerAisleAfter == 0 ? 'OFF' : '$_centerAisleAfter', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.add, () => setState(() { _centerAisleAfter = (_centerAisleAfter + 1).clamp(0, _seatsPerRow - 1); _dirty = true; })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Width', style: TextStyle(color: _hintGrey, fontSize: 12)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.remove, () => setState(() { _centerAisleWidth = (_centerAisleWidth - 8).clamp(16, 120); _dirty = true; })),
          const SizedBox(width: 8),
          Text('$_centerAisleWidth', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.add, () => setState(() { _centerAisleWidth = (_centerAisleWidth + 8).clamp(16, 120); _dirty = true; })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Apply to rows', style: TextStyle(color: _hintGrey, fontSize: 12)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.remove, () => setState(() { _centerAisleRowLimit = (_centerAisleRowLimit - 1).clamp(0, _rows); _dirty = true; })),
          const SizedBox(width: 8),
          Text(_centerAisleRowLimit == 0 ? 'OFF' : '$_centerAisleRowLimit', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _miniStepperBtn(Icons.add, () => setState(() { _centerAisleRowLimit = (_centerAisleRowLimit + 1).clamp(0, _rows); _dirty = true; })),
        ]),
        const Center(child: Text('0 = Off | Walk path applied to first N rows', style: TextStyle(color: _hintGrey, fontSize: 11))),
        const SizedBox(height: 24),
        const Text('INDIVIDUAL ROW SEATS', style: TextStyle(color: _orange, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        ...List.generate(_rows, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 30, child: Text(_rowLabels[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              _miniStepperBtn(Icons.remove, () => _updateRowSpecificSeats(i, _rowSeats[i] - 1)),
              Expanded(child: Center(child: Text('${_rowSeats[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
              _miniStepperBtn(Icons.add, () => _updateRowSpecificSeats(i, _rowSeats[i] + 1)),
            ]),
          );
        }),
        const SizedBox(height: 16),
        const Text('Row Labels', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: List.generate(_rows, (i) {
          return Container(
            width: 44, height: 32,
            decoration: BoxDecoration(
              color: _categoryColors[_rowCategories[i]]?.withValues(alpha: 0.2) ?? Colors.white10,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _categoryColors[_rowCategories[i]]?.withValues(alpha: 0.5) ?? Colors.white24),
            ),
            child: TextField(
              controller: TextEditingController(text: _rowLabels[i]),
              textAlign: TextAlign.center, maxLength: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(counterText: '', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6)),
              onChanged: (v) { if (v.isNotEmpty) setState(() { _rowLabels[i] = v.toUpperCase(); _dirty = true; }); },
            ),
          );
        })),
      ]),
    );
  }

  Widget _buildCategoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ROW CATEGORIES', style: TextStyle(color: _orange, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        ...List.generate(_rows, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 40, child: Text(_rowLabels[i], style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              ...['Platinum', 'Gold', 'Silver', 'Recliner'].map((cat) {
                final isSelected = _rowCategories[i] == cat;
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() { _rowCategories[i] = cat; _dirty = true; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? _categoryColors[cat]!.withValues(alpha: 0.3) : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? _categoryColors[cat]! : const Color(0xFF444444)),
                    ),
                    child: Text(cat, textAlign: TextAlign.center,
                        style: TextStyle(color: isSelected ? _categoryColors[cat]! : _hintGrey, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  ),
                ));
              }),
            ]),
          );
        }),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() {
              final third = _rows / 3;
              for (int i = 0; i < _rows; i++) {
                if (i < third) {
                  _rowCategories[i] = 'Platinum';
                } else if (i < third * 2) _rowCategories[i] = 'Gold';
                else _rowCategories[i] = 'Silver';
              }
              _dirty = true;
            }),
            style: OutlinedButton.styleFrom(foregroundColor: _orange, side: BorderSide(color: _orange.withValues(alpha: 0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Auto Split', style: TextStyle(fontSize: 11)),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() { for (int i = 0; i < _rows; i++) {
              _rowCategories[i] = 'Platinum';
            } _dirty = true; }),
            style: OutlinedButton.styleFrom(foregroundColor: _categoryColors['Platinum'], side: BorderSide(color: _categoryColors['Platinum']!.withValues(alpha: 0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('All Platinum', style: TextStyle(fontSize: 11)),
          )),
        ]),
        const SizedBox(height: 16),
        const Text('CATEGORY COLORS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...['Platinum', 'Gold', 'Silver', 'Recliner'].map((cat) {
          final color = _categoryColors[cat] ?? Colors.grey;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              onTap: () => _pickCategoryColor(cat),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  Container(width: 18, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                  const Icon(Icons.colorize, color: Colors.white54, size: 18),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        const Center(child: Text('Tap a category to change its seat color', style: TextStyle(color: _hintGrey, fontSize: 11))),
      ]),
    );
  }

  Future<void> _pickCategoryColor(String category) async {
    final current = _categoryColors[category] ?? Colors.grey;
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkSurface,
        title: Text('Choose color for $category', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colorPalette.map((c) {
            final isCurrent = c.toARGB32() == current.toARGB32();
            return GestureDetector(
              onTap: () => Navigator.pop(context, c),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrent ? Colors.white : Colors.white24,
                    width: isCurrent ? 3 : 1,
                  ),
                ),
                child: isCurrent ? const Icon(Icons.check, color: Colors.black, size: 20) : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: _hintGrey))),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _categoryColors[category] = picked;
        _dirty = true;
      });
    }
  }

  Widget _buildStatsCard() {
    final totalSeats = _rowSeats.fold(0, (sum, item) => sum + item);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SUMMARY', style: TextStyle(color: _orange, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        _statRow('Screen', _screens[_selectedScreenIndex], Colors.white70),
        _statRow('Total Rows', '$_rows', Colors.white70),
        _statRow('Total Seats', '$totalSeats', Colors.white),
        const Divider(color: Colors.white12, height: 16),
        ..._categoryStats(totalSeats),
      ]),
    );
  }

  List<Widget> _categoryStats(int total) {
    final Map<String, int> catSeats = {};
    for (int i = 0; i < _rows; i++) {
      catSeats[_rowCategories[i]] = (catSeats[_rowCategories[i]] ?? 0) + _rowSeats[i];
    }

    return catSeats.entries.map((e) {
      return _statRow(e.key, '${e.value} seats', _categoryColors[e.key]!);
    }).toList();
  }

  Widget _buildDesignPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(children: [
        Text(_screens[_selectedScreenIndex].toUpperCase(),
            style: const TextStyle(color: Color(0xFF00F2FF), letterSpacing: 4, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Container(height: 4, width: 250, decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0x0000F2FF), Color(0xFF00F2FF), Color(0x0000F2FF)]),
          borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(height: 20),
        Expanded(child: SingleChildScrollView(child: Column(children: [
          ...() {
            final children = <Widget>[];
            for (int i = 0; i < _rows; i++) {
              final catColor = _categoryColors[_rowCategories[i]] ?? Colors.grey;
              final seatsInRow = _rowSeats[i];
              final hasAisle = _centerAisleAfter > 0 && _centerAisleAfter < seatsInRow && i < _centerAisleRowLimit;
              children.add(Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 28, child: Text(_rowLabels[i], style: TextStyle(fontWeight: FontWeight.bold, color: catColor, fontSize: 11), textAlign: TextAlign.center)),
                if (!hasAisle) ...List.generate(seatsInRow, (_) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: seatsInRow > 20 ? 14 : seatsInRow > 15 ? 18 : 22,
                  height: seatsInRow > 20 ? 14 : seatsInRow > 15 ? 18 : 22,
                  decoration: BoxDecoration(color: catColor.withValues(alpha: 0.35), borderRadius: const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(2)), border: Border.all(color: catColor.withValues(alpha: 0.6), width: 0.5)),
                )),
                if (hasAisle) ...[
                  ...List.generate(_centerAisleAfter, (_) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: seatsInRow > 20 ? 14 : seatsInRow > 15 ? 18 : 22,
                    height: seatsInRow > 20 ? 14 : seatsInRow > 15 ? 18 : 22,
                    decoration: BoxDecoration(color: catColor.withValues(alpha: 0.35), borderRadius: const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(2)), border: Border.all(color: catColor.withValues(alpha: 0.6), width: 0.5)),
                  )),
                  Container(
                    width: _centerAisleWidth.toDouble(),
                    height: (seatsInRow > 20 ? 14 : seatsInRow > 15 ? 18 : 22),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
                    alignment: Alignment.center,
                    child: const Text('WALK PATH', style: TextStyle(color: Colors.white24, fontSize: 8, letterSpacing: 1)),
                  ),
                  ...List.generate(seatsInRow - _centerAisleAfter, (_) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: seatsInRow > 20 ? 14 : seatsInRow > 15 ? 18 : 22,
                    height: seatsInRow > 20 ? 14 : seatsInRow > 15 ? 18 : 22,
                    decoration: BoxDecoration(color: catColor.withValues(alpha: 0.35), borderRadius: const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(2)), border: Border.all(color: catColor.withValues(alpha: 0.6), width: 0.5)),
                  )),
                ],
                SizedBox(width: 28, child: Text(_rowLabels[i], style: TextStyle(fontWeight: FontWeight.bold, color: catColor, fontSize: 11), textAlign: TextAlign.center)),
              ])));
              if (_walkPathAfterRow > 0 && i == _walkPathAfterRow - 1) {
                children.add(Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Center(child: Container(
                    width: 200, height: _walkPathWidth.toDouble(),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Center(child: Text('WALK PATH', style: TextStyle(color: Colors.white24, fontSize: 9, letterSpacing: 2))),
                  )),
                ));
              }
            }
            return children;
          }(),
        ]))),
        const SizedBox(height: 16),
        _buildLegend(),
      ]),
    );
  }

  // ── Helpers ──

  Widget _statRow(String label, String value, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: const TextStyle(color: _hintGrey, fontSize: 12)), Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))],
    ));
  }

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF444444))),
      child: Icon(icon, color: _orange, size: 20),
    ));
  }

  Widget _miniStepperBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 24, height: 24,
      decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF444444))),
      child: Icon(icon, color: _orange, size: 14),
    ));
  }

  Widget _buildLegend() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _legendItem('Platinum', _categoryColors['Platinum']!.withValues(alpha: 0.4)),
      const SizedBox(width: 16),
      _legendItem('Gold', _categoryColors['Gold']!.withValues(alpha: 0.4)),
      const SizedBox(width: 16),
      _legendItem('Silver', _categoryColors['Silver']!.withValues(alpha: 0.5)),
      const SizedBox(width: 16),
      _legendItem('Recliner', _categoryColors['Recliner']!.withValues(alpha: 0.4)),
    ]);
  }

  Widget _legendItem(String label, Color color) {
    return Row(children: [
      Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.white24))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: _hintGrey)),
    ]);
  }
}
