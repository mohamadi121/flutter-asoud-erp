import 'package:flutter/material.dart';

import '../../form_repository.dart';

class SectionColorInfo {
  const SectionColorInfo({
    required this.name,
    required this.hex,
    required this.bg,
    required this.border,
    required this.accent,
  });

  final String name;
  final String hex;
  final Color bg;
  final Color border;
  final Color accent;
}

const sectionColorPalette = <SectionColorInfo>[
  SectionColorInfo(
    name: 'آبی ملایم',
    hex: '#EFF6FF',
    bg: Color(0xFFEFF6FF),
    border: Color(0xFFBFDBFE),
    accent: Color(0xFF1D4ED8),
  ),
  SectionColorInfo(
    name: 'سبز ملایم',
    hex: '#F0FDF4',
    bg: Color(0xFFF0FDF4),
    border: Color(0xFFBBF7D0),
    accent: Color(0xFF15803D),
  ),
  SectionColorInfo(
    name: 'بنفش ملایم',
    hex: '#FAF5FF',
    bg: Color(0xFFFAF5FF),
    border: Color(0xFFE9D5FF),
    accent: Color(0xFF7E22CE),
  ),
  SectionColorInfo(
    name: 'نارنجی ملایم',
    hex: '#FFF7ED',
    bg: Color(0xFFFFF7ED),
    border: Color(0xFFFED7AA),
    accent: Color(0xFFC2410C),
  ),
  SectionColorInfo(
    name: 'فیروزه‌ای ملایم',
    hex: '#F0FDFA',
    bg: Color(0xFFF0FDFA),
    border: Color(0xFF99F6E4),
    accent: Color(0xFF0F766E),
  ),
  SectionColorInfo(
    name: 'صورتی ملایم',
    hex: '#FDF2F8',
    bg: Color(0xFFFDF2F8),
    border: Color(0xFFFBCFE8),
    accent: Color(0xFFBE185D),
  ),
  SectionColorInfo(
    name: 'زرد ملایم',
    hex: '#FEFCE8',
    bg: Color(0xFFFEFCE8),
    border: Color(0xFFFEF08A),
    accent: Color(0xFFA16207),
  ),
  SectionColorInfo(
    name: 'نیلی ملایم',
    hex: '#EEF2FF',
    bg: Color(0xFFEEF2FF),
    border: Color(0xFFC7D2FE),
    accent: Color(0xFF4338CA),
  ),
];

String pickNextSectionColor(List<FormMap> sections) {
  final usedHexes = sections
      .map((s) => s['color']?.toString().toUpperCase())
      .whereType<String>()
      .toSet();

  for (final item in sectionColorPalette) {
    if (!usedHexes.contains(item.hex.toUpperCase())) {
      return item.hex;
    }
  }

  // If all 8 colors are used, generate a controlled distinct pastel color
  final idx = sections.length;
  final hue = (idx * 137.5) % 360;
  final color = HSLColor.fromAHSL(1.0, hue, 0.65, 0.95).toColor();
  final hex =
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  return hex;
}

SectionColorInfo resolveSectionColor(String? hex, [int fallbackIndex = 0]) {
  if (hex != null && hex.isNotEmpty) {
    final cleanHex = hex.trim().toUpperCase();
    for (final item in sectionColorPalette) {
      if (item.hex.toUpperCase() == cleanHex) {
        return item;
      }
    }
    // Parse custom hex if provided
    final numeric = cleanHex.replaceAll('#', '');
    if (numeric.length == 6) {
      final val = int.tryParse('FF$numeric', radix: 16);
      if (val != null) {
        final c = Color(val);
        return SectionColorInfo(
          name: 'سفارشی',
          hex: hex,
          bg: c,
          border: Color.lerp(c, Colors.black, 0.15) ?? const Color(0xFFCBD5E1),
          accent: Color.lerp(c, Colors.black, 0.65) ?? const Color(0xFF1E293B),
        );
      }
    }
  }

  return sectionColorPalette[fallbackIndex % sectionColorPalette.length];
}

class FieldVisual {
  const FieldVisual({
    required this.icon,
    required this.bg,
    required this.color,
  });

  final IconData icon;
  final Color bg;
  final Color color;
}

FieldVisual getFieldVisual(String? type) => switch (type) {
      'Text' => const FieldVisual(
          icon: Icons.title,
          bg: Color(0xFFEFF6FF),
          color: Color(0xFF2563EB),
        ),
      'LongText' => const FieldVisual(
          icon: Icons.notes_outlined,
          bg: Color(0xFFEFF6FF),
          color: Color(0xFF2563EB),
        ),
      'Integer' || 'Decimal' => const FieldVisual(
          icon: Icons.numbers,
          bg: Color(0xFFF0FDF4),
          color: Color(0xFF16A34A),
        ),
      'Money' => const FieldVisual(
          icon: Icons.payments_outlined,
          bg: Color(0xFFFFFBEB),
          color: Color(0xFFD97706),
        ),
      'Date' => const FieldVisual(
          icon: Icons.calendar_today_outlined,
          bg: Color(0xFFFAF5FF),
          color: Color(0xFF9333EA),
        ),
      'Time' || 'DateTime' => const FieldVisual(
          icon: Icons.access_time_outlined,
          bg: Color(0xFFFAF5FF),
          color: Color(0xFF9333EA),
        ),
      'Select' || 'MultiSelect' => const FieldVisual(
          icon: Icons.arrow_drop_down_circle_outlined,
          bg: Color(0xFFECFEFF),
          color: Color(0xFF0891B2),
        ),
      'Checkbox' || 'Boolean' => const FieldVisual(
          icon: Icons.check_box_outlined,
          bg: Color(0xFFECFDF5),
          color: Color(0xFF059669),
        ),
      'Table' => const FieldVisual(
          icon: Icons.table_chart_outlined,
          bg: Color(0xFFEEF2FF),
          color: Color(0xFF4F46E5),
        ),
      'Formula' => const FieldVisual(
          icon: Icons.calculate_outlined,
          bg: Color(0xFFFFF7ED),
          color: Color(0xFFEA580C),
        ),
      'Link' => const FieldVisual(
          icon: Icons.link_outlined,
          bg: Color(0xFFEEF2FF),
          color: Color(0xFF4F46E5),
        ),
      'File' || 'Image' || 'Signature' => const FieldVisual(
          icon: Icons.attach_file_outlined,
          bg: Color(0xFFF0FDFA),
          color: Color(0xFF0D9488),
        ),
      'Rating' => const FieldVisual(
          icon: Icons.star_outline,
          bg: Color(0xFFFEFCE8),
          color: Color(0xFFCA8A04),
        ),
      _ => const FieldVisual(
          icon: Icons.view_compact_outlined,
          bg: Color(0xFFF1F5F9),
          color: Color(0xFF475569),
        ),
    };
