/// QR content detection, parsing, and URL security analysis.
///
/// Handles six content types (URL, Wi-Fi, e-mail, phone, SMS, plain text)
/// and provides a three-tier security assessment for scanned URLs:
/// **secure** (HTTPS), **warning** (HTTP / shortened link), and
/// **caution** (raw IP address).
library;

import 'package:material_ui/material_ui.dart';

import '../../data/models/qr_scan_item.dart';

// ── URL Security level ────────────────────────────────────────────────────

/// Represents the assessed security tier of a scanned URL.
enum UrlSecurityLevel { secure, warning, caution }

// ── Data models ───────────────────────────────────────────────────────────

/// Holds the result of a URL security analysis including the parsed
/// components, risk flags, and human-readable status strings.
class SafeUrlInfo {
  final String originalUrl;
  final String host;
  final String scheme;
  final String path;
  final bool isHttps;
  final bool isShortened;
  final bool isIpAddress;
  final UrlSecurityLevel securityLevel;
  final String statusTitle;
  final String statusMessage;
  final Color statusColor;
  final IconData statusIcon;

  const SafeUrlInfo({
    required this.originalUrl,
    required this.host,
    required this.scheme,
    required this.path,
    required this.isHttps,
    required this.isShortened,
    required this.isIpAddress,
    required this.securityLevel,
    required this.statusTitle,
    required this.statusMessage,
    required this.statusColor,
    required this.statusIcon,
  });
}

/// Parsed Wi-Fi network credentials extracted from a `WIFI:` QR code.
class WifiInfo {
  final String ssid;
  final String password;
  final String encryption;

  const WifiInfo({
    required this.ssid,
    required this.password,
    required this.encryption,
  });
}

// ── Parser ────────────────────────────────────────────────────────────────

/// Static utility that classifies raw QR code values, maps content types to
/// UI metadata (title / icon), parses Wi-Fi strings, and performs URL
/// security analysis.
class QrParser {
  QrParser._();

  // ── Content type detection ────────────────────────────────────────────

  /// Inspects the raw QR value and returns the matching [QrContentType].
  ///
  /// Detection order: URL → Wi-Fi → e-mail → phone → SMS → bare domain →
  /// plain text. The first match wins.
  static QrContentType detectType(String raw) {
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();

    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.')) {
      return QrContentType.url;
    }

    if (trimmed.startsWith('WIFI:')) {
      return QrContentType.wifi;
    }

    if (lower.startsWith('mailto:') ||
        RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(trimmed)) {
      return QrContentType.email;
    }

    if (lower.startsWith('tel:') ||
        RegExp(r'^\+?[0-9\s\-()]{7,}$').hasMatch(trimmed)) {
      return QrContentType.phone;
    }

    if (lower.startsWith('sms:') || lower.startsWith('smsto:')) {
      return QrContentType.sms;
    }

    // Bare domain pattern (e.g. "github.com" or "github.com/flutter").
    if (RegExp(r'^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(/.*)?$').hasMatch(trimmed)) {
      return QrContentType.url;
    }

    return QrContentType.text;
  }

  // ── UI metadata helpers ───────────────────────────────────────────────

  /// Returns a user-facing Turkish title for the given content type.
  static String getTypeTitle(QrContentType type) {
    switch (type) {
      case QrContentType.url:
        return 'Web Bağlantısı';
      case QrContentType.wifi:
        return 'Wi-Fi Ağı';
      case QrContentType.email:
        return 'E-posta Adresi';
      case QrContentType.phone:
        return 'Telefon Numarası';
      case QrContentType.sms:
        return 'SMS Mesajı';
      case QrContentType.text:
        return 'Metin / Not';
    }
  }

  /// Returns the Material icon associated with the given content type.
  static IconData getTypeIcon(QrContentType type) {
    switch (type) {
      case QrContentType.url:
        return Icons.language_rounded;
      case QrContentType.wifi:
        return Icons.wifi_rounded;
      case QrContentType.email:
        return Icons.alternate_email_rounded;
      case QrContentType.phone:
        return Icons.phone_rounded;
      case QrContentType.sms:
        return Icons.chat_bubble_outline_rounded;
      case QrContentType.text:
        return Icons.notes_rounded;
    }
  }

  // ── Wi-Fi parsing ─────────────────────────────────────────────────────

  /// Parses a `WIFI:S:<ssid>;T:<type>;P:<password>;;` string into a
  /// [WifiInfo] object. Returns `null` if the input is not a valid Wi-Fi
  /// QR string.
  static WifiInfo? parseWifi(String raw) {
    if (!raw.startsWith('WIFI:')) return null;

    String ssid = '';
    String password = '';
    String encryption = 'WPA';

    final ssidMatch = RegExp(r'S:(.*?)(?:;|$)').firstMatch(raw);
    if (ssidMatch != null) ssid = ssidMatch.group(1) ?? '';

    final passMatch = RegExp(r'P:(.*?)(?:;|$)').firstMatch(raw);
    if (passMatch != null) password = passMatch.group(1) ?? '';

    final typeMatch = RegExp(r'T:(.*?)(?:;|$)').firstMatch(raw);
    if (typeMatch != null) encryption = typeMatch.group(1) ?? 'WPA';

    return WifiInfo(ssid: ssid, password: password, encryption: encryption);
  }

  // ── URL security analysis ─────────────────────────────────────────────

  /// Well-known URL shortener domains. Shortened links mask the true
  /// destination, so they are flagged with a [UrlSecurityLevel.warning].
  static const Set<String> _knownShorteners = {
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'is.gd',
    'buff.ly',
    'ow.ly',
    'rebrand.ly',
    'cutt.ly',
    'shorturl.at',
    'bl.ink',
    'qr.me',
    'qrco.de',
    'rb.gy',
  };

  /// Analyzes the given URL for potential security concerns.
  ///
  /// The assessment checks three risk indicators in priority order:
  /// 1. **IP address** in the host → [UrlSecurityLevel.caution]
  /// 2. **Shortened link** or **HTTP** scheme → [UrlSecurityLevel.warning]
  /// 3. **HTTPS** with a standard domain → [UrlSecurityLevel.secure]
  ///
  /// If the URL lacks a scheme, `https://` is prepended by default.
  static SafeUrlInfo analyzeUrl(String raw) {
    String url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      uri = null;
    }

    final host = uri?.host.toLowerCase() ?? '';
    final scheme = uri?.scheme.toLowerCase() ?? 'https';
    final path = uri?.path.isNotEmpty == true ? uri!.path : '/';

    final isHttps = scheme == 'https';
    final isIpAddress = RegExp(r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$')
        .hasMatch(host);
    final isShortened =
        _knownShorteners.contains(host) ||
        _knownShorteners.any((s) => host.endsWith('.$s'));

    // Priority 1 – Raw IP address (highest risk).
    if (isIpAddress) {
      return SafeUrlInfo(
        originalUrl: url,
        host: host.isNotEmpty ? host : url,
        scheme: scheme,
        path: path,
        isHttps: isHttps,
        isShortened: isShortened,
        isIpAddress: true,
        securityLevel: UrlSecurityLevel.caution,
        statusTitle: 'Doğrudan IP Adresi',
        statusMessage:
            'Bu bağlantı standart bir alan adı yerine doğrudan sunucu IP adresi ($host) içeriyor. Güvenliğinden emin değilseniz dikkatli olun.',
        statusColor: const Color(0xFFEF4444),
        statusIcon: Icons.warning_rounded,
      );
    }

    // Priority 2 – Shortened URL.
    if (isShortened) {
      return SafeUrlInfo(
        originalUrl: url,
        host: host.isNotEmpty ? host : url,
        scheme: scheme,
        path: path,
        isHttps: isHttps,
        isShortened: true,
        isIpAddress: false,
        securityLevel: UrlSecurityLevel.warning,
        statusTitle: 'Kısaltılmış Bağlantı ($host)',
        statusMessage: 'Bu bağlantı bir yönlendirme servisi kullanıyor. Asıl hedef alan adı gizlenmiş olabilir.',
        statusColor: const Color(0xFFF59E0B),
        statusIcon: Icons.link_off_rounded,
      );
    }

    // Priority 3 – Plain HTTP (no TLS encryption).
    if (!isHttps) {
      return SafeUrlInfo(
        originalUrl: url,
        host: host.isNotEmpty ? host : url,
        scheme: scheme,
        path: path,
        isHttps: false,
        isShortened: false,
        isIpAddress: false,
        securityLevel: UrlSecurityLevel.warning,
        statusTitle: 'Güvensiz Bağlantı (HTTP)',
        statusMessage: 'Bu web sitesi SSL (HTTPS) şifrelemesi kullanmıyor. Bilgileriniz şifrelenmeden iletilebilir.',
        statusColor: const Color(0xFFF59E0B),
        statusIcon: Icons.lock_open_rounded,
      );
    }

    // Default – Secure HTTPS connection.
    return SafeUrlInfo(
      originalUrl: url,
      host: host.isNotEmpty ? host : url,
      scheme: scheme,
      path: path,
      isHttps: true,
      isShortened: false,
      isIpAddress: false,
      securityLevel: UrlSecurityLevel.secure,
      statusTitle: 'Güvenli Bağlantı (HTTPS)',
      statusMessage:
          'Bağlantı şifreli HTTPS protokolü ile korunmaktadır. Doğrulanmış ana alan adı: $host',
      statusColor: const Color(0xFF10B981),
      statusIcon: Icons.verified_user_rounded,
    );
  }
}
