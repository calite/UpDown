import 'package:flutter/material.dart';

enum GeneratedAvatarShape { circle, rounded }

class GeneratedAvatar extends StatelessWidget {
  final String seed;
  final String label;
  final double size;
  final GeneratedAvatarShape shape;

  const GeneratedAvatar.circle({
    super.key,
    required this.seed,
    required this.label,
    this.size = 40,
  }) : shape = GeneratedAvatarShape.circle;

  const GeneratedAvatar.rounded({
    super.key,
    required this.seed,
    required this.label,
    this.size = 40,
  }) : shape = GeneratedAvatarShape.rounded;

  @override
  Widget build(BuildContext context) {
    final background = _backgroundColor(seed);
    final text = _initials(label);
    final radius = shape == GeneratedAvatarShape.circle
        ? BorderRadius.circular(size)
        : BorderRadius.circular(10);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: radius),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _backgroundColor(String value) {
    final hash = value.hashCode;
    final hue = (((hash % 360) + 360) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.45).toColor();
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
