import 'package:flutter/material.dart';

class AdvancedFieldLibraryCards extends StatelessWidget {
  const AdvancedFieldLibraryCards({
    required this.selectedType,
    required this.onSelectType,
    super.key,
  });

  final String selectedType;
  final ValueChanged<String> onSelectType;

  @override
  Widget build(BuildContext context) {
    const cards = [
      _CardData(
        type: 'Formula',
        label: 'محاسباتی',
        icon: Icons.calculate_outlined,
        bgColor: Color(0xFFF2EAFE),
        iconColor: Color(0xFF8654B5),
        activeBorderColor: Color(0xFF8654B5),
      ),
      _CardData(
        type: 'Table',
        label: 'جدول تکرارشونده',
        icon: Icons.table_chart_outlined,
        bgColor: Color(0xFFFFF0DD),
        iconColor: Color(0xFFE67E22),
        activeBorderColor: Color(0xFFE67E22),
      ),
      _CardData(
        type: 'File',
        label: 'پیوست فایل',
        icon: Icons.attach_file_rounded,
        bgColor: Color(0xFFE5F7EF),
        iconColor: Color(0xFF0B6B3A),
        activeBorderColor: Color(0xFF0B6B3A),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'کتابخانه فیلدها',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF122044),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _buildCard(cards[i]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_CardData data) {
    final isSelected = selectedType == data.type;
    return InkWell(
      onTap: () => onSelectType(data.type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: data.bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? data.activeBorderColor : const Color(0xFFE2E8F2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: data.iconColor, size: 24),
            const SizedBox(height: 6),
            Text(
              data.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? data.iconColor : const Color(0xFF2D3748),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardData {
  const _CardData({
    required this.type,
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.activeBorderColor,
  });

  final String type;
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color activeBorderColor;
}
