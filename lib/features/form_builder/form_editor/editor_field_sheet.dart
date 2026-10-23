import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/utils/jalali_date.dart';
import '../../../core/widgets/asoud_jalali_picker.dart';
import '../form_repository.dart';
import '../form_runtime.dart';
import 'editor_field_types/choice_options.dart';
import 'editor_field_types/date_time.dart';
import 'editor_field_types/derived_fields.dart';
import 'editor_field_types/file.dart';
import 'editor_field_types/formula.dart';
import 'editor_field_types/link.dart';
import 'editor_field_types/table.dart';
import 'editor_field_types/text_number.dart';
import 'editor_widgets.dart';
import 'field_sheet/field_sheet_preview.dart';
import 'field_sheet/field_type_grid.dart';
import 'field_sheet/live_clock_time_picker.dart';
import 'field_sheet/sheet_bottom_buttons.dart';
import 'field_sheet/smart_link_picker.dart';
import 'field_sheet/advanced/column_type_cards.dart';

export 'field_sheet/field_sheet_preview.dart';
export 'field_sheet/field_type_grid.dart';
export 'field_sheet/live_clock_time_picker.dart';
export 'field_sheet/sheet_bottom_buttons.dart';
export 'field_sheet/smart_link_picker.dart';

Future<FormMap?> editSchemaField(
  BuildContext context,
  FormMap schema,
  FormMap original, {
  bool column = false,
  String? parentNative,
  FormRepository? repository,
}) async {
  final f = copyForm(original);
  final isEditing = original['label'] != null && '${original['label']}'.trim().isNotEmpty;

  // Initialize defaults if empty
  f.putIfAbsent('key', () => 'f_${newFormId()}');
  f.putIfAbsent('type', () => 'Text');
  f.putIfAbsent('source_mode', () => 'manual');
  f.putIfAbsent('orientation', () => 'horizontal');

  return showModalBottomSheet<FormMap>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFF8FAFD),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) {
        return _FieldSheetModal(
          schema: schema,
          initialField: f,
          isEditing: isEditing,
          column: column,
          parentNative: parentNative,
          repository: repository,
        );
      },
    ),
  );
}

class _FieldSheetModal extends StatefulWidget {
  const _FieldSheetModal({
    required this.schema,
    required this.initialField,
    required this.isEditing,
    required this.column,
    this.parentNative,
    this.repository,
  });

  final FormMap schema;
  final FormMap initialField;
  final bool isEditing;
  final bool column;
  final String? parentNative;
  final FormRepository? repository;

  @override
  State<_FieldSheetModal> createState() => _FieldSheetModalState();
}

class _FieldSheetModalState extends State<_FieldSheetModal> {
  late FormMap f;
  late int selectedTab; // 0: پایه, 1: پیشرفته
  bool isPreview = false;
  String? labelError;
  bool isClockPickerOpen = false;

  @override
  void initState() {
    super.initState();
    f = copyForm(widget.initialField);
    selectedTab = 0;
  }

  void set(String key, dynamic value) {
    setState(() {
      f[key] = value;
      if (key == 'label' && value != null && '$value'.trim().isNotEmpty) {
        labelError = null;
      }
    });
  }

  Future<void> _selectType(String type) async {
    if (type == f['type']) return;
    final hasDependencies = f['has_data'] == true ||
        f['dependencies'] is List && (f['dependencies'] as List).isNotEmpty ||
        f['formula_dependents'] is List &&
            (f['formula_dependents'] as List).isNotEmpty;
    if (widget.isEditing && hasDependencies) {
      final confirmed = await formConfirm(
        context,
        'با تغییر نوع، تنظیمات ناسازگار این مشخصه حذف می‌شوند. ادامه می‌دهید؟',
      );
      if (!confirmed || !mounted) return;
    }
    const typeSpecificKeys = {
      'source', 'source_mode', 'max_length', 'min_length', 'lines', 'format',
      'error_message', 'min', 'max', 'precision', 'thousands_separator',
      'digits', 'default_date_mode', 'default_time_mode', 'minute_step',
      'min_date', 'max_date', 'min_time', 'max_time', 'options', 'formula',
      'output_type', 'extensions', 'max_files', 'max_mb', 'allow_delete',
      'readonly', 'default', 'default_source', 'exclude_self', 'fetch_from',
      'not_equal', 'not_equal_message', 'compare', 'next_day_allowed',
    };
    setState(() {
      for (final key in typeSpecificKeys) {
        f.remove(key);
      }
      f['type'] = type;
      f['source_mode'] = 'manual';
      if (type == 'Formula') f['output_type'] = 'Integer';
      if (type == 'Table') f['orientation'] = 'horizontal';
    });
  }

  bool _hasUnsavedChanges() {
    return jsonEncode(f) != jsonEncode(widget.initialField);
  }

  Future<void> _handleCancel() async {
    if (_hasUnsavedChanges()) {
      final discard = await formConfirm(
        context,
        'تغییرات ذخیره‌نشده رها شوند؟',
      );
      if (!discard || !mounted) return;
    }
    Navigator.pop(context);
  }

  void _handleSave() {
    final label = '${f['label'] ?? ''}'.trim();
    if (label.isEmpty) {
      setState(() => labelError = 'عنوان فیلد الزامی است');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عنوان فیلد را وارد کنید.')),
      );
      return;
    }
    if (widget.column) {
      final duplicate = schemaFields(widget.schema).any((field) =>
          field['key'] != f['key'] &&
          '${field['label']}'.trim().toLowerCase() == label.toLowerCase());
      if (duplicate) {
        setState(() => labelError = 'عنوان مشخصه در این جدول تکراری است');
        return;
      }
    }
    final min = f['min'] as num?, max = f['max'] as num?;
    if (min != null && max != null && min > max) {
      setState(() => labelError = 'حداقل نمی‌تواند از حداکثر بیشتر باشد');
      return;
    }
    if (['Select', 'Checkbox'].contains(f['type'])) {
      final options = choiceOptions(f);
      if (options.isEmpty) {
        setState(() => labelError = 'حداقل یک گزینه معتبر وارد کنید');
        return;
      }
      if (f['type'] == 'Checkbox') {
        final minSelected = f['min_selected'] as num? ?? 0;
        final maxSelected = f['max_selected'] as num?;
        if (maxSelected != null && minSelected > maxSelected) {
          setState(() => labelError = 'حداقل انتخاب نمی‌تواند از حداکثر بیشتر باشد');
          return;
        }
      }
    }

    Navigator.pop(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final type = '${f['type']}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              const Divider(height: 1, color: Color(0xFFE2E8F2)),
              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: isPreview
                      ? FieldSheetPreview(field: f, repository: widget.repository)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // دو تب نهایی فرمساز
                            _buildTabs(),
                            const SizedBox(height: 14),
                            if (selectedTab == 0) ...[
                              // Library of 9 cards + 2 cards
                              _buildFieldLibrary(),
                              const SizedBox(height: 16),
                              // Field Settings Card
                              _buildFieldSettingsCard(type),
                            ] else if (selectedTab == 1) ...[
                              _buildAdvancedTabContent(),
                            ],
                          ],
                        ),
                ),
              ),
              // Bottom Buttons
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F2))),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SheetBottomButtons(
                  isEditing: widget.isEditing,
                  isPreviewing: isPreview,
                  isColumn: widget.column,
                  onPrimary: _handleSave,
                  onPreviewToggle: () {
                    setState(() => isPreview = !isPreview);
                  },
                  onCancel: _handleCancel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleCancel,
            icon: const Icon(Icons.close, color: Color(0xFF5B6478)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.column
                      ? (widget.isEditing ? 'ویرایش ستون' : 'افزودن ستون')
                      : (widget.isEditing ? 'ویرایش فیلد' : 'افزودن فیلد'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF122044),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'ASOUD ERP · فرم‌ساز',
                  style: TextStyle(fontSize: 10, color: Color(0xFF5B6478)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_outlined, color: Color(0xFF1876D2)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['پایه', 'پیشرفته'];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => selectedTab = i),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedTab == i ? const Color(0xFF1876D2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selectedTab == i ? FontWeight.bold : FontWeight.normal,
                      color: selectedTab == i ? Colors.white : const Color(0xFF5B6478),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldLibrary() {
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF122044)),
          ),
          const SizedBox(height: 10),
          if (widget.column)
            ColumnTypeCards(
              selectedType: '${f['type']}',
              onSelectType: _selectType,
            )
          else
            FieldTypeGrid(
              selectedType: '${f['type']}',
              onSelectType: _selectType,
            ),
        ],
      ),
    );
  }

  Widget _buildFieldSettingsCard(String type) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  color: const Color(0xFF7C24E8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تنظیمات ${_getTypeLabel(type)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF122044),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Common Field: Title
          TextFormField(
            key: ValueKey('label_${f['key']}'),
            initialValue: '${f['label'] ?? ''}',
            decoration: InputDecoration(
              labelText: 'عنوان فیلد *',
              hintText: 'مثلاً مبلغ نهایی یا نام کارمند',
              errorText: labelError,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (v) => set('label', v),
          ),
          const SizedBox(height: 12),
          // Common Field: Help Text
          TextFormField(
            key: ValueKey('help_${f['key']}'),
            initialValue: '${f['help'] ?? ''}',
            decoration: InputDecoration(
              labelText: 'توضیحات / راهنمای فیلد',
              hintText: 'اختیاری',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (v) => set('help', v),
          ),
          const SizedBox(height: 8),
          // Common Field: Required toggle (except Table/File which have custom wording)
          if (type != 'Table' && type != 'File')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('پاسخ به این فیلد الزامی باشد', style: TextStyle(fontSize: 13)),
              value: f['required'] == true,
              onChanged: (v) => set('required', v),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('این مشخصه در فرم نمایش داده شود', style: TextStyle(fontSize: 13)),
            value: f['visible'] != false,
            onChanged: (v) => set('visible', v),
          ),
          if (!widget.column) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'چیدمان فیلد',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(
                      value: 1,
                      label: Text('نیم‌عرض', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment<int>(
                      value: 2,
                      label: Text('تمام‌عرض', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {(f['span'] as num?)?.toInt() == 1 ? 1 : 2},
                  onSelectionChanged: (Set<int> newSelection) {
                    set('span', newSelection.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 18, color: Color(0xFFE2E8F2)),
          // Specific Settings by Type
          _buildSpecificTypeSettings(type),
        ],
      ),
    ),
    );
  }

  Widget _buildSpecificTypeSettings(String type) {
    switch (type) {
      case 'Text':
        return _buildTextSettings();
      case 'LongText':
        return _buildLongTextSettings();
      case 'Integer':
      case 'Decimal':
      case 'Money':
        return _buildNumberSettings(type);
      case 'Date':
        return _buildDateSettings();
      case 'Time':
        return _buildTimeSettings();
      case 'Select':
        return _buildSelectSettings(multi: false);
      case 'Checkbox':
        return _buildSelectSettings(multi: true);
      case 'Formula':
        return _buildFormulaBasicSettings();
      case 'Table':
        return _buildTableBasicSettings();
      case 'File':
        return _buildFileBasicSettings();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextSettings() {
    final mode = f['source_mode'] ?? 'manual';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'روش تأمین مقدار فیلد',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF122044)),
        ),
        RadioGroup<String>(
          groupValue: mode,
          onChanged: (v) {
            if (v == null) return;
            set('source_mode', v);
            if (v == 'asoud') {
              f.putIfAbsent('source', () => 'Employee');
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('ورود دستی', style: TextStyle(fontSize: 13)),
                value: 'manual',
              ),
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('انتخاب از سیستم آسود', style: TextStyle(fontSize: 13)),
                value: 'asoud',
              ),
            ],
          ),
        ),
        if (mode == 'asoud') ...[
          const SizedBox(height: 6),
          formSelect(
            'منبع اطلاعات آسود',
            '${f['source'] ?? 'Employee'}',
            const {
              'Employee': 'پرسنل',
              'Department': 'سمت سازمانی / واحد',
              'Item': 'کالا',
              'Warehouse': 'انبار',
              'Account': 'حساب',
            },
            (v) {
              set('source', v);
              set('default', null);
            },
          ),
          const SizedBox(height: 8),
          SmartLinkPickerDropdown(
            source: '${f['source'] ?? 'Employee'}',
            selectedId: f['default'] is Map ? f['default']['name'] : (f['default'] as String?),
            selectedLabel: f['default'] is Map ? f['default']['label'] : null,
            repository: widget.repository,
            onSelected: (item) {
              set('default', item);
            },
          ),
        ] else ...[
          const SizedBox(height: 6),
          editorFieldText(
            label: 'حداکثر کاراکتر',
            value: f['max_length'],
            numeric: true,
            onChanged: (v) => set('max_length', v),
          ),
          editorFieldText(
            label: 'متن پیش‌فرض',
            value: f['default'],
            onChanged: (v) => set('default', v),
          ),
        ],
      ],
    );
  }

  Widget _buildLongTextSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        editorFieldText(
          label: 'حداکثر کاراکتر',
          value: f['max_length'],
          numeric: true,
          onChanged: (v) => set('max_length', v),
        ),
        editorFieldText(
          label: 'تعداد سطر اولیه',
          value: f['lines'] ?? 3,
          numeric: true,
          onChanged: (v) => set('lines', v),
        ),
        editorFieldText(
          label: 'متن پیش‌فرض',
          value: f['default'],
          lines: 2,
          onChanged: (v) => set('default', v),
        ),
      ],
    );
  }

  Widget _buildNumberSettings(String type) {
    final isMoney = type == 'Money';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: editorFieldText(
                label: 'حداقل ${isMoney ? 'مبلغ' : 'مقدار'}',
                value: f['min'],
                numeric: true,
                onChanged: (v) => set('min', v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: editorFieldText(
                label: 'حداکثر ${isMoney ? 'مبلغ' : 'مقدار'}',
                value: f['max'],
                numeric: true,
                onChanged: (v) => set('max', v),
              ),
            ),
          ],
        ),
        if (type != 'Integer')
          editorFieldText(
            label: 'تعداد اعشار مجاز (۰ تا ۴)',
            value: f['precision'] ?? 2,
            numeric: true,
            onChanged: (v) => set('precision', v),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('نمایش جداکننده سه‌رقمی', style: TextStyle(fontSize: 13)),
          value: f['thousands_separator'] != false,
          onChanged: (v) => set('thousands_separator', v),
        ),
        editorFieldText(
          label: 'مقدار پیش‌فرض',
          value: f['default'],
          numeric: true,
          onChanged: (v) => set('default', v),
        ),
      ],
    );
  }

  Widget _buildDateSettings() {
    final mode = f['default_date_mode'] ?? 'none';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        formSelect(
          'نوع تقویم',
          '${f['calendar'] ?? 'jalali'}',
          const {'jalali': 'شمسی', 'gregorian': 'میلادی'},
          (v) => set('calendar', v),
        ),
        const Text(
          'مقدار پیش‌فرض تاریخ',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF122044)),
        ),
        RadioGroup<String>(
          groupValue: mode,
          onChanged: (v) {
            if (v != null) set('default_date_mode', v);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('بدون مقدار اولیه', style: TextStyle(fontSize: 13)),
                value: 'none',
              ),
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('تاریخ روز (هنگام اجرای واقعی فرم)', style: TextStyle(fontSize: 13)),
                value: 'today',
              ),
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('تاریخ مشخص', style: TextStyle(fontSize: 13)),
                value: 'custom',
              ),
            ],
          ),
        ),
        if (mode == 'custom') ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('انتخاب تاریخ مشخص', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              f['default'] != null ? toPersianDigits('${f['default']}') : 'لمس کنید',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1876D2)),
            ),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final picked = await showAsoudJalaliPicker(context);
              if (picked != null) {
                final j = JalaliDate.fromDateTime(picked);
                set('default', j.format());
              }
            },
          ),
        ],
        formSelect(
          'نباید قبل از فیلد:',
          '${f['after_or_equal'] ?? ''}',
          {
            '': 'بدون محدودیت',
            for (final field in formMaps(widget.schema['sections'])
                .expand((section) => formMaps(section['fields']))
                .where((field) => field['type'] == 'Date' && field['key'] != f['key']))
              '${field['key']}': '${field['label']}',
          },
          (v) => set('after_or_equal', v.isEmpty ? null : v),
        ),
        ...buildDateTimeConfig(
          context: context,
          f: f,
          set: set,
          update: (fn) => setState(fn),
        ),
      ],
    );
  }

  Widget _buildTimeSettings() {
    final mode = f['default_time_mode'] ?? 'none';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        formSelect(
          'فاصله دقیقه',
          '${f['minute_step'] ?? 5}',
          const {'5': '۵ دقیقه', '10': '۱۰ دقیقه', '15': '۱۵ دقیقه', '30': '۳۰ دقیقه'},
          (v) => set('minute_step', int.tryParse(v) ?? 5),
        ),
        const Text(
          'مقدار پیش‌فرض ساعت',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF122044)),
        ),
        RadioGroup<String>(
          groupValue: mode,
          onChanged: (v) {
            if (v != null) set('default_time_mode', v);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('خالی', style: TextStyle(fontSize: 13)),
                value: 'none',
              ),
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('ساعت جاری', style: TextStyle(fontSize: 13)),
                value: 'now',
              ),
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('ساعت مشخص', style: TextStyle(fontSize: 13)),
                value: 'custom',
              ),
            ],
          ),
        ),
        if (mode == 'custom') ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تنظیم ساعت مشخص', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              f['default'] != null ? toPersianDigits('${f['default']}') : 'لمس جهت تنظیم',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1876D2)),
            ),
            trailing: const Icon(Icons.access_time, size: 18),
            onTap: () {
              setState(() => isClockPickerOpen = !isClockPickerOpen);
            },
          ),
          if (isClockPickerOpen) ...[
            LiveClockTimePicker(
              initialTime: f['default'] as String?,
              minuteStep: (f['minute_step'] as int?) ?? 5,
              onConfirm: (t) {
                set('default', t);
                setState(() => isClockPickerOpen = false);
              },
              onCancel: () {
                setState(() => isClockPickerOpen = false);
              },
            ),
          ],
        ],
        Row(
          children: [
            Expanded(child: editorFieldText(label: 'حداقل ساعت', value: f['min_time'], onChanged: (v) => set('min_time', v))),
            const SizedBox(width: 8),
            Expanded(child: editorFieldText(label: 'حداکثر ساعت', value: f['max_time'], onChanged: (v) => set('max_time', v))),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectSettings({required bool multi}) {
    final opts = choiceOptions(f);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceOptionsListEditor(
          field: f,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (!multi) ...[
          const Text('نمایش', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'dropdown', label: Text('لیست کشویی')),
              ButtonSegment(value: 'radio', label: Text('دکمه رادیویی')),
            ],
            selected: {'${f['style'] ?? 'dropdown'}'},
            onSelectionChanged: (value) => set('style', value.first),
          ),
          const SizedBox(height: 8),
        ],
        if (multi) ...[
          editorFieldText(label: 'حداقل تعداد انتخاب', value: f['min_selected'] ?? 0, numeric: true, onChanged: (v) => set('min_selected', v)),
          editorFieldText(label: 'حداکثر تعداد انتخاب', value: f['max_selected'], numeric: true, onChanged: (v) => set('max_selected', v)),
        ] else if (opts.isNotEmpty)
          formSelect(
            'گزینه پیش‌فرض',
            f['default'] as String?,
            {'': 'بدون پیش‌فرض', for (final option in opts) '${option['id']}': '${option['label']}'},
            (v) => set('default', v.isEmpty ? null : v),
          ),
      ],
    );
  }

  Widget _buildFormulaBasicSettings() {
    final outType = f['output_type'] ?? 'Integer';
    final hasFormula = f['formula'] != null && (formMap(f['formula'])['op'] != null);
    final existingFormulaFields = schemaFields(widget.schema)
        .where((field) => field['type'] == 'Formula')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        formSelect(
          'نوع خروجی',
          outType,
          const {
            'Integer': 'عدد',
            'Money': 'مبلغ',
          },
          (v) => set('output_type', v),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            final sections = formMaps(widget.schema['sections']);
            if (sections.isNotEmpty) {
              final targetSec = sections.first;
              final fields = formMaps(targetSec['fields']);
              final newKey = 'f_${newFormId()}';
              final sampleField = {
                'key': newKey,
                'type': 'Formula',
                'label': (f['label']?.toString().trim().isNotEmpty == true)
                    ? f['label']
                    : 'فیلد محاسباتی نمونه',
                'output_type': outType,
              };
              fields.add(sampleField);
              targetSec['fields'] = fields;
              setState(() {});
            }
          },
          icon: const Icon(Icons.add, size: 18, color: Color(0xFF1876D2)),
          label: const Text(
            '+ ایجاد فیلد در فرم نمونه',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1876D2),
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFBCD8FF)),
            backgroundColor: const Color(0xFFF8FAFD),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        if (existingFormulaFields.isNotEmpty) ...[
          const Text(
            'فیلدهای محاسباتی در این فرم:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B6478)),
          ),
          const SizedBox(height: 6),
          for (final ff in existingFormulaFields)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2EAFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calculate_outlined, color: Color(0xFF7C24E8), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ff['label'] ?? ff['key']}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF122044)),
                        ),
                        Text(
                          'خروجی ${ff['output_type'] == 'Money' ? 'مبلغ' : 'عدد'} · ${ff['formula'] != null ? 'فرمول تعریف‌شده' : 'بدون فرمول'}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF5B6478)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF0B6B3A),
                    size: 20,
                  ),
                ],
              ),
            ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F2)),
            ),
            child: Row(
              children: [
                Icon(
                  hasFormula ? Icons.check_circle : Icons.info_outline,
                  color: hasFormula ? const Color(0xFF0B6B3A) : const Color(0xFF7C24E8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasFormula
                        ? 'وضعیت: فرمول تعریف‌شده در تب پیشرفته'
                        : 'وضعیت: بدون فرمول (تنظیم در تب پیشرفته)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5B6478)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTableBasicSettings() {
    final orient = f['orientation'] ?? 'horizontal';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'جهت جدول',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF122044)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => set('orientation', 'horizontal'),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: orient == 'horizontal' ? const Color(0xFFFFF0DD) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: orient == 'horizontal' ? const Color(0xFFE67E22) : const Color(0xFFE2E8F2),
                    ),
                  ),
                  child: const Text('افقی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => set('orientation', 'vertical'),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: orient == 'vertical' ? const Color(0xFFFFF0DD) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: orient == 'vertical' ? const Color(0xFFE67E22) : const Color(0xFFE2E8F2),
                    ),
                  ),
                  child: const Text('عمودی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            orient == 'horizontal'
                ? 'طراح ستون‌ها را تعریف می‌کند و کاربر ردیف می‌افزاید'
                : 'طراح مشخصات ثابت را تعریف می‌کند و کاربر ستون می‌افزاید',
            style: const TextStyle(fontSize: 11, color: Color(0xFF5B6478)),
          ),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ثبت حداقل یک رکورد الزامی باشد', style: TextStyle(fontSize: 13)),
          value: f['required'] == true,
          onChanged: (v) => set('required', v),
        ),
      ],
    );
  }

  Widget _buildFileBasicSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('پیوست‌کردن حداقل یک فایل الزامی باشد', style: TextStyle(fontSize: 13)),
          value: f['required'] == true,
          onChanged: (v) => set('required', v),
        ),
      ],
    );
  }

  Widget _buildAdvancedTabContent() {
    final fieldOptions = {
      for (final field in schemaFields(widget.schema).where((v) => v['key'] != f['key']))
        '${field['key']}': '${field['label']}',
    };

    if (f['type'] == 'Formula') {
      return buildFormulaAdvancedTab(
        f: f,
        schema: widget.schema,
        fieldOptions: fieldOptions,
        set: set,
        onSelectType: (t) => set('type', t),
      );
    }

    if (f['type'] == 'Table') {
      return buildTableAdvancedTab(
        context: context,
        f: f,
        schema: widget.schema,
        set: set,
        onEditColumn: editSchemaField,
        onSelectType: _selectType,
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F2)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('شناسه پایدار: ${f['key']}', style: const TextStyle(fontSize: 11, color: Color(0xFF5B6478))),
          const SizedBox(height: 12),
          formSelect(
            'منبع مقدار پیش‌فرض',
            '${f['default_source'] ?? ''}',
            {
              '': 'مقدار ثابت یا خالی',
              if (f['type'] == 'Date') 'today': 'تاریخ امروز',
              if (f['type'] == 'Date') 'contract_start': 'شروع قرارداد جاری (در نبود قرارداد: شروع به کار)',
              if (['Text', 'Display'].contains(f['type'])) ...{
                'user': 'کاربر ثبت‌کننده',
                'company': 'دفتر جاری',
              },
              if (f['type'] == 'Link' && f['source'] == 'Employee')
                'employee': 'پرسنل مرتبط با کاربر',
              if (f['type'] == 'Link' && f['source'] == 'Department')
                'department': 'واحد پرسنل ثبت‌کننده',
              if (f['type'] == 'Text') 'employee_number': 'کد پرسنلی',
              if (f['type'] == 'Link' && f['source'] == 'Shift Type')
                'default_shift': 'شیفت پیش‌فرض',
            },
            (v) => set('default_source', v),
          ),
          ...buildLinkAdvancedConfig(
            f: f,
            fieldOptions: fieldOptions,
            set: set,
            update: (fn) => setState(fn),
          ),
          ...buildFetchFromConfig(
            f: f,
            fields: schemaFields(widget.schema),
            set: set,
            update: (fn) => setState(fn),
          ),
          ...buildNotEqualConfig(
            f: f,
            fields: schemaFields(widget.schema),
            set: set,
          ),
          ...buildCompareConfig(
            f: f,
            fields: schemaFields(widget.schema),
            set: set,
          ),
          if (f['type'] == 'Time')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('امکان انتخاب روز بعد', style: TextStyle(fontSize: 13)),
              value: f['next_day_allowed'] == true,
              onChanged: (v) => set('next_day_allowed', v ? true : null),
            ),
          if (widget.column) uniqueColumnSwitch(f, set),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('فقط‌خواندنی', style: TextStyle(fontSize: 13)),
            value: f['readonly'] == true,
            onChanged: (v) => set('readonly', v),
          ),
          ...buildTextNumberConfig(f, set),
          ...buildDateTimeConfig(
            context: context,
            f: f,
            set: set,
            update: (fn) => setState(fn),
          ),
          ...buildFileConfig(f, set),
          if (f['type'] == 'File')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('حذف فایل پیش از ثبت مجاز باشد', style: TextStyle(fontSize: 13)),
              value: f['allow_delete'] != false,
              onChanged: (v) => set('allow_delete', v),
            ),
          ...buildTableConfig(
            context: context,
            f: f,
            schema: widget.schema,
            set: set,
            onEditColumn: editSchemaField,
          ),
          ...buildFormulaConfig(
            f: f,
            schema: widget.schema,
            fieldOptions: fieldOptions,
            set: set,
          ),
          if (widget.schema['kind'] == 'Document' || widget.parentNative != null)
            formSelect(
              'فیلد مقصد سند',
              f['native_key'] as String?,
              nativeFieldLabels(widget.parentNative ?? '${widget.schema['target']}'),
              (v) => set('native_key', v),
            ),
        ],
        ),
      ),
    );
  }


  IconData _getTypeIcon(String type) {
    for (final card in basicFieldCards) {
      if (card.typeKey == type) return card.icon;
    }
    return Icons.text_fields;
  }

  String _getTypeLabel(String type) {
    for (final card in basicFieldCards) {
      if (card.typeKey == type) return card.label;
    }
    return formTypes[type] ?? type;
  }
}
