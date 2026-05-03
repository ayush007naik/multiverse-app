import 'dart:async';
import 'package:flutter/material.dart';

/// Countdown Timer Widget
/// 
/// Displays a countdown timer with circular progress indicator
/// Used for OTP cooldown periods
class OtpCooldownTimer extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onCooldownComplete;
  final TextStyle? textStyle;
  final Color? progressColor;
  final double size;

  const OtpCooldownTimer({
    super.key,
    required this.totalSeconds,
    required this.onCooldownComplete,
    this.textStyle,
    this.progressColor,
    this.size = 50.0,
  });

  @override
  State<OtpCooldownTimer> createState() => _OtpCooldownTimerState();
}

class _OtpCooldownTimerState extends State<OtpCooldownTimer>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _timer;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.totalSeconds;
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    );
    
    _startTimer();
  }

  void _startTimer() {
    _animationController.reverse(from: 1.0);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _animationController.stop();
        widget.onCooldownComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _CirclePainter(
                  progress: _remainingSeconds / widget.totalSeconds,
                  color: widget.progressColor ?? const Color(0xFFFF4D4F),
                ),
              ),
              // Timer text
              Text(
                '$_remainingSeconds',
                style: widget.textStyle ?? const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF4D4F),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Resend OTP in $_remainingSeconds seconds',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for circular progress
class _CirclePainter extends CustomPainter {
  final double progress;
  final Color color;

  _CirclePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Background circle
    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(center, radius, bgPaint);
    
    // Progress circle
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = 2 * 3.14159 * progress;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Simple text-only countdown timer
class SimpleCountdownTimer extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onCooldownComplete;
  final TextStyle? textStyle;

  const SimpleCountdownTimer({
    super.key,
    required this.totalSeconds,
    required this.onCooldownComplete,
    this.textStyle,
  });

  @override
  State<SimpleCountdownTimer> createState() => _SimpleCountdownTimerState();
}

class _SimpleCountdownTimerState extends State<SimpleCountdownTimer> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.totalSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        widget.onCooldownComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Resend available in $_remainingSeconds seconds',
      style: widget.textStyle ?? TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
      ),
    );
  }
}
