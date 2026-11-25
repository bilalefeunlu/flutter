/// Scan history list item card with selection, favorite, and swipe-to-delete.
///
/// Renders a compact card showing the scanned content, its type icon, the
/// scan time, and a favorite toggle button. In multi-select mode the card
/// displays an animated checkbox instead of the type icon, and swipe-to-
/// delete is disabled to prevent accidental removals.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/utils/date_formatter.dart';
import '../../core/utils/qr_parser.dart';
import '../../data/models/qr_scan_item.dart';

/// A single row in the history list.
///
/// Interaction behavior changes based on [isSelectionMode]:
/// - **Normal mode**: Tap opens the detail sheet; long-press activates
///   multi-select; swipe left to delete.
/// - **Selection mode**: Tap toggles selection; swipe-to-delete is disabled.
class HistoryItemCard extends StatelessWidget {
  final QrScanItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;

  const HistoryItemCard({
    super.key,
    required this.item,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onTap,
    required this.onLongPress,
    required this.onFavoriteToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeIcon = QrParser.getTypeIcon(item.type);
    final timeStr = DateFormatter.formatTime(item.scannedAt);

    final cardContent = Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.08)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.8 : 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          if (isSelectionMode) {
            HapticFeedback.selectionClick();
          }
          onTap();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Animated transition between type icon and selection checkbox.
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: isSelectionMode
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2638)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    typeIcon,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                secondChild: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (isDark
                              ? const Color(0xFF1E2638)
                              : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white24 : Colors.black26),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : null,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Content preview and metadata row.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.rawValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          QrParser.getTypeTitle(item.type),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Favorite toggle (hidden during multi-select).
              if (!isSelectionMode)
                IconButton(
                  onPressed: onFavoriteToggle,
                  icon: Icon(
                    item.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: item.isFavorite
                        ? Colors.amber
                        : (isDark ? Colors.white30 : Colors.black26),
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Swipe-to-delete is disabled while multi-select mode is active.
    if (isSelectionMode) {
      return cardContent;
    }

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Sil',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: cardContent,
    );
  }
}
