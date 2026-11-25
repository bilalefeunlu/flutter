/// Custom-painted scanner viewfinder overlay with animated scan line.
///
/// Draws a dimmed background with a rounded-rectangle cutout (the scan
/// window), four colored corner accents, and a gradient laser line that
/// sweeps up and down continuously to indicate active scanning.
library;

import 'package:material_ui/material_ui.dart';

/// Widget that covers the entire screen with the scan-window overlay.
/// The [scanWindowSize] parameter controls the side length of the
/// square cutout in logical pixels.
class ScannerOverlay extends StatefulWidget {
  final double scanWindowSize;

  const ScannerOverlay({super.key, this.scanWindowSize = 260.0});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ScannerOverlayPainter(
            scanWindowSize: widget.scanWindowSize,
            scanLineProgress: _animation.value,
            primaryColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}

/// [CustomPainter] responsible for rendering the overlay, border, corner
/// accents, and animated scan line in a single paint pass.
class _ScannerOverlayPainter extends CustomPainter {
  final double scanWindowSize;
  final double scanLineProgress;
  final Color primaryColor;

  _ScannerOverlayPainter({
    required this.scanWindowSize,
    required this.scanLineProgress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double left = (size.width - scanWindowSize) / 2;
    final double top = (size.height - scanWindowSize) / 2.3;
    final Rect scanRect = Rect.fromLTWH(
      left,
      top,
      scanWindowSize,
      scanWindowSize,
    );
    final RRect scanRRect = RRect.fromRectAndRadius(
      scanRect,
      const Radius.circular(20),
    );

    // 1. Dimmed background with the scan window cut out.
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path cutoutPath = Path()..addRRect(scanRRect);
    final Path finalPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.58)
      ..style = PaintingStyle.fill;
    canvas.drawPath(finalPath, backgroundPaint);

    // 2. Subtle border around the scan window.
    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(scanRRect, borderPaint);

    // 3. Rounded corner accents drawn with the theme primary color.
    final Paint cornerPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 28.0;
    const double radius = 20.0;

    // Top-left corner.
    final Path topLeft = Path()
      ..moveTo(scanRect.left, scanRect.top + cornerLength)
      ..lineTo(scanRect.left, scanRect.top + radius)
      ..quadraticBezierTo(
        scanRect.left,
        scanRect.top,
        scanRect.left + radius,
        scanRect.top,
      )
      ..lineTo(scanRect.left + cornerLength, scanRect.top);
    canvas.drawPath(topLeft, cornerPaint);

    // Top-right corner.
    final Path topRight = Path()
      ..moveTo(scanRect.right - cornerLength, scanRect.top)
      ..lineTo(scanRect.right - radius, scanRect.top)
      ..quadraticBezierTo(
        scanRect.right,
        scanRect.top,
        scanRect.right,
        scanRect.top + radius,
      )
      ..lineTo(scanRect.right, scanRect.top + cornerLength);
    canvas.drawPath(topRight, cornerPaint);

    // Bottom-left corner.
    final Path bottomLeft = Path()
      ..moveTo(scanRect.left, scanRect.bottom - cornerLength)
      ..lineTo(scanRect.left, scanRect.bottom - radius)
      ..quadraticBezierTo(
        scanRect.left,
        scanRect.bottom,
        scanRect.left + radius,
        scanRect.bottom,
      )
      ..lineTo(scanRect.left + cornerLength, scanRect.bottom);
    canvas.drawPath(bottomLeft, cornerPaint);

    // Bottom-right corner.
    final Path bottomRight = Path()
      ..moveTo(scanRect.right - cornerLength, scanRect.bottom)
      ..lineTo(scanRect.right - radius, scanRect.bottom)
      ..quadraticBezierTo(
        scanRect.right,
        scanRect.bottom,
        scanRect.right,
        scanRect.bottom - radius,
      )
      ..lineTo(scanRect.right, scanRect.bottom - cornerLength);
    canvas.drawPath(bottomRight, cornerPaint);

    // 4. Animated gradient scan line sweeping vertically through the window.
    final double scanLineY =
        scanRect.top + (scanRect.height * scanLineProgress);
    final Rect lineRect = Rect.fromLTWH(
      scanRect.left + 10,
      scanLineY - 1.5,
      scanRect.width - 20,
      3,
    );

    final Paint linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.0),
          primaryColor,
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(lineRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(lineRect, const Radius.circular(2)),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanLineProgress != scanLineProgress ||
        oldDelegate.scanWindowSize != scanWindowSize ||
        oldDelegate.primaryColor != primaryColor;
  }
}
