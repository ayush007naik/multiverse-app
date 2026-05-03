import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class TheatreSignupScreen extends StatefulWidget {
  const TheatreSignupScreen({super.key});

  @override
  State<TheatreSignupScreen> createState() => _TheatreSignupScreenState();
}

class _TheatreSignupScreenState extends State<TheatreSignupScreen>
    with TickerProviderStateMixin {
  // ── Page controller ──────────────────────────────
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  bool _loading = false;

  // ── Form keys ────────────────────────────────────
  final _page1Key = GlobalKey<FormState>();
  final _page2Key = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _theatreName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();

  // ── Seat config ───────────────────────────────────
  int _rows = 8;
  int _cols = 10;

  // ── Visibility toggles ───────────────────────────
  bool _showPass = false;
  bool _showConfirm = false;

  // ── Animation ────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Theme colours
  static const _red = Color(0xFFE53935);
  static const _dark = Color(0xFF0D0D0D);
  static const _card = Color(0xFF1A1A1A);
  static const _border = Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    _ownerName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _theatreName.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────
  void _nextPage() {
    if (_currentPage == 0 && !_page1Key.currentState!.validate()) return;
    if (_currentPage == 1 && !_page2Key.currentState!.validate()) return;

    if (_currentPage < 2) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
      setState(() => _currentPage++);
    } else {
      _submit();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
      setState(() => _currentPage--);
    } else {
      Navigator.pop(context);
    }
  }

  // ── Submit ────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await AuthService().signUpTheatreOwner(
        email: _email.text.trim(),
        password: _password.text,
        ownerName: _ownerName.text.trim(),
        theatreName: _theatreName.text.trim(),
        address: '${_address.text.trim()}, ${_city.text.trim()}',
        totalRows: _rows,
        totalCols: _cols,
      );
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Colors.green, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Registration Submitted!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'Your theatre is pending admin approval.\nYou\'ll be notified once approved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // dialog
                  Navigator.pop(context); // screen
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Go to Login',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            )
          ]),
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red[800],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _dark,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Column(children: [
            _buildHeader(),
            _buildStepper(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                ],
              ),
            ),
            _buildBottomBar(),
          ]),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────
  Widget _buildHeader() {
    final titles = ['Personal Info', 'Theatre Details', 'Seat Layout'];
    final subtitles = [
      'Tell us about yourself',
      'Your theatre information',
      'Configure your seating',
    ];
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20,
          right: 20,
          bottom: 20),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _prevPage,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titles[_currentPage],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3)),
          Text(subtitles[_currentPage],
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const Spacer(),
        // Clapperboard icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: _red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.theater_comedy_rounded,
              color: _red, size: 20),
        ),
      ]),
    );
  }

  // ── Stepper dots ─────────────────────────────────
  Widget _buildStepper() {
    return Container(
      color: _card,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: List.generate(3, (i) {
        final active = i == _currentPage;
        final done = i < _currentPage;
        return Expanded(
          child: Row(children: [
            if (i > 0)
              Expanded(
                child: Container(
                  height: 1.5,
                  color: done ? _red : _border,
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 32 : 28,
              height: active ? 32 : 28,
              decoration: BoxDecoration(
                color: done
                    ? _red
                    : active
                    ? _red.withOpacity(0.15)
                    : _card,
                shape: BoxShape.circle,
                border: Border.all(
                    color: done || active ? _red : _border,
                    width: active ? 2 : 1),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14)
                    : Text('${i + 1}',
                    style: TextStyle(
                        color: active ? _red : Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            if (i < 2) const SizedBox(width: 0),
          ]),
        );
      })),
    );
  }

  // ══════════════════════════════════════════════════
  //  PAGE 1 – Personal Info
  // ══════════════════════════════════════════════════
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _page1Key,
        child: Column(children: [
          _sectionCard(
            icon: Icons.person_rounded,
            title: 'Owner Details',
            children: [
              _field(
                ctrl: _ownerName,
                label: 'Full Name',
                icon: Icons.badge_outlined,
                validator: _reqValidator,
              ),
              _field(
                ctrl: _phone,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 10) return 'Enter valid phone';
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            icon: Icons.lock_outline_rounded,
            title: 'Account Credentials',
            children: [
              _field(
                ctrl: _email,
                label: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter valid email';
                  return null;
                },
              ),
              _field(
                ctrl: _password,
                label: 'Password',
                icon: Icons.lock_outlined,
                obscure: !_showPass,
                suffixIcon: IconButton(
                  icon: Icon(
                      _showPass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                      size: 20),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              _field(
                ctrl: _confirmPassword,
                label: 'Confirm Password',
                icon: Icons.lock_outlined,
                obscure: !_showConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                      _showConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                      size: 20),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
                validator: (v) {
                  if (v != _password.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  PAGE 2 – Theatre Details
  // ══════════════════════════════════════════════════
  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _page2Key,
        child: Column(children: [
          _sectionCard(
            icon: Icons.movie_outlined,
            title: 'Theatre Info',
            children: [
              _field(
                ctrl: _theatreName,
                label: 'Theatre Name',
                icon: Icons.theater_comedy_outlined,
                validator: _reqValidator,
              ),
              _field(
                ctrl: _city,
                label: 'City',
                icon: Icons.location_city_outlined,
                validator: _reqValidator,
              ),
              _field(
                ctrl: _address,
                label: 'Full Address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
                validator: _reqValidator,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Amenities chips (UI only)
          _sectionCard(
            icon: Icons.stars_rounded,
            title: 'Amenities',
            children: [
              _AmenitiesSelector(),
            ],
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  PAGE 3 – Seat Layout
  // ══════════════════════════════════════════════════
  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _red.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: _red, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Set your theatre\'s seating configuration. You can design detailed layout after approval.',
                style: TextStyle(
                    color: Colors.red[200], fontSize: 12, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Row & Col sliders
        _sectionCard(
          icon: Icons.grid_view_rounded,
          title: 'Seat Configuration',
          children: [
            _sliderRow(
              label: 'Rows',
              value: _rows,
              min: 3,
              max: 20,
              onChanged: (v) => setState(() => _rows = v),
            ),
            const SizedBox(height: 4),
            _sliderRow(
              label: 'Columns',
              value: _cols,
              min: 5,
              max: 20,
              onChanged: (v) => setState(() => _cols = v),
            ),
            const SizedBox(height: 16),
            // Stats row
            Row(children: [
              _statChip('Total Seats', '${_rows * _cols}',
                  Icons.event_seat_rounded),
              const SizedBox(width: 10),
              _statChip('Rows', '$_rows', Icons.table_rows_rounded),
              const SizedBox(width: 10),
              _statChip('Cols', '$_cols', Icons.view_column_rounded),
            ]),
          ],
        ),
        const SizedBox(height: 20),

        // Mini seat preview
        _sectionCard(
          icon: Icons.preview_rounded,
          title: 'Preview',
          children: [
            const Center(
              child: Text('SCREEN',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      letterSpacing: 3)),
            ),
            const SizedBox(height: 4),
            Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            _SeatPreview(rows: _rows, cols: _cols),
            const SizedBox(height: 10),
            // Legend
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legendDot(const Color(0xFF1E88E5), 'Regular'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFFFB300), 'Premium'),
            ]),
          ],
        ),
      ]),
    );
  }

  // ── Bottom bar ────────────────────────────────────
  Widget _buildBottomBar() {
    final labels = ['Continue', 'Continue', 'Submit Registration'];
    return Container(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14),
      decoration: const BoxDecoration(
          color: _card,
          border: Border(top: BorderSide(color: _border))),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _loading ? null : _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: _red,
            disabledBackgroundColor: _red.withOpacity(0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(labels[_currentPage],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            if (_currentPage < 2) ...[
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ],
          ]),
        ),
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: _red, size: 16),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: _red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
          const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.grey, size: 18),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white.withOpacity(0.04),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _red, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
              BorderSide(color: Colors.red[700]!, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
              BorderSide(color: Colors.red[700]!, width: 1.5)),
          errorStyle: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(children: [
      SizedBox(
        width: 68,
        child: Text(label,
            style:
            const TextStyle(color: Colors.grey, fontSize: 13)),
      ),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _red,
            inactiveTrackColor: _border,
            thumbColor: _red,
            overlayColor: _red.withOpacity(0.15),
            trackHeight: 3,
            thumbShape:
            const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ),
      Container(
        width: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
            color: _red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _red.withOpacity(0.3))),
        child: Text('$value',
            style: const TextStyle(
                color: _red,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border)),
        child: Column(children: [
          Icon(icon, color: Colors.grey, size: 16),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _legendDot(Color color, String text) => Row(children: [
    Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(text,
        style: const TextStyle(color: Colors.grey, fontSize: 11)),
  ]);

  String? _reqValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;
}

// ══════════════════════════════════════════════════
//  Seat Preview Widget
// ══════════════════════════════════════════════════
class _SeatPreview extends StatelessWidget {
  final int rows;
  final int cols;

  const _SeatPreview({required this.rows, required this.cols});

  @override
  Widget build(BuildContext context) {
    // Show max 6 rows x 10 cols in preview
    final previewRows = rows.clamp(1, 6);
    final previewCols = cols.clamp(1, 10);
    final dotSize = (MediaQuery.of(context).size.width - 80) / previewCols;
    final size = dotSize.clamp(8.0, 24.0);

    return Column(
      children: List.generate(previewRows, (r) {
        final isBack = r < previewRows ~/ 3;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(previewCols, (c) {
              return Container(
                width: size,
                height: size * 0.85,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: isBack
                      ? const Color(0xFFFFB300).withOpacity(0.85)
                      : const Color(0xFF1E88E5).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════
//  Amenities Selector
// ══════════════════════════════════════════════════
class _AmenitiesSelector extends StatefulWidget {
  @override
  State<_AmenitiesSelector> createState() => _AmenitiesSelectorState();
}

class _AmenitiesSelectorState extends State<_AmenitiesSelector> {
  final _items = [
    {'label': 'Parking', 'icon': Icons.local_parking_rounded},
    {'label': 'Food Court', 'icon': Icons.fastfood_rounded},
    {'label': 'AC', 'icon': Icons.ac_unit_rounded},
    {'label': 'Wheelchair', 'icon': Icons.accessible_rounded},
    {'label': 'IMAX', 'icon': Icons.hd_rounded},
    {'label': 'Dolby', 'icon': Icons.surround_sound_rounded},
  ];
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_items.length, (i) {
        final sel = _selected.contains(i);
        return GestureDetector(
          onTap: () => setState(() =>
          sel ? _selected.remove(i) : _selected.add(i)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFFE53935).withOpacity(0.12)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel
                      ? const Color(0xFFE53935).withOpacity(0.6)
                      : const Color(0xFF2C2C2C)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_items[i]['icon'] as IconData,
                  color: sel ? const Color(0xFFE53935) : Colors.grey,
                  size: 14),
              const SizedBox(width: 5),
              Text(_items[i]['label'] as String,
                  style: TextStyle(
                      color: sel ? const Color(0xFFE53935) : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        );
      }),
    );
  }
}