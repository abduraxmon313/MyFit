import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 80,
  });
  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final initials = words
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    final fallback = ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: initials.isEmpty
            ? Icon(
                Icons.person_outline_rounded,
                size: size * .42,
                color: colors.onPrimaryContainer,
              )
            : Text(
                initials,
                style: TextStyle(
                  fontSize: size * .32,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimaryContainer,
                ),
              ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: photoUrl == null || photoUrl!.trim().isEmpty
            ? fallback
            : Image.network(
                photoUrl!,
                key: ValueKey(photoUrl),
                fit: BoxFit.cover,
                width: size,
                height: size,
                excludeFromSemantics: true,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
                errorBuilder: (_, error, stack) => fallback,
              ),
      ),
    );
  }
}
