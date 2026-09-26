import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import 'document_template_visuals.dart';

/// Pseudo roles resolved from the request initiator by the server.
const directManagerRole = '__direct_manager__';
const initiatorRole = '__initiator__';

const _roleLabels = {
  directManagerRole: 'مدیر مستقیم',
  initiatorRole: 'درخواست‌کننده',
  'System Manager': 'مدیر سیستم',
  'Accounts Manager': 'مدیر مالی',
  'Accounts User': 'کارشناس مالی',
  'Purchase Manager': 'مدیر خرید',
  'Purchase User': 'کارشناس خرید',
  'Stock Manager': 'مدیر انبار',
  'Stock User': 'کارشناس انبار',
  'Sales Manager': 'مدیر فروش',
  'Sales User': 'کارشناس فروش',
  'HR Manager': 'مدیر منابع انسانی',
  'HR User': 'کارشناس منابع انسانی',
  'Support Team': 'کارشناس پشتیبانی',
  'Projects Manager': 'مدیر پروژه',
  'Employee': 'کارمند',
};

String roleLabel(String role) => _roleLabels[role] ?? role;

TemplateVisual roleVisual(String role) => switch (role) {
      directManagerRole => (
          icon: Icons.supervisor_account_rounded,
          color: AsoudColors.primary
        ),
      initiatorRole => (
          icon: Icons.person_pin_outlined,
          color: AsoudColors.success
        ),
      'System Manager' => (
          icon: Icons.shield_outlined,
          color: AsoudColors.primary
        ),
      final value when value.contains('Accounts') => (
          icon: Icons.account_balance_wallet_outlined,
          color: AsoudColors.success
        ),
      final value when value.contains('Purchase') => (
          icon: Icons.shopping_cart_outlined,
          color: AsoudColors.purple
        ),
      final value when value.contains('Stock') => (
          icon: Icons.inventory_2_outlined,
          color: AsoudColors.warning
        ),
      final value when value.contains('Sales') => (
          icon: Icons.storefront_outlined,
          color: AsoudColors.danger
        ),
      final value when value.startsWith('HR') => (
          icon: Icons.groups_2_outlined,
          color: AsoudColors.cyan
        ),
      _ => (icon: Icons.badge_outlined, color: AsoudColors.muted),
    };

/// «انتخاب نقش»: one role, optionally with the initiator-relative choices.
Future<String?> pickRole(BuildContext context,
        {required List<String> roles,
        String? selected,
        bool directManager = true,
        bool initiator = false}) =>
    Navigator.push<String>(
        context,
        MaterialPageRoute(
            builder: (_) => ChoiceListPage<String>(
                  title: 'انتخاب نقش',
                  searchHint: 'جستجوی نقش‌ها...',
                  items: [
                    if (directManager) directManagerRole,
                    if (initiator) initiatorRole,
                    ...roles.where((role) => role != 'Administrator'),
                  ],
                  selected: selected,
                  labelOf: roleLabel,
                  iconOf: roleVisual,
                )));

/// What the org-unit picker returned.
class OrgUnitChoice {
  const OrgUnitChoice.initiatorDepartment()
      : kind = 'initiator',
        id = '',
        label = 'واحد درخواست‌کننده';
  const OrgUnitChoice.department(this.id, this.label) : kind = 'department';
  const OrgUnitChoice.employee(this.id, this.label) : kind = 'employee';
  final String kind, id, label;

  @override
  bool operator ==(Object other) =>
      other is OrgUnitChoice && other.kind == kind && other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
}

TemplateVisual _unitVisual(int index) {
  const visuals = <TemplateVisual>[
    (icon: Icons.apartment_rounded, color: AsoudColors.primary),
    (icon: Icons.account_balance_outlined, color: AsoudColors.success),
    (icon: Icons.inventory_2_outlined, color: AsoudColors.warning),
    (icon: Icons.storefront_outlined, color: AsoudColors.purple),
    (icon: Icons.computer_rounded, color: AsoudColors.cyan),
    (icon: Icons.groups_2_outlined, color: AsoudColors.danger),
  ];
  return visuals[index % visuals.length];
}

/// «انتخاب واحد سازمانی»: walks the department tree; a unit's page offers
/// the whole unit, its sub-units and, with [members], its people.
Future<OrgUnitChoice?> pickOrgUnit(BuildContext context,
        {required List<WorkflowTargetOption> departments,
        List<WorkflowTargetOption> employees = const [],
        OrgUnitChoice? selected,
        bool initiatorDepartment = true,
        bool members = false}) =>
    Navigator.push<OrgUnitChoice>(
        context,
        MaterialPageRoute(
            builder: (_) => OrgUnitPickerPage(
                departments: departments,
                employees: employees,
                selected: selected,
                initiatorDepartment: initiatorDepartment,
                members: members)));

class OrgUnitPickerPage extends StatefulWidget {
  const OrgUnitPickerPage({
    required this.departments,
    this.employees = const [],
    this.parent,
    this.selected,
    this.initiatorDepartment = true,
    this.members = false,
    super.key,
  });
  final List<WorkflowTargetOption> departments, employees;
  final WorkflowTargetOption? parent;
  final OrgUnitChoice? selected;
  final bool initiatorDepartment, members;

  @override
  State<OrgUnitPickerPage> createState() => _OrgUnitPickerPageState();
}

class _OrgUnitPickerPageState extends State<OrgUnitPickerPage> {
  late OrgUnitChoice? selected = widget.selected;
  String query = '';

  Set<String> get _ids => {for (final unit in widget.departments) unit.id};

  /// Top level: units whose parent is missing or is a root group.
  List<WorkflowTargetOption> _children(WorkflowTargetOption? parent) {
    if (parent != null) {
      return widget.departments
          .where((unit) => unit.parent == parent.id)
          .toList();
    }
    final roots = widget.departments
        .where((unit) => unit.parent == null || !_ids.contains(unit.parent))
        .toList();
    // ERPNext keeps every department under one "All Departments" group.
    if (roots.length == 1 && roots.single.isGroup) {
      return _children(roots.single);
    }
    return roots;
  }

  bool _hasMore(WorkflowTargetOption unit) =>
      widget.departments.any((child) => child.parent == unit.id) ||
      (widget.members &&
          widget.employees.any((person) => person.department == unit.id));

  bool _matches(String label) =>
      query.isEmpty || label.toLowerCase().contains(query.toLowerCase());

  Future<void> _open(WorkflowTargetOption unit) async {
    final choice = await Navigator.push<OrgUnitChoice>(
        context,
        MaterialPageRoute(
            builder: (_) => OrgUnitPickerPage(
                departments: widget.departments,
                employees: widget.employees,
                parent: unit,
                selected: selected,
                initiatorDepartment: false,
                members: widget.members)));
    if (choice != null && mounted) Navigator.pop(context, choice);
  }

  Widget _radio(OrgUnitChoice choice,
      {TemplateVisual? visual, String? subtitle, VoidCallback? onOpen}) {
    final active = selected == choice;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: active ? AsoudColors.primary.withValues(alpha: .06) : null,
      child: ListTile(
        leading: visual == null
            ? null
            : AsoudPickerIcon(icon: visual.icon, color: visual.color),
        title: Text(choice.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              active
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: active ? AsoudColors.primary : AsoudColors.border),
          if (onOpen != null)
            IconButton(
                tooltip: 'زیرمجموعه‌ها',
                onPressed: onOpen,
                icon: const Icon(Icons.chevron_left_rounded)),
        ]),
        onTap: () => setState(() => selected = choice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    final units = _children(parent);
    final people = widget.members && parent != null
        ? widget.employees
            .where((person) => person.department == parent.id)
            .toList()
        : const <WorkflowTargetOption>[];
    return Scaffold(
      appBar: AsoudHeader(title: parent?.label ?? 'انتخاب واحد سازمانی'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          decoration: const InputDecoration(
              hintText: 'جستجو در واحدهای سازمانی...',
              prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (value) => setState(() => query = value.trim()),
        ),
        const SizedBox(height: 12),
        if (parent == null && widget.initiatorDepartment)
          _radio(const OrgUnitChoice.initiatorDepartment(),
              visual: (
                icon: Icons.person_pin_outlined,
                color: AsoudColors.success
              ),
              subtitle: 'واحدی که درخواست را ثبت کرده است'),
        if (parent != null)
          _radio(
              OrgUnitChoice.department(
                  parent.id,
                  widget.members
                      ? 'همه افراد واحد ${parent.label}'
                      : parent.label),
              visual: (icon: Icons.groups_rounded, color: AsoudColors.primary)),
        for (final (index, unit) in units.indexed)
          if (_matches(unit.label))
            _radio(OrgUnitChoice.department(unit.id, unit.label),
                visual: _unitVisual(index),
                onOpen: _hasMore(unit) ? () => _open(unit) : null),
        for (final person in people)
          if (_matches(person.label))
            _radio(OrgUnitChoice.employee(person.id, person.label),
                visual: (icon: Icons.person_rounded, color: AsoudColors.muted),
                subtitle: person.designation),
        if (units.isEmpty && people.isEmpty && parent == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('واحد سازمانی از سرور دریافت نشده است.',
                textAlign: TextAlign.center),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: selected == null
                ? null
                : () => Navigator.pop(context, selected),
            child: const Text('تأیید انتخاب'),
          ),
        ),
      ),
    );
  }
}
