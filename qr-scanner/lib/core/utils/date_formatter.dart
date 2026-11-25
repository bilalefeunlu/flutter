/// Date formatting and grouping utilities for scan history.
///
/// All user-facing date strings are localized in Turkish. Dates are presented
/// as relative labels ("Bugün", "Dün") when applicable, and as absolute
/// Turkish-formatted strings ("27 Kasım", "27 Kasım 2025") otherwise.
library;

import 'package:intl/intl.dart';
import '../../data/models/qr_scan_item.dart';

/// Provides static helpers that format [DateTime] values and group
/// [QrScanItem] lists by their scan date.
class DateFormatter {
  DateFormatter._();

  /// Month names in Turkish. Index 0 is unused so that `date.month` can
  /// be used directly as the list index (Dart months are 1-based).
  static const List<String> _turkishMonths = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  /// Converts [date] into a human-friendly section header.
  ///
  /// Returns:
  /// - `"Bugün"` if the date is today.
  /// - `"Dün"` if the date is yesterday.
  /// - `"27 Kasım"` if the date is in the current year.
  /// - `"27 Kasım 2025"` if the date belongs to a different year.
  static String formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);

    final differenceInDays = today.difference(itemDate).inDays;

    if (differenceInDays == 0) return 'Bugün';
    if (differenceInDays == 1) return 'Dün';

    final day = date.day;
    final monthName = _turkishMonths[date.month];

    if (date.year == now.year) {
      return '$day $monthName';
    } else {
      return '$day $monthName ${date.year}';
    }
  }

  /// Formats the time portion of [date] in 24-hour notation (e.g. `"14:30"`).
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Groups [items] by their scan date and returns a linked map whose keys
  /// are formatted date headers and whose values are the items scanned on
  /// that date. The map is ordered from the most recent date to the oldest.
  static Map<String, List<QrScanItem>> groupByDate(List<QrScanItem> items) {
    final sorted = List<QrScanItem>.from(items)
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    final Map<String, List<QrScanItem>> grouped = {};

    for (final item in sorted) {
      final header = formatDateHeader(item.scannedAt);
      grouped.putIfAbsent(header, () => []).add(item);
    }

    return grouped;
  }
}
