import 'package:flutter/material.dart';

class FieldTypeCardData {
  const FieldTypeCardData({
    required this.typeKey,
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });

  final String typeKey;
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
}

const basicFieldCards = <FieldTypeCardData>[
  // Row 1
  FieldTypeCardData(
    typeKey: 'Text',
    label: 'متن کوتاه',
    icon: Icons.title_rounded,
    bgColor: Color(0xFFE8F2FF),
    iconColor: Color(0xFF1876D2),
  ),
  FieldTypeCardData(
    typeKey: 'LongText',
    label: 'متن بلند',
    icon: Icons.segment_rounded,
    bgColor: Color(0xFFE8F2FF),
    iconColor: Color(0xFF1876D2),
  ),
  FieldTypeCardData(
    typeKey: 'Integer',
    label: 'عدد',
    icon: Icons.tag_rounded,
    bgColor: Color(0xFFE5F7EF),
    iconColor: Color(0xFF0B6B3A),
  ),
  // Row 2
  FieldTypeCardData(
    typeKey: 'Money',
    label: 'مبلغ',
    icon: Icons.payments_outlined,
    bgColor: Color(0xFFFFF0DD),
    iconColor: Color(0xFFE67E22),
  ),
  FieldTypeCardData(
    typeKey: 'Date',
    label: 'تاریخ',
    icon: Icons.calendar_today_outlined,
    bgColor: Color(0xFFF2EAFE),
    iconColor: Color(0xFF7C24E8),
  ),
  FieldTypeCardData(
    typeKey: 'Time',
    label: 'ساعت',
    icon: Icons.access_time_rounded,
    bgColor: Color(0xFFF2EAFE),
    iconColor: Color(0xFF7C24E8),
  ),
  // Row 3
  FieldTypeCardData(
    typeKey: 'Select',
    label: 'فهرست انتخابی',
    icon: Icons.checklist_rounded,
    bgColor: Color(0xFFE6F6F7),
    iconColor: Color(0xFF12B8C4),
  ),
  FieldTypeCardData(
    typeKey: 'Checkbox',
    label: 'چک‌لیست',
    icon: Icons.rule_rounded,
    bgColor: Color(0xFFE6F6F7),
    iconColor: Color(0xFF12B8C4),
  ),
  FieldTypeCardData(
    typeKey: 'Formula',
    label: 'فیلد محاسباتی',
    icon: Icons.calculate_outlined,
    bgColor: Color(0xFFF2EAFE),
    iconColor: Color(0xFF7C24E8),
  ),
  // Row 4 (Section 9 additions)
  FieldTypeCardData(
    typeKey: 'Table',
    label: 'جدول تکرارشونده',
    icon: Icons.table_chart_outlined,
    bgColor: Color(0xFFFFF0DD),
    iconColor: Color(0xFFE67E22),
  ),
  FieldTypeCardData(
    typeKey: 'File',
    label: 'پیوست فایل',
    icon: Icons.attach_file_rounded,
    bgColor: Color(0xFFE5F7EF),
    iconColor: Color(0xFF0B6B3A),
  ),
];

class FieldTypeGrid extends StatelessWidget {
  const FieldTypeGrid({
    required this.selectedType,
    required this.onSelectType,
    this.allowTable = true,
    super.key,
  });

  final String selectedType;
  final ValueChanged<String> onSelectType;
  final bool allowTable;

  @override
  Widget build(BuildContext context) {
    final cards = basicFieldCards.where((c) => allowTable || c.typeKey != 'Table').toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards.map((card) {
            final isSelected = card.typeKey == selectedType;
            return SizedBox(
              width: itemWidth,
              child: InkWell(
                onTap: () => onSelectType(card.typeKey),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 74,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? card.bgColor.withValues(alpha: 0.95) : card.bgColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? card.iconColor : Colors.transparent,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(card.icon, size: 24, color: card.iconColor),
                      const SizedBox(height: 5),
                      Text(
                        card.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? card.iconColor : const Color(0xFF122044),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
