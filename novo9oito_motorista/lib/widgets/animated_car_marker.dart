import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedCarMarker extends StatefulWidget {
  final double bearing;
  final Color color;
  final double size;
  final bool isMoving;

  const AnimatedCarMarker({
    super.key,
    required this.bearing,
    this.color = const Color(0xFF6A4C93),
    this.size = 40,
    this.isMoving = false,
  });

  @override
  State<AnimatedCarMarker> createState() => _AnimatedCarMarkerState();
}

class _AnimatedCarMarkerState extends State<AnimatedCarMarker>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOut,
    ));

    if (widget.isMoving) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedCarMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isMoving != oldWidget.isMoving) {
      if (widget.isMoving) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
    
    if (widget.bearing != oldWidget.bearing) {
      _rotationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isMoving ? _pulseAnimation.value : 1.0,
          child: Transform.rotate(
            angle: widget.bearing * (math.pi / 180),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: widget.size * 0.7,
                  height: widget.size * 0.7,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.navigation,
                    color: Colors.white,
                    size: widget.size * 0.4,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CarTrailPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  CarTrailPainter({
    required this.points,
    this.color = const Color(0xFF6A4C93),
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      // Criar curva suave entre pontos
      if (i < points.length - 1) {
        final current = points[i];
        final next = points[i + 1];
        final controlPoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(current.dx, current.dy, controlPoint.dx, controlPoint.dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }

    // Gradiente para o rastro
    final gradient = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.8),
          color.withOpacity(0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, gradient);
  }

  @override
  bool shouldRepaint(CarTrailPainter oldDelegate) {
    return points != oldDelegate.points ||
           color != oldDelegate.color ||
           strokeWidth != oldDelegate.strokeWidth;
  }
}

