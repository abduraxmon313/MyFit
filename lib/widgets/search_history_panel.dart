import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/search_history_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchHistoryPanel extends StatelessWidget {
  const SearchHistoryPanel({
    super.key,
    required this.onSelected,
    this.store,
    this.header,
  });
  final ValueChanged<String> onSelected;
  final SearchHistoryStore? store;

  /// Tarixdan oldin ko'rsatiladigan qism (masalan, kategoriyalar).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final history = store ?? SearchHistoryStore.shared;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? colors.outlineVariant : const Color(0xFFE4E9EE);
    return AnimatedBuilder(
      animation: history,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 22)],
          if (history.failed)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.tr('Qidiruv tarixini saqlash yoki yuklashda xatolik.'),
                style: TextStyle(color: colors.error),
              ),
            ),
          if (history.items.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Oxirgi qidiruvlar'),
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -.2,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: history.clear,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(context.tr('Tozalash')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < history.items.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 62, color: border),
                    _HistoryRow(
                      query: history.items[i],
                      onTap: () => onSelected(history.items[i]),
                      onRemove: () => history.remove(history.items[i]),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (!history.failed) ...[
            const SizedBox(height: 28),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.search,
                  size: 34,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('Taom nomini yozib qidiring'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('Qidiruvlaringiz shu yerda saqlanadi.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: dark
                    ? colors.surfaceContainerHigh
                    : const Color(0xFFF1F4F8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.history,
                size: 19,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              tooltip: context.tr('Tarixdan o‘chirish'),
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                LucideIcons.x,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
