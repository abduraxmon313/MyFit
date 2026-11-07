import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/appearance_store.dart';

class AppearanceSelector extends StatefulWidget {
  const AppearanceSelector({
    super.key,
    required this.selected,
    required this.onSave,
    this.onChanged,
    this.store,
  });

  final String selected;
  final Future<void> Function(String mode) onSave;
  final ValueChanged<String>? onChanged;
  final AppearanceStore? store;

  @override
  State<AppearanceSelector> createState() => _AppearanceSelectorState();
}

class _AppearanceSelectorState extends State<AppearanceSelector> {
  bool _saving = false;
  String? _pending;
  String? _savedSelection;

  String get _selection => _pending ?? _savedSelection ?? widget.selected;

  @override
  void didUpdateWidget(covariant AppearanceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected && _pending == null) {
      _savedSelection = null;
    }
  }

  Future<void> _select(String mode) async {
    if (_saving || mode == _selection) return;
    final previous = _selection;
    setState(() {
      _saving = true;
      _pending = mode;
    });
    widget.onChanged?.call(mode);
    try {
      await (widget.store ?? AppearanceStore()).save(mode);
      _savedSelection = mode;
      // Firestore queues offline writes. A remote acknowledgement must not
      // block another local appearance change or undo a saved device choice.
      unawaited(
        Future<void>.sync(() => widget.onSave(mode)).catchError((Object _) {}),
      );
    } catch (_) {
      widget.onChanged?.call(previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Rejimni saqlab bo\u2018lmadi. Qayta urinib ko\u2018ring.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _pending = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'light',
          icon: const Icon(Icons.light_mode_outlined),
          label: Text(context.tr('Oq rejim')),
        ),
        ButtonSegment(
          value: 'dark',
          icon: const Icon(Icons.dark_mode_outlined),
          label: Text(context.tr('Qora rejim')),
        ),
      ],
      selected: {_selection},
      onSelectionChanged: _saving ? null : (values) => _select(values.single),
    );
  }
}
