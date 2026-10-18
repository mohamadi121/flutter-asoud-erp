import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../form_repository.dart';
import '../../form_runtime/schema_migration.dart';
import 'live_clock_time_picker.dart';
import 'smart_link_picker.dart';

class FieldSheetPreview extends StatefulWidget {
  const FieldSheetPreview({
    required this.field,
    this.repository,
    super.key,
  });

  final FormMap field;
  final FormRepository? repository;

  @override
  State<FieldSheetPreview> createState() => _FieldSheetPreviewState();
}

class _FieldSheetPreviewState extends State<FieldSheetPreview> {
  dynamic currentValue;
  bool isClockOpen = false;

  @override
  void initState() {
    super.initState();
    _initValue();
  }

  void _initValue() {
    final type = '${widget.field['type']}';
    if (widget.field['default'] != null) {
      currentValue = widget.field['default'];
    } else if (type == 'Date' && widget.field['default_date_mode'] == 'today') {
      currentValue = JalaliDate.fromDateTime(DateTime.now()).format();
    } else if (type == 'Time' && widget.field['default_time_mode'] == 'now') {
      final now = DateTime.now();
      currentValue = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    } else if (type == 'Select') {
      final opts = choiceOptions(widget.field);
      currentValue = opts.isNotEmpty ? opts.first['id'] : null;
    } else if (type == 'Checkbox') {
      currentValue = <String>[];
    } else {
      currentValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final type = '${f['type']}';
    final label = '${f['label'] ?? ''}'.trim();
    final displayLabel = label.isEmpty ? 'عنوان فیلد' : label;
    final help = f['help'] as String?;
    final isRequired = f['required'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'پیش‌نمایش زنده در فرم',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1876D2),
                  ),
                ),
              ),
              const Spacer(),
              if (isRequired)
                const Text(
                  '* الزامی',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB3261E)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            displayLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF122044),
            ),
          ),
          if (help != null && help.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              help,
              style: const TextStyle(fontSize: 11, color: Color(0xFF5B6478)),
            ),
          ],
          const SizedBox(height: 12),
          _buildTypeInput(type, f),
        ],
      ),
    );
  }

  Widget _buildTypeInput(String type, FormMap f) {
    switch (type) {
      case 'Text':
        if (f['source_mode'] == 'asoud') {
          return SmartLinkPickerDropdown(
            source: '${f['source'] ?? 'Employee'}',
            selectedId: currentValue is Map ? currentValue['name'] : (currentValue as String?),
            selectedLabel: currentValue is Map ? currentValue['label'] : null,
            repository: widget.repository,
            onSelected: (item) {
              setState(() => currentValue = item);
            },
          );
        }
        return TextFormField(
          initialValue: '${currentValue ?? ''}',
          decoration: InputDecoration(
            hintText: f['help'] as String? ?? 'ورود متن...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (v) => currentValue = v,
        );

      case 'LongText':
        return TextFormField(
          initialValue: '${currentValue ?? ''}',
          maxLines: (f['lines'] as int?) ?? 3,
          decoration: InputDecoration(
            hintText: f['help'] as String? ?? 'ورود متن چندخطی...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (v) => currentValue = v,
        );

      case 'Integer':
      case 'Decimal':
      case 'Money':
        final isMoney = type == 'Money';
        return TextFormField(
          initialValue: currentValue != null ? _formatNumber(currentValue) : '',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: isMoney ? 'مثلاً ۱,۲۵۰,۰۰۰' : 'ورود عدد',
            suffixText: isMoney ? 'ریال' : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (v) {
            final latin = toLatinDigits(v.replaceAll(',', ''));
            currentValue = num.tryParse(latin);
          },
        );

      case 'Date':
        return InkWell(
          onTap: () async {
            // Pick date
            final now = DateTime.now();
            final jalali = JalaliDate.fromDateTime(now);
            setState(() {
              currentValue = jalali.format();
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F2)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Color(0xFF7C24E8)),
                const SizedBox(width: 8),
                Text(
                  currentValue != null ? toPersianDigits('$currentValue') : 'انتخاب تاریخ...',
                  style: TextStyle(
                    fontSize: 13,
                    color: currentValue != null ? const Color(0xFF122044) : const Color(0xFF5B6478),
                  ),
                ),
              ],
            ),
          ),
        );

      case 'Time':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                setState(() => isClockOpen = !isClockOpen);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F2)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF7C24E8)),
                    const SizedBox(width: 8),
                    Text(
                      currentValue != null ? toPersianDigits('$currentValue') : 'انتخاب ساعت...',
                      style: TextStyle(
                        fontSize: 13,
                        color: currentValue != null ? const Color(0xFF122044) : const Color(0xFF5B6478),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isClockOpen) ...[
              const SizedBox(height: 8),
              LiveClockTimePicker(
                initialTime: currentValue as String?,
                minuteStep: (f['minute_step'] as int?) ?? 5,
                onConfirm: (t) {
                  setState(() {
                    currentValue = t;
                    isClockOpen = false;
                  });
                },
                onCancel: () {
                  setState(() => isClockOpen = false);
                },
              ),
            ],
          ],
        );

      case 'Select':
        final opts = choiceOptions(f);
        if (opts.isEmpty) {
          return const Text('گزینه‌ای تعریف نشده است', style: TextStyle(color: Color(0xFF5B6478), fontSize: 12));
        }
        return DropdownButtonFormField<String>(
          initialValue: opts.any((o) => o['id'] == currentValue) ? currentValue as String? : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: opts
              .map((o) => DropdownMenuItem(value: '${o['id']}', child: Text('${o['label']}')))
              .toList(),
          onChanged: (v) => setState(() => currentValue = v),
        );

      case 'Checkbox':
        final opts = choiceOptions(f);
        if (opts.isEmpty) {
          return const Text('آیتمی در چک‌لیست تعریف نشده است', style: TextStyle(color: Color(0xFF5B6478), fontSize: 12));
        }
        final selectedList = (currentValue as List?) ?? [];
        return Column(
          children: opts.map((o) {
            final id = '${o['id']}';
            final isChecked = selectedList.contains(id);
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${o['label']}', style: const TextStyle(fontSize: 13)),
              value: isChecked,
              onChanged: (checked) {
                setState(() {
                  final next = List<String>.from(selectedList);
                  if (checked == true) {
                    next.add(id);
                  } else {
                    next.remove(id);
                  }
                  currentValue = next;
                });
              },
            );
          }).toList(),
        );

      case 'Formula':
        final hasFormula = f['formula'] != null && (formMap(f['formula'])['op'] != null);
        final outputType = f['output_type'] == 'Money' ? 'مبلغ' : 'عدد';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calculate_outlined, color: Color(0xFF7C24E8), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasFormula
                      ? 'خروجی: $outputType (فرمول تعریف‌شده در تب پیشرفته)'
                      : 'خروجی: $outputType · بدون فرمول',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5B6478)),
                ),
              ),
            ],
          ),
        );

      case 'Table':
        final isVertical = f['orientation'] == 'vertical';
        final cols = formMaps(f['columns']);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_chart_outlined, color: Color(0xFFE67E22), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isVertical ? 'جهت جدول: عمودی (ماتریسی)' : 'جهت جدول: افقی (افزودن ردیف)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF122044)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (cols.isEmpty)
                const Text(
                  'مشخصات جدول هنوز تعریف نشده‌اند؛ ستون‌ها در تب پیشرفته تعریف می‌شوند.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF5B6478)),
                )
              else
                Wrap(
                  spacing: 6,
                  children: cols.map((c) => Chip(
                    label: Text('${c['label']}', style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                  )).toList(),
                ),
            ],
          ),
        );

      case 'File':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F2), style: BorderStyle.solid),
          ),
          child: Column(
            children: const [
              Icon(Icons.cloud_upload_outlined, color: Color(0xFF0B6B3A), size: 30),
              SizedBox(height: 6),
              Text(
                'برای پیوست فایل ضربه بزنید یا فایل را بکشید',
                style: TextStyle(fontSize: 12, color: Color(0xFF5B6478)),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatNumber(dynamic val) {
    if (val == null) return '';
    final s = val.toString().replaceAll(',', '');
    final n = num.tryParse(s);
    if (n == null) return val.toString();
    final parts = s.split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final formatted = parts.length > 1 ? '$integerPart.${parts[1]}' : integerPart;
    return toPersianDigits(formatted);
  }
}
