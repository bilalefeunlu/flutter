/// Data model representing a single scanned QR code entry.
///
/// Each item captures the raw barcode value, its detected content type,
/// the timestamp of the scan, and whether the user has marked it as a
/// favorite. The model supports JSON serialization for local persistence
/// via [SharedPreferences].
library;

/// Supported QR content categories used to drive type-specific UI and actions.
enum QrContentType {
  url,
  wifi,
  email,
  phone,
  sms,
  text,
}

/// Immutable value object for a scanned QR code.
///
/// Use [copyWith] to produce a modified copy (e.g. toggling the favorite
/// flag) while keeping the original instance unchanged.
class QrScanItem {
  /// Unique identifier generated from the scan timestamp and an internal
  /// counter to avoid collisions during rapid successive scans.
  final String id;

  /// The original, unprocessed value decoded from the barcode.
  final String rawValue;

  /// Detected content type (URL, Wi-Fi, e-mail, phone, SMS, or text).
  final QrContentType type;

  /// Point in time when the code was scanned.
  final DateTime scannedAt;

  /// Whether the user has starred this item in the history list.
  final bool isFavorite;

  const QrScanItem({
    required this.id,
    required this.rawValue,
    required this.type,
    required this.scannedAt,
    this.isFavorite = false,
  });

  /// Returns a shallow copy with the specified fields replaced.
  QrScanItem copyWith({
    String? id,
    String? rawValue,
    QrContentType? type,
    DateTime? scannedAt,
    bool? isFavorite,
  }) {
    return QrScanItem(
      id: id ?? this.id,
      rawValue: rawValue ?? this.rawValue,
      type: type ?? this.type,
      scannedAt: scannedAt ?? this.scannedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// Serializes the item to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawValue': rawValue,
      'type': type.name,
      'scannedAt': scannedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  /// Deserializes a [QrScanItem] from a JSON map.
  ///
  /// Falls back to [QrContentType.text] when the stored type name does not
  /// match any known enum value, ensuring forward compatibility.
  factory QrScanItem.fromJson(Map<String, dynamic> json) {
    return QrScanItem(
      id: json['id'] as String,
      rawValue: json['rawValue'] as String,
      type: QrContentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QrContentType.text,
      ),
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      isFavorite: (json['isFavorite'] as bool?) ?? false,
    );
  }
}
