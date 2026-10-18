import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../form_repository.dart';
import 'form_fields_view.dart';
import 'formula_engine.dart';
import 'rules_engine.dart';

class TableRowPage extends StatefulWidget {
  const TableRowPage({
    required this.tableTitle,
    required this.columns,
    required this.row,
    required this.repository,
    this.formName,
    this.isNew = true,
    super.key,
  });

  final String tableTitle;
  final List<FormMap> columns;
  final FormMap row;
  final FormRepository repository;
  final String? formName;
  final bool isNew;

  @override
  State<TableRowPage> createState() => _TableRowPageState();
}

class _TableRowPageState extends State<TableRowPage> {
  final _formKey = GlobalKey<FormState>();
  late FormMap _values;
  String? _error;

  @override
  void initState() {
    super.initState();
    _values = copyForm(widget.row);
  }

  void _update(String key, dynamic value) {
    setState(() {
      _values[key] = value;
      _error = null;
    });
  }

  FormMap _evaluateCurrent() {
    final schema = {
      'sections': [
        {
          'id': 'table_columns',
          'title': widget.tableTitle,
          'fields': widget.columns,
        },
      ],
      'rules': <FormMap>[],
    };
    return evaluatedValues(schema, _values);
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final evaluated = _evaluateCurrent();

    for (final col in widget.columns) {
      final key = '${col['key']}';
      final isRequired = col['required'] == true;
      if (isRequired && isEmptyValue(evaluated[key])) {
        setState(() {
          _error = 'تکمیل فیلد «${col['label'] ?? key}» الزامی است.';
        });
        return;
      }
    }

    Navigator.pop(context, evaluated);
  }

  @override
  Widget build(BuildContext context) {
    final evaluated = _evaluateCurrent();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AsoudColors.text,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isNew ? 'افزودن ردیف' : 'ویرایش ردیف',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AsoudColors.text,
                ),
              ),
              Text(
                widget.tableTitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AsoudColors.muted,
                ),
              ),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AsoudColors.dangerSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AsoudColors.danger),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AsoudColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ),
              for (final col in widget.columns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildColumnInput(context, col, evaluated),
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AsoudColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AsoudColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'انصراف',
                        style: TextStyle(
                          color: AsoudColors.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1876D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _save,
                      child: const Text(
                        'ثبت ردیف',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColumnInput(
    BuildContext context,
    FormMap col,
    FormMap evaluated,
  ) {
    final key = '${col['key']}';
    final type = '${col['type']}';
    final required = col['required'] == true;
    final label = '${col['label'] ?? key}${required ? ' *' : ''}';
    final val = evaluated[key];

    if (type == 'Formula' || col['readonly'] == true) {
      final numVal = double.tryParse(toLatinDigits('$val'));
      final displayVal = numVal != null
          ? (numVal == numVal.truncateToDouble()
              ? formatNumber(numVal.toInt())
              : formatNumber(numVal))
          : formatNumber(val);
      final display = displayVal.isNotEmpty ? displayVal : '${val ?? 0}';
      final isMoney = type == 'Money' ||
          (col['formula'] is Map &&
              col['formula']['inputs'] != null &&
              (col['label']?.toString().contains('مبلغ') == true ||
                  col['label']?.toString().contains('قیمت') == true));
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF7EE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC3E6CB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calculate_outlined,
                  size: 20,
                  color: AsoudColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              isMoney ? '$display تومان' : display,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AsoudColors.success,
              ),
            ),
          ],
        ),
      );
    }

    final choice = buildChoiceInput(
      context: context,
      f: col,
      value: val,
      label: label,
      required: required,
      onChanged: (v) => _update(key, v),
    );
    if (choice != null) return choice;

    final dateTime = buildDateTimeInput(
      context: context,
      f: col,
      value: val,
      label: label,
      required: required,
      onChanged: (v) => _update(key, v),
    );
    if (dateTime != null) return dateTime;

    final link = buildLinkInput(
      context: context,
      f: col,
      computed: evaluated,
      value: val,
      label: label,
      repository: widget.repository,
      formName: widget.formName,
      onChanged: (v) => _update(key, v),
    );
    if (link != null) return link;

    final file = buildFileInput(
      context: context,
      f: col,
      value: val,
      label: label,
      repository: widget.repository,
      formName: widget.formName,
      onChanged: (v) => _update(key, v),
    );
    if (file != null) return file;

    return buildTextNumberInput(
      f: col,
      value: val,
      label: label,
      required: required,
      onChanged: (v) => _update(key, v),
    )!;
  }
}
