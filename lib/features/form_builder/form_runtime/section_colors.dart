import 'package:flutter/material.dart';

class SectionColors {
  const SectionColors(this.background, this.accent);
  final Color background;
  final Color accent;
}

SectionColors? sectionColors(Map<String, dynamic> section) {
  final rawColor = _hexColor('${section['color'] ?? ''}');
  final background = _hexColor('${section['background_color'] ?? ''}');
  if (rawColor == null && background == null) return null;
  final color = rawColor ?? background!;
  final bg = background ?? (color.computeLuminance() > .6
      ? color
      : Color.lerp(color, Colors.white, .88)!);
  final accent = color.computeLuminance() > .6
      ? Color.lerp(bg, Colors.black, .65)!
      : color;
  return SectionColors(bg, accent);
}

Color? _hexColor(String value) {
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value.trim())) return null;
  return Color(int.parse('FF${value.trim().substring(1)}', radix: 16));
}
