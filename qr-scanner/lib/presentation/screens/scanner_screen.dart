/// Live camera QR scanner screen with gallery import support.
///
/// Displays a full-screen camera preview overlaid with a scan-window
/// viewfinder and animated laser line. Detected barcodes are processed
/// once per scan cycle; the result is presented in a modal bottom sheet.
/// Users can also pick an image from the device gallery for offline
/// barcode analysis.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../logic/scan_history_provider.dart';
import '../widgets/result_bottom_sheet.dart';
import '../widgets/scanner_overlay.dart';

/// Full-screen scanner that manages the device camera, torch, and gallery
/// picker. Scan results are saved to [historyProvider] and shown via
/// [ResultBottomSheet].
class ScannerScreen extends StatefulWidget {
  final ScanHistoryProvider historyProvider;

  const ScannerScreen({super.key, required this.historyProvider});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  final ImagePicker _imagePicker = ImagePicker();

  /// Guards against processing multiple barcodes simultaneously.
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Barcode detection callback ────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    _processScannedValue(rawValue.trim());
  }

  /// Saves the scanned value to history, presents the result sheet, and
  /// re-enables scanning after the sheet is dismissed.
  Future<void> _processScannedValue(String rawValue) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final item = await widget.historyProvider.addScan(rawValue);

    if (!mounted) return;

    await ResultBottomSheet.show(
      context,
      item: item,
      onFavoriteToggle: () {
        widget.historyProvider.toggleFavorite(item.id);
        Navigator.pop(context);
        // Re-open the sheet so the updated favorite state is visible.
        _processScannedValue(rawValue);
      },
    );

    // Brief delay before re-enabling detection prevents the same code
    // from being read again immediately after dismissal.
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  // ── Gallery import ────────────────────────────────────────────────────

  /// Opens the device gallery, analyzes the selected image for barcodes,
  /// and processes the first detected value.
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image == null) return;

      setState(() => _isProcessing = true);

      final BarcodeCapture? capture = await _controller.analyzeImage(
        image.path,
      );

      if (capture == null || capture.barcodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seçilen görselde QR kod bulunamadı.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      final rawValue = capture.barcodes.first.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        await _processScannedValue(rawValue.trim());
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görsel okunurken bir sorun oluştu: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _isProcessing = false);
    }
  }

  // ── Camera controls ───────────────────────────────────────────────────

  void _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  void _switchCamera() async {
    await _controller.switchCamera();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Live camera feed.
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Semi-transparent overlay with animated scan line.
          const ScannerOverlay(scanWindowSize: 260),

          // Top toolbar: instruction badge, torch and camera-switch buttons.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Kodu vizöre hizalayın',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _isTorchOn ? Colors.amber : Colors.white,
                        onPressed: _toggleTorch,
                      ),
                      const SizedBox(width: 8),
                      _CircleIconButton(
                        icon: Icons.flip_camera_ios_rounded,
                        color: Colors.white,
                        onPressed: _switchCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom "Scan from Gallery" button.
          PositionBar(
            onGalleryPressed: _pickImageFromGallery,
            primaryColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// Anchored bar at the bottom of the scanner that contains the gallery
/// import button.
class PositionBar extends StatelessWidget {
  final VoidCallback onGalleryPressed;
  final Color primaryColor;

  const PositionBar({
    super.key,
    required this.onGalleryPressed,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: Center(
        child: FilledButton.tonalIcon(
          onPressed: onGalleryPressed,
          icon: const Icon(Icons.photo_library_rounded, size: 20),
          label: const Text(
            'Galeriden Tara',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.65),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent circular icon button used in the scanner toolbar.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
