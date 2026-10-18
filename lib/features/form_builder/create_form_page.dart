import 'package:flutter/material.dart';

import '../../core/utils/jalali_date.dart';
import '../../core/widgets/asoud_ui.dart';
import 'form_editor.dart';
import 'form_repository.dart';
import 'forms_page.dart';

class CreateFormPage extends StatefulWidget {
  const CreateFormPage({
    required this.repository,
    required this.selectedModule,
    this.initialKind = 'Request',
    super.key,
  });

  final FormRepository repository;
  final String selectedModule;
  final String initialKind;

  @override
  State<CreateFormPage> createState() => _CreateFormPageState();
}

class _CreateFormPageState extends State<CreateFormPage> {
  late String kind = widget.initialKind;
  late final String effectiveModule =
      widget.selectedModule.isEmpty ? 'General' : widget.selectedModule;

  bool useTemplate = false;
  FormMap? selectedPreset;

  late final TextEditingController _titleController = TextEditingController();
  late final TextEditingController _descController = TextEditingController();

  int selectedIconIndex = 0;
  bool expandedIcons = false;
  int selectedColorIndex = 0;

  static const List<(String, IconData)> availableIcons = [
    ('clipboard', Icons.assignment_outlined),
    ('calendar', Icons.calendar_today_outlined),
    ('clock', Icons.access_time_outlined),
    ('users', Icons.people_outline_rounded),
    ('cart', Icons.shopping_cart_outlined),
    ('wallet', Icons.account_balance_wallet_outlined),
    ('box', Icons.inventory_2_outlined),
    ('briefcase', Icons.business_center_outlined),
    ('document', Icons.description_outlined),
    ('truck', Icons.local_shipping_outlined),
    ('wrench', Icons.build_outlined),
    ('building', Icons.business_outlined),
    ('laptop', Icons.laptop_outlined),
    ('phone', Icons.phone_android_outlined),
    ('receipt', Icons.receipt_long_outlined),
    ('credit_card', Icons.credit_card_outlined),
    ('security', Icons.security_outlined),
    ('help', Icons.help_outline_rounded),
  ];

  static const List<Color> availableColors = [
    Color(0xFF1E88E5), // Blue
    Color(0xFF2E7D32), // Green
    Color(0xFFF57F17), // Amber
    Color(0xFF7B1FA2), // Purple
    Color(0xFFC2185B), // Crimson
    Color(0xFF00897B), // Teal
  ];

  static const _moduleVisuals = <String, (IconData, Color, Color)>{
    '': (Icons.grid_view_rounded, Color(0xFF1E88E5), Color(0xFFEFF6FF)),
    'HR': (Icons.people_outline_rounded, Color(0xFF2E7D32), Color(0xFFE8F8F0)),
    'Finance': (
      Icons.account_balance_wallet_outlined,
      Color(0xFFF57F17),
      Color(0xFFFFF8E1)
    ),
    'Sales': (
      Icons.shopping_bag_outlined,
      Color(0xFF7B1FA2),
      Color(0xFFF3E5F5)
    ),
    'Stock': (Icons.inventory_2_outlined, Color(0xFF00796B), Color(0xFFE0F7FA)),
    'Purchase': (
      Icons.business_center_outlined,
      Color(0xFFC2185B),
      Color(0xFFFFEBEE)
    ),
    'Manufacturing': (
      Icons.precision_manufacturing_outlined,
      Color(0xFF455A64),
      Color(0xFFECEFF1)
    ),
    'Projects': (
      Icons.assignment_outlined,
      Color(0xFF512DA8),
      Color(0xFFEDE7F6)
    ),
    'IT': (Icons.computer_outlined, Color(0xFF0288D1), Color(0xFFE1F5FE)),
    'General': (
      Icons.dashboard_customize_outlined,
      Color(0xFF546E7A),
      Color(0xFFECEFF1)
    ),
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges =>
      _titleController.text.trim().isNotEmpty ||
      _descController.text.trim().isNotEmpty ||
      selectedPreset != null;

  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges) return true;
    return await formConfirm(
      context,
      'تغییرات ذخیره نشده از دست خواهند رفت. آیا خارج می‌شوید؟',
    );
  }

  Future<void> _openTemplatePicker() async {
    final allPresets = formPresets(kind);
    final modulePresets = allPresets
        .where((p) =>
            p['module'] == effectiveModule || effectiveModule == 'General')
        .toList();
    final candidatePresets =
        modulePresets.isNotEmpty ? modulePresets : allPresets;

    String templateQuery = '';
    final chosen = await showModalBottomSheet<FormMap>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final filtered = candidatePresets.where((p) {
            final t = '${p['title'] ?? ''}';
            return t.contains(templateQuery.trim());
          }).toList();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'انتخاب الگوی آماده',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'نام الگو را جست‌وجو کنید...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) =>
                          setSheetState(() => templateQuery = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'نتایج الگوها',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '${toPersianDigits('${filtered.length}')} مورد',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('الگویی با این عنوان یافت نشد.'),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final p = filtered[i];
                                final isPicked =
                                    selectedPreset?['title'] == p['title'];
                                final pMod = '${p['module'] ?? 'General'}';
                                final visual = _moduleVisuals[pMod] ??
                                    (
                                      Icons.description_outlined,
                                      const Color(0xFF2E7D32),
                                      const Color(0xFFE8F8F0)
                                    );

                                return InkWell(
                                  onTap: () => Navigator.pop(sheetCtx, p),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isPicked
                                          ? const Color(0xFFEFF6FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isPicked
                                            ? const Color(0xFF1E88E5)
                                            : const Color(0xFFE2E8F0),
                                        width: isPicked ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isPicked
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: isPicked
                                              ? const Color(0xFF1E88E5)
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '${p['title']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isPicked
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: visual.$3,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(visual.$1,
                                              size: 18, color: visual.$2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (chosen != null && mounted) {
      setState(() {
        selectedPreset = chosen;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = 'کپی ${chosen['title']}';
        }
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً عنوان قالب فرم را وارد کنید.')),
      );
      return;
    }

    FormMap schema;
    if (useTemplate && selectedPreset != null) {
      schema = copyForm(selectedPreset!);
      schema['title'] = title;
      schema['description'] = _descController.text.trim();
      schema['module'] = effectiveModule;
      schema['kind'] = kind;
    } else {
      schema = blankSchema(kind);
      schema['title'] = title;
      schema['description'] = _descController.text.trim();
      schema['module'] = effectiveModule;
    }

    schema['icon'] = availableIcons[selectedIconIndex].$1;
    schema['color'] =
        '#${availableColors[selectedColorIndex].toARGB32().toRadixString(16).substring(2)}';

    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FormEditorPage(
          repository: widget.repository,
          initial: {
            'schema': schema,
            'client_id': newFormId(),
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = _moduleVisuals[effectiveModule] ??
        (
          Icons.category_outlined,
          const Color(0xFF1E88E5),
          const Color(0xFFEFF6FF)
        );

    final selectedIcon = availableIcons[selectedIconIndex].$2;
    final selectedColor = availableColors[selectedColorIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmLeave();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const AsoudHeader(
            title: 'ایجاد فرم جدید',
            subtitle: 'طراحی قالب خام',
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Card 1: Initial Specifications (Section 3 order)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_note_rounded,
                              color: Color(0xFF1E88E5), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'مشخصات اولیه قالب',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 1. Kind: Request / Document
                    const Text(
                      'نوع قالب *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AsoudSegmentedControl<String>(
                      value: kind,
                      options: const [
                        AsoudSegmentedOption(
                            value: 'Request', label: 'درخواست'),
                        AsoudSegmentedOption(value: 'Document', label: 'سند'),
                      ],
                      onChanged: (v) => setState(() {
                        kind = v;
                        selectedPreset = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    // 2. Selected Module Card (Read-only with Lock icon)
                    const Text(
                      'ماژول انتخاب‌شده',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: visual.$3,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(visual.$1, size: 20, color: visual.$2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formModules[effectiveModule] ??
                                      effectiveModule,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'انتخاب‌شده از صفحه قبل',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.lock_outline_rounded,
                              size: 18, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 3. Creation Method
                    const Text(
                      'روش ایجاد قالب *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => setState(() => useTemplate = false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              !useTemplate
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: !useTemplate
                                  ? const Color(0xFF1E88E5)
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('طراحی فرم جدید',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => useTemplate = true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              useTemplate
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: useTemplate
                                  ? const Color(0xFF1E88E5)
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('استفاده از الگوی آماده',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 4. Template Selector (only if useTemplate is true)
                    if (useTemplate) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الگوی آماده',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _openTemplatePicker,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.copy_rounded,
                                        size: 18, color: Color(0xFF1E88E5)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedPreset?['title'] ??
                                            'برای انتخاب الگو لمس کنید...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: selectedPreset != null
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.expand_more_rounded,
                                        size: 20, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'فقط الگوهای مجاز ماژول انتخاب‌شده نمایش داده می‌شوند.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // 5. Title
                    const Text(
                      'عنوان قالب *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'عنوان قالب را وارد کنید...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 6. Description
                    const Text(
                      'توضیحات',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'توضیحات مختصر درباره کاربرد این فرم...',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Card 2: Icon and Color Selection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.palette_outlined,
                                    color: Color(0xFF7B1FA2), size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'انتخاب آیکون فرم',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: selectedColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: selectedColor),
                          ),
                          child: Icon(selectedIcon,
                              color: selectedColor, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'کتابخانه آیکون‌ها',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              setState(() => expandedIcons = !expandedIcons),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                expandedIcons ? 'نمایش کمتر' : 'نمایش همه',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E88E5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                expandedIcons
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16,
                                color: const Color(0xFF1E88E5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 6-column icon grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final displayedIcons = expandedIcons
                            ? availableIcons
                            : availableIcons.take(12).toList();

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: displayedIcons.length,
                          itemBuilder: (ctx, idx) {
                            final item = displayedIcons[idx];
                            final isPicked = selectedIconIndex == idx;
                            return InkWell(
                              onTap: () =>
                                  setState(() => selectedIconIndex = idx),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isPicked
                                      ? selectedColor.withValues(alpha: 0.1)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPicked
                                        ? selectedColor
                                        : const Color(0xFFE2E8F0),
                                    width: isPicked ? 1.5 : 1,
                                  ),
                                ),
                                child: Icon(
                                  item.$2,
                                  size: 20,
                                  color: isPicked
                                      ? selectedColor
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'رنگ آیکون',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(availableColors.length, (idx) {
                        final color = availableColors[idx];
                        final isPicked = selectedColorIndex == idx;
                        return InkWell(
                          onTap: () => setState(() => selectedColorIndex = idx),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isPicked
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isPicked
                                ? const Icon(Icons.check,
                                    size: 20, color: Colors.white)
                                : null,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check, size: 20),
                label: const Text(
                  'تأیید و ادامه',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
