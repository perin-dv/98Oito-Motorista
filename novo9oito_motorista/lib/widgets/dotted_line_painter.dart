import 'package:flutter/material.dart';

class DottedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DottedLinePainter({
    this.color = Colors.grey,
    this.strokeWidth = 2.0,
    this.dashWidth = 4.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double startX = 6; // Offset para alinhar com os círculos
    final double endX = startX;
    final double startY = 0;
    final double endY = size.height;

    double currentY = startY;

    while (currentY < endY) {
      canvas.drawLine(
        Offset(startX, currentY),
        Offset(endX, currentY + dashWidth),
        paint,
      );
      currentY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

