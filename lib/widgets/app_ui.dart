import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bordered surface with a subtle hover/press state. Used for every card in
/// the product so spacing, borders and shadows stay consistent.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.lg,
    this.color,
    this.elevated = false,
    this.clip = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool elevated;
  final bool clip;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final interactive = widget.onTap != null;
    final radius = BorderRadius.circular(widget.radius);
    final active = interactive && _hovered;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.color ?? scheme.surfaceContainerLowest,
          borderRadius: radius,
          border: Border.all(
            color: active ? scheme.outline : scheme.outlineVariant,
          ),
          boxShadow: dark
              ? null
              : (active || widget.elevated)
              ? AppShadows.raised
              : AppShadows.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
          borderRadius: radius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Square icon container with a neutral or tinted background.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.color,
    this.background,
    this.iconSize,
  }) : accent = null;

  /// Soft tinted tile: light wash of [accent] behind an [accent] icon.
  const AppIconTile.tinted({
    super.key,
    required this.icon,
    required Color this.accent,
    this.size = 40,
    this.iconSize,
  }) : color = null,
       background = null;

  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;
  final Color? accent;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(
      size >= 44 ? AppRadius.md : AppRadius.sm,
    );
    final accent = this.accent;
    if (accent != null) {
      // Lighter icon on dark surfaces keeps contrast without louder colors.
      final iconColor = dark ? Color.lerp(accent, Colors.white, .35)! : accent;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: dark ? .16 : .09),
          borderRadius: radius,
          border: Border.all(color: accent.withValues(alpha: dark ? .22 : .14)),
        ),
        child: Icon(icon, size: iconSize ?? size * .46, color: iconColor),
      );
    }
    final tint = color ?? scheme.onSurface;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerLow,
        borderRadius: radius,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .7)),
      ),
      child: Icon(icon, size: iconSize ?? size * .46, color: tint),
    );
  }
}

/// Section title with optional trailing action/caption.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Small uppercase label used above metrics ("WEIGHT", "TODAY").
class AppOverline extends StatelessWidget {
  const AppOverline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: .6,
      ),
    );
  }
}
