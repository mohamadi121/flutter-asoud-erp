import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../workflows/domain/entities/request_models.dart';

/// The categories of the balance panel, in the mockup's order. `unpaid` is
/// never listed (CONTRACT §4.11).
const leavePanelCategories = ['annual', 'sick', 'other'];

IconData leaveCategoryIcon(String category) => switch (category) {
      'annual' => Icons.beach_access_outlined,
      'sick' => Icons.medical_services_outlined,
      _ => Icons.folder_outlined,
    };

/// «اطلاعات باقی‌مانده مرخصی»: remaining annual / sick / other days from the
/// [balance] (`get_leave_balance`). Once a preview exists, [remainingAfter]
/// shows what is left after this request on the tile of [highlightCategory].
class LeaveBalancePanel extends StatelessWidget {
  const LeaveBalancePanel({
    required this.balance,
    this.highlightCategory,
    this.remainingAfter,
    this.loading = false,
    super.key,
  });

  /// Null while loading or when the balance could not be read.
  final LeaveBalance? balance;
  final String? highlightCategory;
  final double? remainingAfter;
  final bool loading;

  static String tileLabel(LeaveBalanceCategory row) =>
      row.category == 'annual' ? 'ماندهٔ ${row.label}' : row.label;

  List<LeaveBalanceCategory> get _rows => [
        for (final key in leavePanelCategories)
          if (balance?.category(key) != null) balance!.category(key)!
      ];

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Container(
      key: const ValueKey('leave-balance-panel'),
      decoration: BoxDecoration(
        color: AsoudColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AsoudColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F7FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: const Row(children: [
            Icon(Icons.pie_chart_outline_rounded,
                size: 18, color: AsoudColors.primary),
            SizedBox(width: 8),
            Text('اطلاعات باقی‌مانده مرخصی',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: loading
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))))
              : rows.isEmpty
                  ? const Text('مانده مرخصی در دسترس نیست.',
                      style: TextStyle(fontSize: 11, color: AsoudColors.muted))
                  : Row(children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _tile(rows[i])),
                      ],
                    ]),
        ),
      ]),
    );
  }

  Widget _tile(LeaveBalanceCategory row) {
    final selected = row.category == highlightCategory;
    final color = switch (row.category) {
      'annual' => AsoudColors.success,
      'sick' => AsoudColors.primary,
      _ => AsoudColors.muted,
    };
    final after = selected ? remainingAfter : null;
    return Container(
      key: ValueKey('leave-balance-${row.category}'),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: row.category == 'annual'
            ? AsoudColors.success.withValues(alpha: .09)
            : const Color(0xFFF8FAFE),
        border: Border.all(
            color:
                selected ? color.withValues(alpha: .55) : AsoudColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(leaveCategoryIcon(row.category), size: 16, color: color),
          const SizedBox(width: 5),
          Flexible(
              child: Text(tileLabel(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color))),
        ]),
        const SizedBox(height: 6),
        Text('${formatPersianNumber(row.remainingDays)} روز',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        if (after != null) ...[
          const SizedBox(height: 3),
          Text('پس از این درخواست: ${formatPersianNumber(after)} روز',
              key: const ValueKey('leave-balance-after'),
              style: const TextStyle(
                  fontSize: 9, height: 1.4, color: AsoudColors.muted)),
        ],
      ]),
    );
  }
}

/// Read-only «مدت مرخصی» box: «۳ روز» / «۴ ساعت», a spinner while the preview
/// is being fetched, or a dash while the input is incomplete.
class LeaveDurationBadge extends StatelessWidget {
  const LeaveDurationBadge(
      {required this.duration, this.loading = false, super.key});

  final LeaveDuration? duration;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = duration?.label ?? '';
    return Container(
      key: const ValueKey('leave-duration'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        border: Border.all(color: AsoudColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.timelapse_rounded, size: 18, color: AsoudColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text.isEmpty ? '—' : text,
              key: const ValueKey('leave-duration-text'),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: text.isEmpty ? AsoudColors.muted : AsoudColors.text)),
        ),
        if (loading)
          const SizedBox.square(
              dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
    );
  }
}
