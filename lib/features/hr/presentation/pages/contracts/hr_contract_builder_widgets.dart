import 'package:flutter/material.dart';

import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';

class ArticleCard extends StatelessWidget {
  const ArticleCard({
    required this.clause,
    required this.index,
    required this.isExpanded,
    required this.isEditing,
    required this.canManage,
    required this.isFirst,
    required this.isLast,
    required this.payrollRows,
    required this.onToggleExpand,
    required this.onStartEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.editTitleController,
    required this.editBodyController,
    required this.draftPayrollRows,
    required this.onSaveEdit,
    required this.onCancelEdit,
    required this.onOpenDrawer,
    required this.onOpenSalaryPicker,
    required this.onAddDraftPayrollRow,
    required this.onDeleteDraftPayrollRow,
    super.key,
  });

  final HrContractClause clause;
  final int index;
  final bool isExpanded;
  final bool isEditing;
  final bool canManage;
  final bool isFirst;
  final bool isLast;
  final List<HrPayrollTableRow> payrollRows;
  final VoidCallback onToggleExpand;
  final VoidCallback onStartEdit;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final TextEditingController editTitleController;
  final TextEditingController editBodyController;
  final List<HrPayrollTableRow> draftPayrollRows;
  final VoidCallback onSaveEdit;
  final VoidCallback onCancelEdit;
  final void Function(TextEditingController controller) onOpenDrawer;
  final void Function(Object rowId) onOpenSalaryPicker;
  final VoidCallback onAddDraftPayrollRow;
  final void Function(Object rowId) onDeleteDraftPayrollRow;

  @override
  Widget build(BuildContext context) {
    final hasPayroll = clause.id == 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isEditing ? AsoudColors.primary : const Color(0xFFE2E8F0),
          width: isEditing ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      toPersianDigits('${index + 1}'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      clause.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AsoudColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: isEditing
                  ? InlineArticleEditor(
                      clauseIndex: index,
                      isPayrollArticle: hasPayroll,
                      titleController: editTitleController,
                      bodyController: editBodyController,
                      draftPayrollRows: draftPayrollRows,
                      onSave: onSaveEdit,
                      onCancel: onCancelEdit,
                      onOpenDrawer: () => onOpenDrawer(editBodyController),
                      onOpenSalaryPicker: onOpenSalaryPicker,
                      onAddRow: onAddDraftPayrollRow,
                      onDeleteRow: onDeleteDraftPayrollRow,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          clause.body,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: Color(0xFF334155),
                          ),
                        ),
                        if (hasPayroll) ...[
                          const SizedBox(height: 12),
                          PayrollMiniTable(rows: payrollRows),
                        ],
                        if (canManage) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: isFirst ? null : onMoveUp,
                                icon: const Icon(Icons.arrow_upward, size: 18),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'انتقال به بالا',
                              ),
                              IconButton(
                                onPressed: isLast ? null : onMoveDown,
                                icon: const Icon(Icons.arrow_downward, size: 18),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'انتقال به پایین',
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: onStartEdit,
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('ویرایش'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class InlineArticleEditor extends StatelessWidget {
  const InlineArticleEditor({
    required this.clauseIndex,
    required this.isPayrollArticle,
    required this.titleController,
    required this.bodyController,
    required this.draftPayrollRows,
    required this.onSave,
    required this.onCancel,
    required this.onOpenDrawer,
    required this.onOpenSalaryPicker,
    required this.onAddRow,
    required this.onDeleteRow,
    super.key,
  });

  final int clauseIndex;
  final bool isPayrollArticle;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final List<HrPayrollTableRow> draftPayrollRows;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onOpenDrawer;
  final void Function(Object rowId) onOpenSalaryPicker;
  final VoidCallback onAddRow;
  final void Function(Object rowId) onDeleteRow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.edit, size: 16, color: AsoudColors.primary),
            const SizedBox(width: 6),
            Text(
              'ویرایش ماده ${toPersianDigits('${clauseIndex + 1}')}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'عنوان ماده',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: bodyController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'متن ماده',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onOpenDrawer,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('درج فیلد پرسنلی یا شرکت در متن'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AsoudColors.primary,
          ),
        ),
        if (isPayrollArticle) ...[
          const SizedBox(height: 12),
          const Divider(),
          PayrollRepeatingTableEditor(
            rows: draftPayrollRows,
            onOpenSalaryPicker: onOpenSalaryPicker,
            onAddRow: onAddRow,
            onDeleteRow: onDeleteRow,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('ذخیره تغییرات'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('انصراف'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class NewArticleForm extends StatelessWidget {
  const NewArticleForm({
    required this.titleController,
    required this.bodyController,
    required this.onSave,
    required this.onCancel,
    required this.onOpenDrawer,
    super.key,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AsoudColors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle_outline,
                  size: 18, color: AsoudColors.primary),
              SizedBox(width: 6),
              Text(
                'افزودن ماده جدید',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'عنوان ماده',
              hintText: 'مثلاً محرمانگی اطلاعات',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: bodyController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'متن ماده',
              hintText:
                  'متن ماده جدید را بنویسید یا از فیلدهای موجود استفاده کنید.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onOpenDrawer,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('درج فیلد پرسنلی یا شرکت در متن'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('افزودن ماده'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('انصراف'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PayrollMiniTable extends StatelessWidget {
  const PayrollMiniTable({required this.rows, super.key});
  final List<HrPayrollTableRow> rows;

  static const _periodLabels = {
    'monthly': 'ماهانه',
    'yearly': 'سالانه',
    'once': 'یک‌باره',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اقلام حقوق و مزایا:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    '${toPersianDigits('${i + 1}')}.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rows[i].name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _periodLabels[rows[i].period] ?? rows[i].period,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PayrollRepeatingTableEditor extends StatelessWidget {
  const PayrollRepeatingTableEditor({
    required this.rows,
    required this.onOpenSalaryPicker,
    required this.onAddRow,
    required this.onDeleteRow,
    super.key,
  });

  final List<HrPayrollTableRow> rows;
  final void Function(Object rowId) onOpenSalaryPicker;
  final VoidCallback onAddRow;
  final void Function(Object rowId) onDeleteRow;

  static const _periodLabels = {
    'monthly': 'ماهانه',
    'yearly': 'سالانه',
    'once': 'یک‌باره',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.table_chart_outlined,
                size: 18, color: AsoudColors.primary),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'جدول تکرارشونده حقوق و مزایا',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < rows.length; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ردیف ${toPersianDigits('${i + 1}')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => onDeleteRow(rows[i].id),
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'حذف',
                    ),
                  ],
                ),
                TextFormField(
                  initialValue: rows[i].name,
                  decoration: const InputDecoration(
                    labelText: 'عنوان قلم حقوق و مزایا',
                    isDense: true,
                  ),
                  onChanged: (val) {
                    rows[i] = rows[i].copyWith(name: val);
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.link, size: 14, color: AsoudColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        rows[i].fieldRef.isNotEmpty
                            ? 'فیلد: ${rows[i].fieldRef}'
                            : 'فیلد انتخاب نشده',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onOpenSalaryPicker(rows[i].id),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search,
                                size: 13, color: AsoudColors.primary),
                            SizedBox(width: 2),
                            Text('انتخاب',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AsoudColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: rows[i].period,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'دوره پرداخت',
                    isDense: true,
                  ),
                  items: _periodLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      rows[i] = rows[i].copyWith(period: v);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
        OutlinedButton.icon(
          onPressed: onAddRow,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('افزودن ردیف جدید'),
        ),
      ],
    );
  }
}

class InsertFieldDrawer extends StatefulWidget {
  const InsertFieldDrawer({
    required this.catalog,
    required this.onFieldSelected,
    this.resolveTag,
    super.key,
  });

  final Map<String, List<String>> catalog;
  final void Function(String fieldTag) onFieldSelected;
  final String Function(String group, String label)? resolveTag;

  @override
  State<InsertFieldDrawer> createState() => _InsertFieldDrawerState();
}

class _InsertFieldDrawerState extends State<InsertFieldDrawer> {
  String selectedGroup = 'personnel';
  String searchQuery = '';
  bool showAll = false;

  static const _groupLabels = {
    'personnel': 'اطلاعات پرسنل',
    'company': 'مشخصات شرکت',
    'contract': 'اطلاعات قرارداد',
    'payroll': 'حقوق و دستمزد',
  };

  @override
  Widget build(BuildContext context) {
    final fields = widget.catalog[selectedGroup] ?? const [];
    final filtered = fields
        .where((f) => f.contains(searchQuery.trim()))
        .toList();
    final displayed = showAll ? filtered : filtered.take(8).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storage_rounded,
                            size: 18, color: AsoudColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'انتخاب فیلد موجود',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedGroup,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'گروه فیلدها',
                    isDense: true,
                  ),
                  items: _groupLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        selectedGroup = v;
                        showAll = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'نام فیلد را جست‌وجو کنید...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: displayed.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final field = displayed[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add_circle_outline,
                            size: 18, color: AsoudColors.primary),
                        title: Text(field, style: const TextStyle(fontSize: 13)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('درج',
                              style: TextStyle(
                                  fontSize: 11, color: AsoudColors.primary)),
                        ),
                        onTap: () {
                          final tag = widget.resolveTag?.call(selectedGroup, field) ?? (selectedGroup == 'personnel'
                              ? '[$field پرسنل]'
                              : '[$field]');
                          widget.onFieldSelected(tag);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
                if (filtered.length > 8)
                  TextButton(
                    onPressed: () => setState(() => showAll = !showAll),
                    child: Text(showAll
                        ? 'نمایش کمتر'
                        : 'نمایش همه ${toPersianDigits('${filtered.length}')} فیلد'),
                  ),
                const SizedBox(height: 6),
                const Text(
                  'فیلد انتخابی در محل نشانگر متن قرار می‌گیرد.',
                  style: TextStyle(fontSize: 11, color: AsoudColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SalaryPickerSheet extends StatefulWidget {
  const SalaryPickerSheet({
    required this.payrollFields,
    required this.onSelected,
    super.key,
  });

  final List<HrPayrollFieldOption> payrollFields;
  final void Function(HrPayrollFieldOption field) onSelected;

  @override
  State<SalaryPickerSheet> createState() => _SalaryPickerSheetState();
}

class _SalaryPickerSheetState extends State<SalaryPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.payrollFields
        .where((f) => f.label.contains(query) || f.group.contains(query))
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SizedBox(
          height: 420,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'انتخاب فیلد حقوق و مزایا',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'جست‌وجوی فیلد (مثلاً حق مسکن)...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => query = v.trim()),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return ListTile(
                        title: Text(item.label,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(item.id,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF64748B))),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(item.group,
                              style: const TextStyle(fontSize: 11)),
                        ),
                        onTap: () {
                          widget.onSelected(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
