import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/document_template.dart';

typedef TemplateVisual = ({IconData icon, Color color});

TemplateVisual moduleVisual(String module) => switch (module) {
      'Finance' => (
          icon: Icons.account_balance_outlined,
          color: AsoudColors.primary
        ),
      'Purchase' => (
          icon: Icons.shopping_cart_outlined,
          color: AsoudColors.danger
        ),
      'Selling' => (icon: Icons.bar_chart_rounded, color: AsoudColors.primary),
      'Stock' => (icon: Icons.inventory_2_outlined, color: AsoudColors.warning),
      'HR' => (icon: Icons.person_outline_rounded, color: AsoudColors.primary),
      'Admin' => (icon: Icons.settings_outlined, color: AsoudColors.muted),
      'IT' => (icon: Icons.computer_rounded, color: AsoudColors.primary),
      _ => (icon: Icons.apps_rounded, color: AsoudColors.muted),
    };

TemplateVisual documentTypeVisual(String type) => switch (type) {
      'Journal Entry' => (
          icon: Icons.description_outlined,
          color: AsoudColors.primary
        ),
      'Receipt' => (icon: Icons.south_rounded, color: AsoudColors.success),
      'Payment' => (icon: Icons.north_rounded, color: AsoudColors.danger),
      'Material Request' => (
          icon: Icons.inventory_outlined,
          color: AsoudColors.purple
        ),
      'Purchase Order' => (
          icon: Icons.receipt_long_outlined,
          color: AsoudColors.purple
        ),
      _ => (icon: Icons.article_outlined, color: AsoudColors.muted),
    };

TemplateVisual templateVisual(DocumentTemplate template) =>
    switch (template.icon) {
      'cart' => (icon: Icons.shopping_cart_rounded, color: AsoudColors.purple),
      'payment' => (icon: Icons.south_rounded, color: AsoudColors.success),
      'chart' => (icon: Icons.bar_chart_rounded, color: AsoudColors.primary),
      'truck' => (
          icon: Icons.local_shipping_rounded,
          color: AsoudColors.primary
        ),
      'box' => (icon: Icons.inventory_2_rounded, color: AsoudColors.warning),
      _ => template.module == 'Purchase'
          ? (icon: Icons.shopping_cart_rounded, color: AsoudColors.purple)
          : documentTypeVisual(template.documentType),
    };

IconData fieldTypeIcon(String type) => switch (type) {
      'Date' => Icons.calendar_today_outlined,
      'Currency' || 'Number' => Icons.functions_rounded,
      'Account' => Icons.person_outline_rounded,
      'Cost Center' => Icons.sell_outlined,
      'Project' => Icons.folder_outlined,
      'Warehouse' => Icons.warehouse_outlined,
      'Item Table' => Icons.list_alt_rounded,
      _ => Icons.notes_rounded,
    };

/// A small rounded label such as «سفارشی» or «آماده».
class TemplateChip extends StatelessWidget {
  const TemplateChip(this.label, {this.color = AsoudColors.success, super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      );
}

/// A tappable row that looks like a dropdown, used for pickers.
class PickerField extends StatelessWidget {
  const PickerField({
    required this.value,
    required this.onTap,
    this.label,
    this.icon,
    this.iconColor = AsoudColors.primary,
    this.placeholder = 'انتخاب کنید',
    this.trailing,
    super.key,
  });
  final String? label;
  final String value;
  final String placeholder;
  final IconData? icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (label != null) ...[
          Text(label!,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AsoudColors.border),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              if (icon != null) ...[
                AsoudPickerIcon(icon: icon!, color: iconColor),
                const SizedBox(width: 10),
              ],
              Expanded(
                  child: Text(value.isEmpty ? placeholder : value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: value.isEmpty
                              ? AsoudColors.muted
                              : AsoudColors.text))),
              trailing ??
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AsoudColors.muted),
            ]),
          ),
        ),
      ]);
}

class AsoudPickerIcon extends StatelessWidget {
  const AsoudPickerIcon(
      {required this.icon, required this.color, this.size = 32, super.key});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: size * .55, color: color),
      );
}

/// A full-page single-choice list with search, used by several pickers.
class ChoiceListPage<T> extends StatefulWidget {
  const ChoiceListPage({
    required this.title,
    required this.items,
    required this.labelOf,
    this.subtitleOf,
    this.iconOf,
    this.selected,
    this.searchHint = 'جستجو...',
    this.sectionTitle,
    this.confirmLabel = 'تأیید انتخاب',
    this.enabledOf,
    super.key,
  });
  final String title, searchHint, confirmLabel;
  final String? sectionTitle;
  final List<T> items;
  final T? selected;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final TemplateVisual Function(T)? iconOf;
  final bool Function(T)? enabledOf;

  @override
  State<ChoiceListPage<T>> createState() => _ChoiceListPageState<T>();
}

class _ChoiceListPageState<T> extends State<ChoiceListPage<T>> {
  late T? selected = widget.selected;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where((item) =>
            query.isEmpty ||
            widget.labelOf(item).toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AsoudHeader(title: widget.title),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search_rounded)),
          onChanged: (value) => setState(() => query = value.trim()),
        ),
        const SizedBox(height: 12),
        if (widget.sectionTitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(widget.sectionTitle!,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AsoudColors.muted)),
          ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('موردی یافت نشد.', textAlign: TextAlign.center),
          ),
        for (final item in items)
          Builder(builder: (context) {
            final enabled = widget.enabledOf?.call(item) ?? true;
            final visual = widget.iconOf?.call(item);
            final subtitle = widget.subtitleOf?.call(item) ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: item == selected
                  ? AsoudColors.primary.withValues(alpha: .06)
                  : null,
              child: ListTile(
                enabled: enabled,
                leading: visual == null
                    ? null
                    : AsoudPickerIcon(icon: visual.icon, color: visual.color),
                title: Text(widget.labelOf(item),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: subtitle.isEmpty
                    ? null
                    : Text(subtitle, style: const TextStyle(fontSize: 11)),
                trailing: Icon(
                    item == selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item == selected
                        ? AsoudColors.primary
                        : AsoudColors.border),
                onTap: enabled ? () => setState(() => selected = item) : null,
              ),
            );
          }),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: selected == null
                ? null
                : () => Navigator.pop(context, selected),
            child: Text(widget.confirmLabel),
          ),
        ),
      ),
    );
  }
}
