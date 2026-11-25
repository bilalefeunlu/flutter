/// Business-logic layer for scan history management.
///
/// Acts as the single source of truth between the UI and the persistence
/// layer. Exposes filtered, grouped, and searchable views of the scan list,
/// and notifies listeners whenever the underlying data changes.
library;

import 'package:flutter/foundation.dart';
import '../core/utils/date_formatter.dart';
import '../core/utils/qr_parser.dart';
import '../data/models/qr_scan_item.dart';
import '../data/repositories/scan_history_repository.dart';

/// [ChangeNotifier]-based provider that manages the in-memory scan history,
/// delegates persistence to [ScanHistoryRepository], and supports search,
/// favorite filtering, and batch operations.
class ScanHistoryProvider extends ChangeNotifier {
  final ScanHistoryRepository _repository;

  ScanHistoryProvider({ScanHistoryRepository? repository})
      : _repository = repository ?? ScanHistoryRepository();

  List<QrScanItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showOnlyFavorites = false;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  bool get showOnlyFavorites => _showOnlyFavorites;

  /// Unmodifiable snapshot of the full item list (no filters applied).
  List<QrScanItem> get allItems => List.unmodifiable(_items);

  /// Items that match the current search query and favorites filter.
  /// Matching is performed case-insensitively against both the raw value
  /// and the localized content-type title.
  List<QrScanItem> get filteredItems {
    return _items.where((item) {
      if (_showOnlyFavorites && !item.isFavorite) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final content = item.rawValue.toLowerCase();
        final typeTitle = QrParser.getTypeTitle(item.type).toLowerCase();
        return content.contains(query) || typeTitle.contains(query);
      }
      return true;
    }).toList();
  }

  /// Filtered items grouped by their formatted scan date.
  /// Keys are Turkish date headers ("Bugün", "Dün", "27 Kasım", etc.).
  Map<String, List<QrScanItem>> get groupedFilteredItems {
    return DateFormatter.groupByDate(filteredItems);
  }

  int get totalCount => _items.length;
  int get favoriteCount => _items.where((i) => i.isFavorite).length;

  /// Loads persisted history from disk into memory. Should be called once
  /// during app initialization, before the first frame is rendered.
  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    _items = await _repository.loadAll();
    _isLoading = false;
    notifyListeners();
  }

  /// Monotonically increasing counter appended to microsecond timestamps
  /// to guarantee unique IDs even when multiple scans occur within the
  /// same microsecond (e.g. during unit tests).
  static int _idCounter = 0;

  /// Creates a new [QrScanItem] from [rawValue], inserts it at the top of
  /// the list, and persists the change. If the same raw value already exists,
  /// the old entry is removed to avoid duplicates.
  Future<QrScanItem> addScan(String rawValue) async {
    final trimmed = rawValue.trim();
    final type = QrParser.detectType(trimmed);
    final newItem = QrScanItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
      rawValue: trimmed,
      type: type,
      scannedAt: DateTime.now(),
      isFavorite: false,
    );

    _items.removeWhere((i) => i.rawValue == trimmed);
    _items.insert(0, newItem);
    notifyListeners();

    await _repository.addItem(newItem);
    return newItem;
  }

  /// Removes a single scan identified by [id] from both memory and storage.
  Future<void> deleteScan(String id) async {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    await _repository.deleteItem(id);
  }

  /// Removes all scans whose IDs are in [ids] in a single batch operation.
  Future<void> deleteMultipleScans(Set<String> ids) async {
    _items.removeWhere((i) => ids.contains(i.id));
    notifyListeners();
    await _repository.deleteMultiple(ids);
  }

  /// Toggles the favorite flag on the item identified by [id].
  Future<void> toggleFavorite(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final updated = _items[index].copyWith(
        isFavorite: !_items[index].isFavorite,
      );
      _items[index] = updated;
      notifyListeners();
      await _repository.toggleFavorite(id);
    }
  }

  /// Clears the entire scan history from both memory and disk.
  Future<void> clearAll() async {
    _items.clear();
    notifyListeners();
    await _repository.clearAll();
  }

  /// Updates the active search query and refreshes the filtered view.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Toggles the favorites-only filter on or off.
  void toggleFavoriteFilter() {
    _showOnlyFavorites = !_showOnlyFavorites;
    notifyListeners();
  }
}
