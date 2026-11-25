/// Local persistence layer for scan history.
///
/// Uses [SharedPreferences] to store the history as a list of JSON-encoded
/// strings under a versioned key. All public methods are asynchronous and
/// safe to call from the UI thread.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/qr_scan_item.dart';

/// Repository that handles CRUD operations for [QrScanItem] records
/// stored in device-local shared preferences.
class ScanHistoryRepository {
  /// Versioned storage key. Increment the suffix when the data schema
  /// changes to avoid deserialization errors on existing installs.
  static const String _storageKey = 'qr_scanner_history_items_v1';

  /// Loads every persisted scan item and returns them in insertion order.
  /// Returns an empty list when no data exists or when deserialization fails.
  Future<List<QrScanItem>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final rawStringList = prefs.getStringList(_storageKey);

    if (rawStringList == null || rawStringList.isEmpty) {
      return [];
    }

    try {
      return rawStringList
          .map((item) => QrScanItem.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Overwrites the entire history with [items].
  Future<void> saveAll(List<QrScanItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = items.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_storageKey, stringList);
  }

  /// Adds [item] at the top of the history. If an entry with the same raw
  /// value already exists, it is removed first to prevent duplicates.
  Future<void> addItem(QrScanItem item) async {
    final current = await loadAll();
    current.removeWhere((i) => i.rawValue == item.rawValue);
    current.insert(0, item);
    await saveAll(current);
  }

  /// Deletes the single item identified by [id].
  Future<void> deleteItem(String id) async {
    final current = await loadAll();
    current.removeWhere((i) => i.id == id);
    await saveAll(current);
  }

  /// Deletes all items whose IDs are contained in [ids].
  Future<void> deleteMultiple(Set<String> ids) async {
    final current = await loadAll();
    current.removeWhere((i) => ids.contains(i.id));
    await saveAll(current);
  }

  /// Toggles the favorite flag on the item identified by [id].
  Future<void> toggleFavorite(String id) async {
    final current = await loadAll();
    final index = current.indexWhere((i) => i.id == id);
    if (index != -1) {
      final existing = current[index];
      current[index] = existing.copyWith(isFavorite: !existing.isFavorite);
      await saveAll(current);
    }
  }

  /// Removes all persisted scan history from storage.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
