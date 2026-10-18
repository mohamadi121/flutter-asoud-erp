import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../form_repository.dart';
import 'form_fields_view.dart';
import 'formula_engine.dart';
import 'print_preview.dart';

class FormPreviewPage extends StatefulWidget {
  const FormPreviewPage({
    required this.schema,
    required this.repository,
    this.record = const {},
    this.initialValues = const {},
    this.onChanged,
    this.onReturnToDesigner,
    super.key,
  });

  final FormMap schema;
  final FormRepository repository;
  final FormMap record;
  final FormMap initialValues;
  final ValueChanged<FormMap>? onChanged;
  final VoidCallback? onReturnToDesigner;

  @override
  State<FormPreviewPage> createState() => _FormPreviewPageState();
}

class _FormPreviewPageState extends State<FormPreviewPage> {
  final _previewKey = GlobalKey<FormState>();
  late FormMap _values;
  String? _notice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _values = copyForm(widget.initialValues);
  }

  void _onValuesChanged(FormMap updated) {
    setState(() {
      _values = updated;
      _notice = null;
      _error = null;
    });
    widget.onChanged?.call(updated);
  }

  void _validateAndTestSubmit() {
    final problems = schemaProblems(widget.schema);
    final formValid = _previewKey.currentState?.validate() ?? true;

    final tableProblems = <String>[];
    for (final sec in formMaps(widget.schema['sections'])) {
      for (final f in formMaps(sec['fields'])) {
        if (f['type'] == 'Table') {
          final minRows = (f['min_rows'] as num?)?.toInt();
          final rows = formMaps(_values['${f['key']}']);
          if (minRows != null && rows.length < minRows) {
            tableProblems.add(
              'جدول «${f['label']}» حداقل نیازمند ${toPersianDigits(minRows)} ردیف است.',
            );
          }
        }
      }
    }

    if (problems.isNotEmpty || !formValid || tableProblems.isNotEmpty) {
      final allErrors = [
        ...problems,
        ...tableProblems,
        if (!formValid) 'لطفاً خطاهای فیلدهای فرم را برطرف کنید.',
      ];
      setState(() {
        _error = allErrors.join('\n');
        _notice = null;
      });
    } else {
      setState(() {
        _notice =
            'ساختار و مقادیر فرم با موفقیت در حالت آزمایشی اعتبارسنجی شدند. هیچ داده‌ای در سرور ثبت نگردید.';
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyName = widget.repository.company.isNotEmpty
        ? widget.repository.company
        : 'شرکت نمونه آسود';
    final title = '${widget.schema['title'] ?? widget.record['title'] ?? 'درخواست خرید کالا'}';
    final module = '${widget.schema['module'] ?? widget.record['module'] ?? ''}';
    final subtitle = module.isNotEmpty ? 'نمای آزمایشی $module' : 'نمای آزمایشی پرسنل';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFE),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AsoudColors.text,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () {
              widget.onReturnToDesigner?.call();
              Navigator.pop(context);
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'پیش‌نمایش فرم',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF122044),
                ),
              ),
              Text(
                companyName,
                style: const TextStyle(
                  fontSize: 11,
                  color: AsoudColors.muted,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'ویرایش فرم در محیط طراحی',
              color: const Color(0xFF1876D2),
              onPressed: () {
                widget.onReturnToDesigner?.call();
                Navigator.pop(context);
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
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
            if (_notice != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AsoudColors.successSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AsoudColors.success),
                ),
                child: Text(
                  _notice!,
                  style: const TextStyle(
                    color: AsoudColors.success,
                    fontSize: 13,
                  ),
                ),
              ),

            // Form Preview Card matching m-004.png
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header card with badge & icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEBF3FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.assignment_outlined,
                                  color: Color(0xFF1876D2),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF122044),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AsoudColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF3FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'پیش‌نمایش',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1876D2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Form Fields
                  Form(
                    key: _previewKey,
                    child: FormFieldsView(
                      schema: widget.schema,
                      values: _values,
                      repository: widget.repository,
                      formName: widget.record['name'] as String?,
                      onChanged: _onValuesChanged,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FormPrintPreviewPage(
                              schema: widget.schema,
                              values: _values,
                              repository: widget.repository,
                              formName: widget.record['name'] as String?,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'نمای چاپ',
                        style: TextStyle(
                          color: AsoudColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1876D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _validateAndTestSubmit,
                      icon: const Icon(
                        Icons.arrow_circle_down_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'آزمایش ثبت',
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
}
