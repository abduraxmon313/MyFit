import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/search_history_store.dart';

class SearchHistoryPanel extends StatelessWidget {
  const SearchHistoryPanel({super.key, required this.onSelected, this.store});
  final ValueChanged<String> onSelected;
  final SearchHistoryStore? store;

  @override
  Widget build(BuildContext context) {
    final history = store ?? SearchHistoryStore.shared;
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: history,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
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
                      fontSize: 18,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: history.clear,
                  child: Text(context.tr('Tozalash')),
                ),
              ],
            ),
            for (final query in history.items) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.history_rounded,
                  color: colors.onSurfaceVariant,
                ),
                title: Text(
                  query,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelected(query),
                trailing: IconButton(
                  tooltip: context.tr('Tarixdan o‘chirish'),
                  onPressed: () => history.remove(query),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Divider(color: colors.outlineVariant),
            ],
          ] else if (!history.failed) ...[
            const SizedBox(height: 40),
            Icon(Icons.search_rounded, size: 44, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              context.tr('Taom nomini yozib qidiring'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Qidiruvlaringiz shu yerda saqlanadi.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
