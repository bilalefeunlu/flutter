/// Modal bottom sheet that presents the details of a scanned QR code.
///
/// Displays the content type badge, scan timestamp, selectable raw value,
/// and context-sensitive action buttons (open link, call, copy Wi-Fi
/// password, etc.). For URL-type scans, a colored security preview card
/// is shown with the assessed risk level.
///
/// Copy and Wi-Fi password operations provide inline animated feedback
/// (a green confirmation badge) instead of relying solely on SnackBars,
/// since SnackBars rendered from within a modal bottom sheet may be
/// obscured by the sheet itself on some devices.
library;

import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/date_formatter.dart';
import '../../core/utils/qr_parser.dart';
import '../../data/models/qr_scan_item.dart';

/// Stateful bottom sheet for a single [QrScanItem].
///
/// Call [ResultBottomSheet.show] to present it as a modal.
class ResultBottomSheet extends StatefulWidget {
  final QrScanItem item;
  final VoidCallback? onFavoriteToggle;

  const ResultBottomSheet({
    super.key,
    required this.item,
    this.onFavoriteToggle,
  });

  /// Convenience method that wraps [showModalBottomSheet] with the
  /// correct styling and passes [item] into the sheet widget.
  static Future<void> show(
    BuildContext context, {
    required QrScanItem item,
    VoidCallback? onFavoriteToggle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          ResultBottomSheet(item: item, onFavoriteToggle: onFavoriteToggle),
    );
  }

  @override
  State<ResultBottomSheet> createState() => _ResultBottomSheetState();
}

class _ResultBottomSheetState extends State<ResultBottomSheet> {
  bool _isCopied = false;
  bool _isWifiPassCopied = false;
  String? _errorMessage;
  Timer? _copyTimer;
  Timer? _wifiCopyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    _wifiCopyTimer?.cancel();
    super.dispose();
  }

  // ── Primary action (open / call / copy Wi-Fi password) ────────────────

  /// Executes the primary action based on the scanned content type.
  ///
  /// For URLs, a three-tier launch strategy is attempted:
  /// 1. External browser
  /// 2. In-app browser view
  /// 3. Platform default
  ///
  /// If the URL carries a warning or caution security level, a
  /// confirmation dialog is shown before proceeding.
  Future<void> _handlePrimaryAction() async {
    final raw = widget.item.rawValue;
    final type = widget.item.type;

    setState(() => _errorMessage = null);

    try {
      if (type == QrContentType.url) {
        String url = raw.trim();
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://$url';
        }

        final safeInfo = QrParser.analyzeUrl(url);

        // Prompt the user before opening potentially unsafe links.
        if (safeInfo.securityLevel == UrlSecurityLevel.caution ||
            safeInfo.securityLevel == UrlSecurityLevel.warning) {
          final shouldProceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(
                    safeInfo.statusIcon,
                    color: safeInfo.statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text('Bağlantı Uyarısı'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(safeInfo.statusMessage),
                  const SizedBox(height: 12),
                  Text(
                    'Hedef: ${safeInfo.host}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: safeInfo.statusColor,
                  ),
                  child: const Text('Yine de Aç'),
                ),
              ],
            ),
          );

          if (shouldProceed != true) return;
        }

        final uri = Uri.parse(url);
        bool launched = false;

        // Attempt 1 – External browser.
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          launched = false;
        }

        // Attempt 2 – In-app browser view.
        if (!launched) {
          try {
            launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          } catch (_) {
            launched = false;
          }
        }

        // Attempt 3 – Platform default.
        if (!launched) {
          try {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          } catch (_) {
            launched = false;
          }
        }

        if (!launched && mounted) {
          setState(() {
            _errorMessage =
                'Bağlantı tarayıcıda açılamadı. Lütfen cihazınızda bir web tarayıcısı (Chrome vb.) kurulu olduğundan emin olun veya bağlantıyı kopyalayarak tarayıcınıza yapıştırın.';
          });
        }
      } else if (type == QrContentType.phone) {
        final uri = Uri.parse(raw.startsWith('tel:') ? raw : 'tel:$raw');
        bool launched = false;
        try {
          launched = await launchUrl(uri);
        } catch (_) {
          launched = false;
        }
        if (!launched && mounted) {
          setState(() => _errorMessage = 'Arama başlatılamadı.');
        }
      } else if (type == QrContentType.email) {
        final uri = Uri.parse(raw.startsWith('mailto:') ? raw : 'mailto:$raw');
        bool launched = false;
        try {
          launched = await launchUrl(uri);
        } catch (_) {
          launched = false;
        }
        if (!launched && mounted) {
          setState(() => _errorMessage = 'E-posta uygulaması açılamadı.');
        }
      } else if (type == QrContentType.sms) {
        final uri = Uri.parse(raw);
        bool launched = false;
        try {
          launched = await launchUrl(uri);
        } catch (_) {
          launched = false;
        }
        if (!launched && mounted) {
          setState(() => _errorMessage = 'SMS uygulaması açılamadı.');
        }
      } else if (type == QrContentType.wifi) {
        final wifi = QrParser.parseWifi(raw);
        if (wifi != null && wifi.password.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: wifi.password));
          HapticFeedback.mediumImpact();
          setState(() => _isWifiPassCopied = true);
          _wifiCopyTimer?.cancel();
          _wifiCopyTimer = Timer(const Duration(milliseconds: 2500), () {
            if (mounted) setState(() => _isWifiPassCopied = false);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'İşlem başlatılırken bir hata oluştu: $e');
      }
    }
  }

  // ── Clipboard ─────────────────────────────────────────────────────────

  /// Copies the raw QR value to the system clipboard and shows both an
  /// inline confirmation badge and a floating SnackBar.
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.item.rawValue));
    HapticFeedback.mediumImpact();

    setState(() {
      _isCopied = true;
    });

    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('İçerik panoya kopyalandı'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Share ─────────────────────────────────────────────────────────────

  /// Shares the raw QR value via the platform share sheet.
  void _shareContent() {
    SharePlus.instance.share(
      ShareParams(text: widget.item.rawValue, subject: 'Taranan QR Kodu'),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeIcon = QrParser.getTypeIcon(widget.item.type);
    final typeTitle = QrParser.getTypeTitle(widget.item.type);
    final formattedDate = DateFormatter.formatDateHeader(widget.item.scannedAt);
    final formattedTime = DateFormatter.formatTime(widget.item.scannedAt);

    final SafeUrlInfo? safeUrlInfo = widget.item.type == QrContentType.url
        ? QrParser.analyzeUrl(widget.item.rawValue)
        : null;

    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141822) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle indicator.
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row: type icon badge, title, timestamp, favorite toggle.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$formattedDate • $formattedTime',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onFavoriteToggle != null)
                IconButton(
                  onPressed: widget.onFavoriteToggle,
                  icon: Icon(
                    widget.item.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: widget.item.isFavorite
                        ? Colors.amber
                        : (isDark ? Colors.white54 : Colors.black45),
                    size: 26,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // URL security preview card (only shown for URL-type scans).
          if (safeUrlInfo != null) ...[
            _buildSecurityCard(safeUrlInfo, isDark),
            const SizedBox(height: 12),
          ],

          // Selectable raw content card.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const BorderSide(color: Color(0xFF2C354D)).color
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: SelectableText(
              widget.item.rawValue,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
              ),
            ),
          ),

          // Inline copy / Wi-Fi password confirmation badge.
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: (_isCopied || _isWifiPassCopied)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 12),
            secondChild: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isWifiPassCopied
                        ? 'Wi-Fi şifresi panoya kopyalandı!'
                        : 'İçerik panoya başarıyla kopyalandı!',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Error message banner (shown when an action fails).
          if (_errorMessage != null) ...[
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Primary action button (content-type specific).
          if (widget.item.type == QrContentType.url)
            FilledButton.icon(
              onPressed: _handlePrimaryAction,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: Text(
                safeUrlInfo?.securityLevel == UrlSecurityLevel.secure
                    ? 'Güvenli Bağlantıyı Aç'
                    : 'Bağlantıyı Aç',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          else if (widget.item.type == QrContentType.wifi)
            FilledButton.icon(
              onPressed: _handlePrimaryAction,
              icon: Icon(
                _isWifiPassCopied
                    ? Icons.check_circle_rounded
                    : Icons.copy_rounded,
                color: _isWifiPassCopied ? Colors.white : null,
              ),
              label: Text(
                _isWifiPassCopied
                    ? 'Wi-Fi Şifresi Kopyalandı!'
                    : 'Wi-Fi Şifresini Kopyala',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _isWifiPassCopied ? const Color(0xFF10B981) : null,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          else if (widget.item.type == QrContentType.phone)
            FilledButton.icon(
              onPressed: _handlePrimaryAction,
              icon: const Icon(Icons.call_rounded),
              label: const Text('Telefonu Ara'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

          if (widget.item.type == QrContentType.url ||
              widget.item.type == QrContentType.wifi ||
              widget.item.type == QrContentType.phone)
            const SizedBox(height: 10),

          // Secondary action row: Copy & Share.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: Icon(
                    _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                    size: 18,
                    color: _isCopied ? const Color(0xFF10B981) : null,
                  ),
                  label: Text(
                    _isCopied ? 'Kopyalandı!' : 'Kopyala',
                    style: TextStyle(
                      fontWeight: _isCopied ? FontWeight.w700 : FontWeight.w500,
                      color: _isCopied ? const Color(0xFF10B981) : null,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isCopied
                          ? const Color(0xFF10B981)
                          : (isDark
                              ? const Color(0xFF1E2638)
                              : const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareContent,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Paylaş'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Security preview card ─────────────────────────────────────────────

  /// Builds the colored URL security assessment card displayed above
  /// the raw content.
  Widget _buildSecurityCard(SafeUrlInfo info, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: info.statusColor.withValues(
          alpha: isDark ? 0.12 : 0.08,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: info.statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(info.statusIcon, color: info.statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info.statusTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: info.statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: info.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  info.scheme.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: info.statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Hedef Alan Adı: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: Text(
                  info.host,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            info.statusMessage,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
