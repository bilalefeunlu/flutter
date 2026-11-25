/// Unit tests for core utilities, URL security analysis, batch operations,
/// and model serialization.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_code_reader/core/utils/date_formatter.dart';
import 'package:qr_code_reader/core/utils/qr_parser.dart';
import 'package:qr_code_reader/data/models/qr_scan_item.dart';
import 'package:qr_code_reader/logic/scan_history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── DateFormatter ─────────────────────────────────────────────────────

  group('DateFormatter', () {
    test('returns "Bugün" for today and "Dün" for yesterday', () {
      final now = DateTime.now();
      expect(DateFormatter.formatDateHeader(now), 'Bugün');

      final yesterday = now.subtract(const Duration(days: 1));
      expect(DateFormatter.formatDateHeader(yesterday), 'Dün');
    });

    test('formats a specific date such as 27 Kasım correctly', () {
      final now = DateTime.now();
      final nov27ThisYear = DateTime(now.year, 11, 27, 14, 30);

      final header = DateFormatter.formatDateHeader(nov27ThisYear);
      // If the date happens to be today or yesterday, relative labels apply.
      expect(
        header.contains('27 Kasım') || header == 'Bugün' || header == 'Dün',
        isTrue,
      );
    });

    test('groups items from newest to oldest date', () {
      final now = DateTime.now();
      final itemToday = QrScanItem(
        id: '1',
        rawValue: 'https://flutter.dev',
        type: QrContentType.url,
        scannedAt: now,
      );
      final itemYesterday = QrScanItem(
        id: '2',
        rawValue: 'Metin 1',
        type: QrContentType.text,
        scannedAt: now.subtract(const Duration(days: 1)),
      );
      final itemPast = QrScanItem(
        id: '3',
        rawValue: 'WIFI:S:Ev;P:12345678;;',
        type: QrContentType.wifi,
        scannedAt: now.subtract(const Duration(days: 5)),
      );

      final grouped = DateFormatter.groupByDate([itemPast, itemToday, itemYesterday]);

      expect(grouped.keys.first, 'Bugün');
      expect(grouped['Bugün']?.first.rawValue, 'https://flutter.dev');
      expect(grouped['Dün']?.first.rawValue, 'Metin 1');
      expect(grouped.length, 3);
    });
  });

  // ── QrParser – content type detection ─────────────────────────────────

  group('QrParser – content type detection', () {
    test('detects URL formats', () {
      expect(QrParser.detectType('https://google.com'), QrContentType.url);
      expect(QrParser.detectType('http://test.org/page'), QrContentType.url);
      expect(QrParser.detectType('www.apple.com'), QrContentType.url);
    });

    test('detects and parses Wi-Fi QR codes', () {
      const wifiStr = 'WIFI:S:MyHomeWifi;T:WPA;P:SuperSecret123;;';
      expect(QrParser.detectType(wifiStr), QrContentType.wifi);

      final wifiInfo = QrParser.parseWifi(wifiStr);
      expect(wifiInfo, isNotNull);
      expect(wifiInfo?.ssid, 'MyHomeWifi');
      expect(wifiInfo?.password, 'SuperSecret123');
      expect(wifiInfo?.encryption, 'WPA');
    });

    test('detects phone, e-mail, and SMS formats', () {
      expect(QrParser.detectType('tel:+905551234567'), QrContentType.phone);
      expect(QrParser.detectType('mailto:bilal@example.com'), QrContentType.email);
      expect(QrParser.detectType('bilal@example.com'), QrContentType.email);
      expect(QrParser.detectType('sms:+905551234567?body=Merhaba'), QrContentType.sms);
    });

    test('classifies plain text values as text', () {
      expect(QrParser.detectType('Sade bir not'), QrContentType.text);
      expect(QrParser.detectType('12345'), QrContentType.text);
    });
  });

  // ── QrParser – URL security analysis ──────────────────────────────────

  group('QrParser – URL security analysis (SafeUrlInfo)', () {
    test('marks HTTPS links as secure', () {
      final info = QrParser.analyzeUrl('https://flutter.dev/docs');
      expect(info.isHttps, isTrue);
      expect(info.host, 'flutter.dev');
      expect(info.securityLevel, UrlSecurityLevel.secure);
    });

    test('flags HTTP links as a warning', () {
      final info = QrParser.analyzeUrl('http://insecure-site.com');
      expect(info.isHttps, isFalse);
      expect(info.securityLevel, UrlSecurityLevel.warning);
      expect(info.statusTitle.contains('HTTP'), isTrue);
    });

    test('flags shortened URLs (bit.ly, t.co, etc.) as a warning', () {
      final info = QrParser.analyzeUrl('https://bit.ly/my-secret-link');
      expect(info.isShortened, isTrue);
      expect(info.securityLevel, UrlSecurityLevel.warning);
      expect(info.statusTitle.contains('Kısaltılmış'), isTrue);
    });

    test('flags raw IP address URLs as caution', () {
      final info = QrParser.analyzeUrl('http://192.168.1.1/admin');
      expect(info.isIpAddress, isTrue);
      expect(info.securityLevel, UrlSecurityLevel.caution);
      expect(info.statusTitle.contains('IP'), isTrue);
    });
  });

  // ── Batch delete ──────────────────────────────────────────────────────

  group('Batch delete (deleteMultipleScans)', () {
    test('removes only the selected items from the list', () async {
      final provider = ScanHistoryProvider();
      await provider.loadHistory();

      final item1 = await provider.addScan('Öğe 1');
      final item2 = await provider.addScan('Öğe 2');
      final item3 = await provider.addScan('Öğe 3');

      expect(provider.allItems.length, 3);

      await provider.deleteMultipleScans({item1.id, item2.id});

      expect(provider.allItems.length, 1);
      expect(provider.allItems.first.id, item3.id);
    });
  });

  // ── Serialization ─────────────────────────────────────────────────────

  group('QrScanItem serialization', () {
    test('round-trips through toJson / fromJson without data loss', () {
      final now = DateTime.now();
      final item = QrScanItem(
        id: '123',
        rawValue: 'https://flutter.dev',
        type: QrContentType.url,
        scannedAt: now,
        isFavorite: true,
      );

      final json = item.toJson();
      final reconstructed = QrScanItem.fromJson(json);

      expect(reconstructed.id, item.id);
      expect(reconstructed.rawValue, item.rawValue);
      expect(reconstructed.type, item.type);
      expect(reconstructed.isFavorite, item.isFavorite);
    });
  });
}
