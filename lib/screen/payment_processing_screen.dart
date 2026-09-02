import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cinematic Payment Processing Screen
/// Shows for 5 seconds during order processing with cancel option
class PaymentProcessingScreen extends StatefulWidget {
  final double total;
  final String shopName;
  final String paymentMethod;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  const PaymentProcessingScreen({
    super.key,
    required this.total,
    required this.shopName,
    required this.paymentMethod,
    required this.onCancel,
    required this.onComplete,
  });

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  Timer? _processingTimer;

  int _elapsedSeconds = 0;
  String _currentMessage = "Processing Payment...";
  bool _isCancelled = false;

  final List<String> _processingMessages = [
    "Processing Payment...",
    "Securing Your Order...",
    "Almost Done...",
    "Finalizing Order...",
    "Confirmation Coming...",
  ];

  @override
  void initState() {
    super.initState();

    // Rotation animation for loader
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Pulse animation for glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Start processing timer
    _startProcessingTimer();
  }

  void _startProcessingTimer() {
    _processingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCancelled) {
        timer.cancel();
        return;
      }

      setState(() {
        _elapsedSeconds++;

        // Update message based on elapsed time
        if (_elapsedSeconds < _processingMessages.length) {
          _currentMessage = _processingMessages[_elapsedSeconds];
        }
      });

      // Complete after 5 seconds
      if (_elapsedSeconds >= 5) {
        timer.cancel();
        if (mounted && !_isCancelled) {
          widget.onComplete();
        }
      }
    });
  }

  void _handleCancel() async {
    if (_isCancelled) return;

    setState(() {
      _isCancelled = true;
    });

    // Cancel timers
    _processingTimer?.cancel();
    _animationController.stop();
    _pulseController.stop();

    // Show confirmation dialog
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel Order?',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this order?',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF7A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel Order',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldCancel == true && mounted) {
      widget.onCancel();
    } else {
      // Resume processing
      setState(() {
        _isCancelled = false;
      });
      _animationController.repeat();
      _pulseController.repeat(reverse: true);
      _startProcessingTimer();
    }
  }

  @override
  void dispose() {
    _processingTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  const Color(0xFFFF7A1A).withValues(alpha: 0.15),
                  const Color(0xFF0D0D0D),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Animated Loader
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _animationController.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(120, 120),
                          painter: _NeonLoaderPainter(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Processing message
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      _currentMessage,
                      key: ValueKey(_currentMessage),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Shop name
                  Text(
                    widget.shopName,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Amount
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFFF7A1A).withValues(
                              alpha: 0.3 + (_pulseController.value * 0.4),
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF7A1A,
                              ).withValues(alpha: 0.2 * _pulseController.value),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Text(
                          '₹${widget.total.toStringAsFixed(0)}',
                          style: GoogleFonts.orbitron(
                            color: const Color(0xFFFF7A1A),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Progress indicator
                  _buildProgressDots(),

                  const SizedBox(height: 16),

                  // Estimated time
                  Text(
                    'Estimated: ${5 - _elapsedSeconds}s',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(),

                  // Cancel button (COD only)
                  if (widget.paymentMethod.toUpperCase() == 'COD')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: GestureDetector(
                        onTap: _handleCancel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            color: Colors.red.withValues(alpha: 0.1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.close_rounded,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cancel Order',
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final isActive = index < _elapsedSeconds;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFF7A1A)
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF7A1A).withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

/// Custom painter for neon loader
class _NeonLoaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Outer glow
    final paintGlow = Paint()
      ..color = const Color(0xFFFF7A1A).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paintGlow);

    // Main arc
    final paintMain = Paint()
      ..color = const Color(0xFFFF7A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.5 * math.pi,
      false,
      paintMain,
    );

    // Inner arc (opposite direction)
    final paintInner = Paint()
      ..color = const Color(0xFF9C27B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 15),
      math.pi,
      1.2 * math.pi,
      false,
      paintInner,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
