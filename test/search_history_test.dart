import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myfit/services/search_history_store.dart';
import 'package:myfit/widgets/search_history_panel.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Only complete queries matching food results enter history', () async {
    final history = SearchHistoryStore();
    for (final query in ['gur', 'guru', 'shd']) {
      await history.addSuccessful(query, ['Guruch', 'Guruchli osh']);
    }
    await history.addSuccessful('tuxum', []);
    expect(history.items, isEmpty);
    await history.addSuccessful('guruch', ['Oq guruch']);
    await history.addSuccessful('non', ['Non']);
    await history.addSuccessful('osh', ['Osh']);
    await history.addSuccessful('rice', ['Rice, cooked']);
    await history.addSuccessful('рис', ['Белый рис']);
    final reopened = SearchHistoryStore();
    await reopened.load();
    expect(reopened.items, ['рис', 'rice', 'osh', 'non', 'guruch']);
  });

  test('Queries persist, deduplicate, and move to the top', () async {
    final history = SearchHistoryStore();
    await history.add('  tuxum  ');
    await history.add('olma');
    await history.add('TUXUM');
    final reopened = SearchHistoryStore();
    await reopened.load();
    expect(reopened.items, ['TUXUM', 'olma']);
    await reopened.remove('TUXUM');
    await history.load();
    expect(history.items, ['olma']);
    await history.clear();
    await reopened.load();
    expect(reopened.items, isEmpty);
  });

  test('Rapid operations keep order and history stays bounded', () async {
    final history = SearchHistoryStore();
    await Future.wait([
      history.add('egg'),
      history.add('apple'),
      history.remove('egg'),
    ]);
    expect(history.items, ['apple']);
    for (var i = 0; i < 35; i++) {
      await history.add('food $i');
    }
    expect(history.items.length, SearchHistoryStore.limit);
    expect(history.items.first, 'food 34');
    await history.add(' ');
    expect(history.items.length, SearchHistoryStore.limit);
  });

  testWidgets(
    'History reuses queries and supports individual and full deletion',
    (tester) async {
      final history = SearchHistoryStore();
      await history.add('tuxum');
      await history.add('olma');
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchHistoryPanel(
              store: history,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('tuxum'));
      expect(selected, 'tuxum');
      await tester.tap(find.byTooltip('Tarixdan o‘chirish').first);
      await tester.pumpAndSettle();
      expect(find.text('olma'), findsNothing);
      await tester.tap(find.text('Tozalash'));
      await tester.pumpAndSettle();
      expect(history.items, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
