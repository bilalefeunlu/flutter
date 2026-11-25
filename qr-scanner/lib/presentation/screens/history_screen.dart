/// Scan history screen with search, favorites, and batch operations.
///
/// Displays all previous scans grouped by Turkish date headers
/// ("Bugün", "Dün", "27 Kasım" etc.). Supports:
/// - **Search**: Filters items by raw content or type title.
/// - **Favorites filter**: Shows only starred items.
/// - **Multi-select mode**: Activated by long-press; allows batch deletion.
/// - **Swipe-to-delete**: Individual items can be dismissed with a swipe.
library;

import 'package:material_ui/material_ui.dart';

import '../../data/models/qr_scan_item.dart';
import '../../logic/scan_history_provider.dart';
import '../widgets/history_item_card.dart';
import '../widgets/result_bottom_sheet.dart';

/// Stateful screen that listens to [ScanHistoryProvider] and rebuilds
/// whenever the underlying scan list changes.
class HistoryScreen extends StatefulWidget {
  final ScanHistoryProvider historyProvider;

  /// Callback invoked when the user taps "Hemen Tara" in the empty state,
  /// navigating back to the scanner tab.
  final VoidCallback onGoToScan;

  const HistoryScreen({
    super.key,
    required this.historyProvider,
    required this.onGoToScan,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Selection helpers ─────────────────────────────────────────────────

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        // Automatically exit selection mode when the last item is deselected.
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<QrScanItem> visibleItems) {
    setState(() {
      if (_selectedIds.length == visibleItems.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(visibleItems.map((e) => e.id));
      }
    });
  }

  // ── Destructive action dialogs ────────────────────────────────────────

  /// Shows a confirmation dialog before deleting all selected items.
  void _confirmDeleteSelected() {
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seçilenleri Sil'),
        content: Text('Seçilen $count kaydı silmek istediğinize emin misiniz?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              widget.historyProvider.deleteMultipleScans(
                Set.from(_selectedIds),
              );
              _exitSelectionMode();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$count kayıt başarıyla silindi'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog before clearing the entire scan history.
  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geçmişi Temizle'),
        content: const Text(
          'Tüm tarama geçmişinizi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              widget.historyProvider.clearAll();
              _exitSelectionMode();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.historyProvider,
      builder: (context, child) {
        final provider = widget.historyProvider;
        final grouped = provider.groupedFilteredItems;
        final filteredList = provider.filteredItems;
        final hasAny = provider.allItems.isNotEmpty;

        return Scaffold(
          appBar: _isSelectionMode
              ? _buildSelectionAppBar(filteredList)
              : _buildDefaultAppBar(hasAny),
          body: Column(
            children: [
              // Search bar and favorites filter chip.
              _buildSearchAndFilter(provider, isDark, theme),

              // History list or appropriate empty-state illustration.
              Expanded(
                child: grouped.isEmpty
                    ? _buildEmptyState(
                        context,
                        hasAny,
                        provider.showOnlyFavorites,
                      )
                    : _buildGroupedList(grouped, filteredList, provider, isDark, theme),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── App bar variants ──────────────────────────────────────────────────

  AppBar _buildSelectionAppBar(List<QrScanItem> filteredList) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'İptal',
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        '${_selectedIds.length} seçildi',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: _selectedIds.length == filteredList.length
              ? 'Seçimi Kaldır'
              : 'Tümünü Seç',
          icon: Icon(
            _selectedIds.length == filteredList.length
                ? Icons.deselect_rounded
                : Icons.select_all_rounded,
          ),
          onPressed: () => _toggleSelectAll(filteredList),
        ),
        IconButton(
          tooltip: 'Seçilenleri Sil',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _selectedIds.isEmpty
              ? null
              : _confirmDeleteSelected,
        ),
      ],
    );
  }

  AppBar _buildDefaultAppBar(bool hasAny) {
    return AppBar(
      title: const Text('Tarama Geçmişi'),
      actions: [
        if (hasAny) ...[
          IconButton(
            tooltip: 'Çoklu Seçim',
            icon: const Icon(Icons.checklist_rounded, size: 22),
            onPressed: () {
              setState(() {
                _isSelectionMode = true;
              });
            },
          ),
          IconButton(
            tooltip: 'Tümünü Temizle',
            icon: const Icon(Icons.delete_sweep_rounded, size: 22),
            onPressed: () => _confirmClearAll(context),
          ),
        ],
      ],
    );
  }

  // ── Search bar and filter chip ────────────────────────────────────────

  Widget _buildSearchAndFilter(
    ScanHistoryProvider provider,
    bool isDark,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141822)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E2638)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: provider.setSearchQuery,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Geçmişte ara...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            selected: provider.showOnlyFavorites,
            showCheckmark: false,
            avatar: Icon(
              provider.showOnlyFavorites
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              size: 18,
              color: provider.showOnlyFavorites
                  ? Colors.amber
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
            label: Text(
              'Favoriler',
              style: TextStyle(
                fontSize: 13,
                fontWeight: provider.showOnlyFavorites
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
            onSelected: (_) => provider.toggleFavoriteFilter(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: provider.showOnlyFavorites
                    ? theme.colorScheme.primary
                    : (isDark
                          ? const Color(0xFF1E2638)
                          : const Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Grouped list ──────────────────────────────────────────────────────

  Widget _buildGroupedList(
    Map<String, List<QrScanItem>> grouped,
    List<QrScanItem> filteredList,
    ScanHistoryProvider provider,
    bool isDark,
    ThemeData theme,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24, top: 4),
      itemCount: grouped.keys.length,
      itemBuilder: (context, sectionIndex) {
        final dateHeader = grouped.keys.elementAt(sectionIndex);
        final items = grouped[dateHeader]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date section header with colored accent bar and item count.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 14,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    dateHeader,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${items.length})',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),

            // Individual scan cards for this date group.
            ...items.map(
              (item) => HistoryItemCard(
                item: item,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedIds.contains(item.id),
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleItemSelection(item.id);
                  } else {
                    _openItemDetail(context, item);
                  }
                },
                onLongPress: () {
                  if (!_isSelectionMode) {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedIds.add(item.id);
                    });
                  } else {
                    _toggleItemSelection(item.id);
                  }
                },
                onFavoriteToggle: () =>
                    provider.toggleFavorite(item.id),
                onDelete: () => provider.deleteScan(item.id),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Detail sheet ──────────────────────────────────────────────────────

  void _openItemDetail(BuildContext context, QrScanItem item) {
    ResultBottomSheet.show(
      context,
      item: item,
      onFavoriteToggle: () {
        widget.historyProvider.toggleFavorite(item.id);
        Navigator.pop(context);
      },
    );
  }

  // ── Empty states ──────────────────────────────────────────────────────

  Widget _buildEmptyState(
    BuildContext context,
    bool hasAnyItems,
    bool isFavoriteOnly,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // No scans have been recorded yet.
    if (!hasAnyItems) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz taranmış bir kod yok',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kamera veya galeriden bir QR kod tarayın',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: widget.onGoToScan,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Hemen Tara'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // The active search or favorites filter returned no results.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFavoriteOnly
                ? Icons.star_border_rounded
                : Icons.search_off_rounded,
            size: 48,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
          const SizedBox(height: 14),
          Text(
            isFavoriteOnly
                ? 'Favorilere eklenmiş bir kayıt bulunmuyor'
                : 'Aradığınız kriterlere uygun sonuç bulunamadı',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
