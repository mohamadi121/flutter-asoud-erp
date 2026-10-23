import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/access_denied.dart';
import '../../core/auth/capabilities.dart';
import '../../core/network/frappe_client.dart';
import '../../core/offline/offline_failure.dart';
import '../../core/widgets/asoud_ui.dart';
import '../../core/utils/jalali_date.dart';
import '../request_types/presentation/pages/forms_management_page.dart';
import 'create_form_page.dart';
import 'form_editor.dart';
import 'form_repository.dart';
import 'form_runtime.dart';
import 'presets/hr_traffic_correction.dart';
import 'presets/hr_salary_advance.dart';
import 'presets/hr_employment_certificate.dart';
import 'presets/hr_shift_change.dart';
import 'presets/hr_settlement.dart';
import 'presets/hr_training.dart';

class VersionedFormsPage extends StatefulWidget {
  const VersionedFormsPage({
    required this.company,
    this.manage = true,
    this.initialKind = 'Request',
    this.fixedKind = false,
    super.key,
  });
  final String company, initialKind;
  final bool manage;
  final bool fixedKind;
  @override
  State<VersionedFormsPage> createState() => _VersionedFormsPageState();
}

class _VersionedFormsPageState extends State<VersionedFormsPage> {
  late final Future<Capabilities> _capabilities = capabilitiesOf(context);
  String _effectiveCompany = '';
  String get effectiveCompany =>
      _effectiveCompany.isNotEmpty ? _effectiveCompany : widget.company;

  late final repository = FormRepository(
    context.read<FrappeApiClient>(),
    widget.company,
  );
  late String kind = widget.initialKind;
  String query = '', module = '', status = '';
  bool expandedModules = false;
  late final TextEditingController _searchController = TextEditingController();
  late Future<List<FormMap>> rows = repository.list(
    kind,
    manage: widget.manage,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _effectiveCompany = widget.company;
    if (_effectiveCompany.isEmpty) {
      try {
        final client = context.read<FrappeApiClient>();
        client.getCurrentUser().then((u) {
          if (mounted && (u.company ?? '').isNotEmpty) {
            setState(() => _effectiveCompany = u.company!);
          }
        }).catchError((_) {});
      } catch (_) {}
    }
  }
  void reload() {
    setState(() {
      rows = repository.list(kind, manage: widget.manage);
    });
  }
  Future<void> editor(FormMap initial) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            FormEditorPage(repository: repository, initial: initial),
      ),
    );
    if (mounted) {
      reload();
    }
  }

  Future<void> create() async {
    String targetModule = module;
    if (targetModule.isEmpty) {
      final chosen = await pickModuleModal(context);
      if (chosen == null || !mounted) {
        return;
      }
      targetModule = chosen;
    }

    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CreateFormPage(
          repository: repository,
          selectedModule: targetModule,
          initialKind: kind,
        ),
      ),
    );
    if (mounted) {
      reload();
    }
  }

  Future<void> action(String action, FormMap row) async {
    try {
      if (action == 'edit' || action == 'copy') {
        final data = row['schema'] != null
            ? copyForm(row)
            : formMap(
                await repository.call('get_form', {
                  'name': row['name'],
                  'manage': 1,
                }),
              );
        if (action == 'copy') {
          final schema = formMap(data['schema']);
          schema['title'] = '${schema['title']} (کپی)';
          if (mounted) {
            await editor({'schema': schema, 'client_id': newFormId()});
          }
        } else if (mounted) {
          await editor(data);
        }
      } else if (action == 'preview') {
        final data = formMap(
          await repository.call('get_form', {
            'name': row['name'],
            'manage': widget.manage ? 1 : 0,
          }),
        );
        if (!mounted) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => FormEntryPage(
              repository: repository,
              record: data,
              previewOnly: widget.manage,
            ),
          ),
        );
      } else if (action == 'versions') {
        final history = formMaps(
          await repository.call('get_history', {
            'name': row['name'],
          }),
        );
        if (!mounted) {
          return;
        }
        await formSheet<void>(
          context,
          'تاریخچه نسخه‌ها',
          (sheet, update) => Column(
            children: [
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('تاریخچه‌ای برای این فرم ثبت نشده است.'),
                ),
              for (final r in history)
                ListTile(
                  title: Text('نسخه ${toPersianDigits('${r['version'] ?? 1}')}'),
                  subtitle: Text(
                    '${formatJalaliDateTimeIso('${r['published_on']}')} · ${r['published_by'] ?? ''}\n${r['change_note'] ?? ''}',
                  ),
                ),
            ],
          ),
        );
      } else if (action == 'disable' || action == 'enable') {
        if (!await formConfirm(
          context,
          action == 'disable'
              ? 'فرم غیرفعال شود؟ ثبت‌های قبلی باقی می‌مانند.'
              : 'نسخه منتشرشده دوباره فعال شود؟',
        )) {
          return;
        }
        await repository.call('transition', {
          'name': row['name'],
          'action': action,
          'expected_version': row['draft_version'],
        });
      }
      if (mounted) {
        reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(offlineFailureMessage(e))));
      }
    }
  }

  Future<void> entries() async {
    try {
      final records = formMaps(
        await repository.call('list_my_entries', {'company': widget.company}),
      );
      if (!mounted) {
        return;
      }
      await formSheet<void>(
        context,
        'ثبت‌های من',
        (sheet, update) => Column(
          children: [
            if (records.isEmpty) const Text('هنوز فرمی ثبت نشده است.'),
            for (final entry in records)
              ListTile(
                title: Text('${entry['subject']}'),
                subtitle: Text(
                  '${formatJalaliDateTimeIso('${entry['creation']}')}\n${entry['name']}',
                ),
                onTap: () async {
                  try {
                    final data = formMap(
                      await repository.call('get_entry', {
                        'name': entry['name'],
                      }),
                    );
                    if (!sheet.mounted) {
                      return;
                    }
                    await formSheet<void>(
                      sheet,
                      '${data['subject']} — نسخه ${data['version']}',
                      (c, s) => Column(
                        children: [
                          if (data['reference_name'] != null)
                            Text('رکورد مرتبط: ${data['reference_name']}'),
                          if (data['current_native_values'] == true)
                            const Text(
                                'مقادیر فعلی سند اصلی با چیدمان نسخه زمان ثبت نمایش داده می‌شوند.'),
                          FormFieldsView(
                            schema: formMap(data['schema']),
                            values: formMap(data['values']),
                            repository: repository,
                            enabled: false,
                            snapshot: true,
                            onChanged: (_) {},
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (sheet.mounted) {
                      ScaffoldMessenger.of(sheet).showSnackBar(
                        SnackBar(content: Text(offlineFailureMessage(e))),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(offlineFailureMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.manage) {
      return _buildContent(context);
    }
    return FutureBuilder<Capabilities>(
      future: _capabilities,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!.canManageForms) {
          return const AccessDeniedScaffold();
        }
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AsoudHeader(
            title: widget.manage ? 'مدیریت فرم‌ها' : 'فرم‌های قابل ثبت',
            subtitle: effectiveCompany,
            action: IconButton(
              onPressed: reload,
              icon: const Icon(Icons.refresh),
              tooltip: 'بازخوانی',
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!widget.fixedKind)
                AsoudSegmentedControl<String>(
                  value: kind,
                  options: const [
                    AsoudSegmentedOption(value: 'Request', label: 'درخواست‌ها'),
                    AsoudSegmentedOption(value: 'Document', label: 'سندها'),
                  ],
                  onChanged: (v) {
                    kind = v;
                    reload();
                  },
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'جست‌وجوی قالب فرم...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => query = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => query = v.trim()),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ماژول‌ها',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () =>
                        setState(() => expandedModules = !expandedModules),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            expandedModules ? 'نمایش کمتر' : 'نمایش همه',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E88E5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            expandedModules
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: const Color(0xFF1E88E5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final baseItems = [
                    ('', 'همه'),
                    ('HR', 'منابع انسانی'),
                    ('Finance', 'مالی'),
                    ('Sales', 'فروش'),
                    ('Stock', 'انبار'),
                    ('Purchase', 'اداری'),
                  ];
                  final expandedList = [
                    ('Manufacturing', 'تولید'),
                    ('Projects', 'پروژه‌ها'),
                    ('IT', 'فناوری اطلاعات'),
                    ('General', 'عمومی'),
                  ];
                  final moduleItems = [
                    ...baseItems,
                    if (expandedModules)
                      ...expandedList
                    else if (module.isNotEmpty &&
                        !baseItems.any((m) => m.$1 == module))
                      (module, formModules[module] ?? module),
                  ];
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: moduleItems.length,
                    itemBuilder: (context, index) {
                      final item = moduleItems[index];
                      final isSelected = module == item.$1;
                      final visual = _moduleVisuals[item.$1] ??
                          (
                            Icons.category_outlined,
                            const Color(0xFF1E88E5),
                            const Color(0xFFF1F5F9)
                          );
                      return InkWell(
                        onTap: () => setState(() => module =
                            isSelected && item.$1.isNotEmpty ? '' : item.$1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: visual.$3,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1E88E5)
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(visual.$1, size: 22, color: visual.$2),
                              const SizedBox(height: 6),
                              Text(
                                item.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<FormMap>>(
                future: rows,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        Text(offlineFailureMessage(snapshot.error!)),
                        const Text(
                          'بخش نسخه‌دار نیازمند نصب نسخه جدید افزونه سرور است.',
                        ),
                        TextButton(
                          onPressed: reload,
                          child: const Text('تلاش مجدد'),
                        ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final filtered = snapshot.data!.where((r) {
                    final s = formMap(r['schema']);
                    final title = '${s['title'] ?? r['title'] ?? ''}';
                    return title.contains(query) &&
                        (module.isEmpty ||
                            (s['module'] ?? r['module_key']) == module) &&
                        (status.isEmpty || (r['status'] ?? 'Draft') == status);
                  }).toList();
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              kind == 'Request'
                                  ? 'قالب فرم‌های درخواست'
                                  : 'قالب فرم‌های سند',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${toPersianDigits('${filtered.length}')} مورد',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('فرمی با این فیلتر پیدا نشد.'),
                        ),
                      for (final row in filtered) ...[
                        _buildTemplateCard(row),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
              if (widget.manage)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FormsManagementPage(company: widget.company),
                    ),
                  ),
                  child: const Text(
                    'فرم‌ها و الگوهای نسخه قبلی (بدون مهاجرت خودکار)',
                  ),
                ),
              if (!widget.manage)
                TextButton(
                  onPressed: entries,
                  child: const Text('مشاهده ثبت‌های من'),
                ),
            ],
          ),
          bottomNavigationBar: widget.manage
              ? AsoudBottomActions(
                  primaryLabel: '+ ایجاد فرم جدید',
                  onPrimary: create,
                )
              : null,
        ),
      );

  static const _moduleVisuals = <String, (IconData, Color, Color)>{
    '': (Icons.grid_view_rounded, Color(0xFF1E88E5), Color(0xFFEFF6FF)),
    'HR': (Icons.people_outline_rounded, Color(0xFF2E7D32), Color(0xFFE8F8F0)),
    'Finance': (
      Icons.account_balance_wallet_outlined,
      Color(0xFFF57F17),
      Color(0xFFFFF8E1)
    ),
    'Sales':
        (Icons.shopping_bag_outlined, Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
    'Stock': (Icons.inventory_2_outlined, Color(0xFF00796B), Color(0xFFE0F7FA)),
    'Purchase': (Icons.business_center_outlined, Color(0xFFC2185B), Color(0xFFFFEBEE)),
    'Manufacturing': (
      Icons.precision_manufacturing_outlined,
      Color(0xFF455A64),
      Color(0xFFECEFF1)
    ),
    'Projects':
        (Icons.assignment_outlined, Color(0xFF512DA8), Color(0xFFEDE7F6)),
    'IT': (Icons.computer_outlined, Color(0xFF0288D1), Color(0xFFE1F5FE)),
    'General': (
      Icons.dashboard_customize_outlined,
      Color(0xFF546E7A),
      Color(0xFFECEFF1)
    ),
  };

  static const _iconMap = <String, IconData>{
    'clipboard': Icons.assignment_outlined,
    'calendar': Icons.calendar_today_outlined,
    'clock': Icons.access_time_outlined,
    'users': Icons.people_outline_rounded,
    'cart': Icons.shopping_cart_outlined,
    'wallet': Icons.account_balance_wallet_outlined,
    'box': Icons.inventory_2_outlined,
    'briefcase': Icons.business_center_outlined,
    'document': Icons.description_outlined,
    'truck': Icons.local_shipping_outlined,
    'wrench': Icons.build_outlined,
    'building': Icons.business_outlined,
    'laptop': Icons.laptop_outlined,
    'phone': Icons.phone_android_outlined,
    'receipt': Icons.receipt_long_outlined,
    'credit_card': Icons.credit_card_outlined,
    'security': Icons.security_outlined,
    'help': Icons.help_outline_rounded,
  };

  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    } else if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return null;
  }

  Widget _buildTemplateCard(FormMap row) {
    final s = formMap(row['schema']);
    final title = '${s['title'] ?? row['title'] ?? 'پیش‌نویس'}';
    final modKey = '${s['module'] ?? row['module_key'] ?? 'General'}';
    final visual = _moduleVisuals[modKey] ??
        (
          Icons.description_outlined,
          const Color(0xFF10B981),
          const Color(0xFFE8F5E9)
        );
    final customIcon = s['icon'] != null ? _iconMap[s['icon']] : null;
    final customColor = _parseHexColor(s['color']?.toString());
    final cardIcon = customIcon ?? visual.$1;
    final cardIconColor = customColor ?? visual.$2;
    final cardIconBg = customColor != null
        ? customColor.withValues(alpha: 0.12)
        : visual.$3;
    final status = '${row['status'] ?? 'Draft'}';

    String statusText;
    Color statusBg;
    Color statusColor;

    if (row['local'] == true) {
      statusText = 'پیش‌نویس دستگاه';
      statusBg = const Color(0xFFF1F5F9);
      statusColor = const Color(0xFF64748B);
    } else if (status == 'Published') {
      statusText = 'فعال';
      statusBg = const Color(0xFFE8F8F0);
      statusColor = const Color(0xFF2E7D32);
    } else if (status == 'Inactive') {
      statusText = 'غیرفعال';
      statusBg = const Color(0xFFFFEBEE);
      statusColor = const Color(0xFFC62828);
    } else if (status == 'Pending') {
      statusText = 'در انتظار';
      statusBg = const Color(0xFFFFF8E1);
      statusColor = const Color(0xFFF57F17);
    } else {
      statusText = 'پیش‌نویس';
      statusBg = const Color(0xFFF1F5F9);
      statusColor = const Color(0xFF475569);
    }

    return InkWell(
      onTap: () => action(widget.manage ? 'edit' : 'preview', row),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cardIconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cardIcon, size: 22, color: cardIconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formModules[modKey] ?? modKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.manage)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: Color(0xFF64748B), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (v) => action(v, row),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('ویرایش / نسخه جدید'),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Text('ایجاد نسخه مشابه'),
                  ),
                  if (row['name'] != null) ...[
                    const PopupMenuItem(
                      value: 'versions',
                      child: Text('نسخه‌ها'),
                    ),
                    const PopupMenuItem(
                      value: 'preview',
                      child: Text('پیش‌نمایش'),
                    ),
                    PopupMenuItem(
                      value: row['disabled'] == 1 ? 'enable' : 'disable',
                      child: Text(
                        row['disabled'] == 1 ? 'فعال‌سازی' : 'غیرفعال‌سازی',
                      ),
                    ),
                  ],
                ],
              )
            else
              const Icon(Icons.chevron_left, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class FormEntryPage extends StatefulWidget {
  const FormEntryPage({
    required this.repository,
    required this.record,
    this.previewOnly = false,
    super.key,
  });
  final FormRepository repository;
  final FormMap record;
  final bool previewOnly;
  @override
  State<FormEntryPage> createState() => _FormEntryPageState();
}

class _FormEntryPageState extends State<FormEntryPage> {
  final key = GlobalKey<FormState>();
  FormMap values = {};
  String subject = '', requestKey = newFormId();
  String? error;
  bool busy = false;
  bool restoring = true;
  final subjectController = TextEditingController();
  @override
  void initState() {
    super.initState();
    restore();
  }

  @override
  void dispose() {
    subjectController.dispose();
    super.dispose();
  }

  Future<void> restore() async {
    try {
      final draft = widget.previewOnly
          ? null
          : await widget.repository.entryDraft('${widget.record['name']}');
      if (!mounted) {
        return;
      }
      if (draft != null) {
        if (draft['revision'] != widget.record['revision']) {
          error =
              'نسخه فرم از زمان ذخیره پیش‌نویس تغییر کرده است. پیش‌نویس قبلی حفظ شده و خودکار به نسخه جدید منتقل نمی‌شود.';
        } else {
          values = formMap(draft['values']);
          subject = '${draft['subject'] ?? ''}';
          subjectController.text = subject;
          requestKey = '${draft['request_key']}';
        }
      }
    } catch (e) {
      error = offlineFailureMessage(e);
    } finally {
      if (mounted) {
        setState(() => restoring = false);
      }
    }
  }

  Future<void> saveLocal() async {
    if (widget.previewOnly) {
      return;
    }
    try {
      await widget.repository.saveEntryDraft('${widget.record['name']}', {
        'revision': widget.record['revision'],
        'subject': subject,
        'values': values,
        'request_key': requestKey
      });
      if (mounted) {
        setState(() =>
            error = 'پیش‌نویس روی دستگاه ذخیره شد؛ ثبت قطعی انجام نشده است.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = offlineFailureMessage(e));
      }
    }
  }

  Future<void> submit() async {
    if (!(key.currentState?.validate() ?? false)) {
      return;
    }
    if (widget.previewOnly) {
      setState(
        () => error = 'بررسی محلی انجام شد؛ در پیش‌نمایش اطلاعات ثبت نمی‌شوند.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.saveEntryDraft('${widget.record['name']}', {
        'revision': widget.record['revision'],
        'subject': subject,
        'values': values,
        'request_key': requestKey
      });
      final result = formMap(
        await widget.repository.call('submit_form', {
          'name': widget.record['name'],
          'revision_name': widget.record['revision'],
          'subject': subject,
          'values': evaluatedValues(formMap(widget.record['schema']), values),
          'request_key': requestKey,
        }),
      );
      await widget.repository.discardEntryDraft('${widget.record['name']}');
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('ثبت شد'),
          content: Text(
            'شماره ثبت: ${result['name']}${result['reference_name'] != null && result['reference_name'] != '' ? '\nرکورد مرتبط: ${result['reference_name']}' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('بستن'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = offlineFailureMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AsoudHeader(
            title: '${formMap(widget.record['schema'])['title']}',
            subtitle: widget.previewOnly
                ? 'پیش‌نمایش؛ بدون ثبت اطلاعات'
                : 'نسخه ${widget.record['version']}',
          ),
          body: restoring
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: key,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (error != null) Text(error!),
                      TextFormField(
                        controller: subjectController,
                        decoration:
                            const InputDecoration(labelText: 'عنوان ثبت *'),
                        onChanged: (v) => subject = v,
                        validator: (v) => (v ?? '').trim().length < 3
                            ? 'حداقل سه حرف وارد کنید.'
                            : null,
                      ),
                      FormFieldsView(
                        schema: formMap(widget.record['schema']),
                        values: values,
                        repository: widget.repository,
                        formName: widget.previewOnly
                            ? null
                            : '${widget.record['name']}',
                        enabled: !busy,
                        onChanged: (v) => setState(() => values = v),
                      ),
                      if (!widget.previewOnly)
                        TextButton(
                            onPressed: busy ? null : saveLocal,
                            child: const Text('ذخیره پیش‌نویس روی دستگاه')),
                    ],
                  ),
                ),
          bottomNavigationBar: AsoudBottomActions(
            primaryLabel: busy
                ? 'در حال ثبت…'
                : widget.previewOnly
                    ? 'بررسی فرم'
                    : 'ثبت فرم',
            onPrimary: busy || restoring ? null : submit,
          ),
        ),
      );
}

Future<String?> pickModuleModal(BuildContext context, {String? current}) async {
  String? selected = current;
  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheetState) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'انتخاب ماژول',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'برای ایجاد فرم جدید، ابتدا ماژول مربوطه را مشخص کنید.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              for (final entry in formModules.entries) ...[
                InkWell(
                  onTap: () => setSheetState(() => selected = entry.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          selected == entry.key
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected == entry.key
                              ? const Color(0xFF1E88E5)
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(entry.value,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(sheetCtx, selected),
                  child: const Text('ادامه'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

List<FormMap> formPresets(String kind) {
  FormMap field(
    String key,
    String label,
    String type, [
    FormMap extra = const {},
  ]) =>
      {'key': key, 'label': label, 'type': type, ...extra};
  if (kind == 'Request') {
    return [
      hrTrafficCorrectionPreset(),
      employmentCertificatePreset(),
      hrShiftChangePreset(),
      hrTrainingPreset(),
      for (final item in [
        (
          'درخواست عمومی',
          'General',
          'clipboard',
          '#1E88E5',
          'قالب پیش‌فرض برای ثبت انواع درخواست‌های عمومی سازمانی',
        ),
        (
          'درخواست مرخصی',
          'HR',
          'calendar',
          '#2E7D32',
          'قالب آماده برای ثبت انواع مرخصی استحقاقی، استعلاجی و ساعتی',
        ),
        (
          'درخواست مأموریت',
          'HR',
          'briefcase',
          '#2E7D32',
          'قالب آماده برای اعزام و مأموریت‌های اداری و عملیاتی',
        ),
        (
          'درخواست تجهیزات',
          'IT',
          'laptop',
          '#0288D1',
          'قالب درخواست سخت‌افزار، تجهیزات شبکه و امکانات انفورماتیک',
        ),
        (
          'درخواست تنخواه',
          'Finance',
          'wallet',
          '#F57F17',
          'قالب ثبت تنخواه، هزینه‌های جاری و تسویه‌حساب مالی',
        ),
        (
          'درخواست خرید کالا',
          'Purchase',
          'cart',
          '#C2185B',
          'قالب ثبت نیاز و درخواست خرید کالا و تجهیزات',
        ),
      ])
        {
          ...blankSchema(kind),
          'title': item.$1,
          'module': item.$2,
          'icon': item.$3,
          'color': item.$4,
          'description': item.$5,
          'sections': [
            {
              'id': 'main',
              'title': 'اطلاعات درخواست',
              'fields': [
                field('description', 'شرح درخواست', 'LongText', {
                  'required': true,
                }),
                field('date', 'تاریخ موردنیاز', 'Date'),
                if (item.$2 == 'Purchase' || item.$2 == 'IT')
                  field('items', 'اقلام', 'Table', {
                    'max_rows': 100,
                    'columns': [
                      field('item', 'کالا', 'Link', {
                        'source': 'Item',
                        'required': true,
                      }),
                      field('qty', 'تعداد', 'Decimal', {
                        'min': 0.001,
                        'required': true,
                      }),
                    ],
                  }),
                if (item.$2 == 'Finance')
                  field('amount', 'مبلغ', 'Money', {
                    'min': 0,
                    'required': true,
                  }),
              ],
            },
          ],
        },
      hrSalaryAdvancePreset(),
      hrSettlementPreset(),
    ];
  }
  return [
    {
      ...blankSchema(kind),
      'title': 'درخواست کالا',
      'module': 'Purchase',
      'icon': 'box',
      'color': '#00796B',
      'description': 'سند درخواست و حواله انتقال کالا از انبار',
      'target': 'Material Request',
      'sections': [
        {
          'id': 'main',
          'title': 'اطلاعات سند',
          'fields': [
            field('purpose', 'نوع درخواست', 'Select', {
              'options': [
                'Purchase',
                'Material Transfer',
                'Material Issue',
                'Manufacture',
              ],
              'option_labels': {
                'Purchase': 'خرید',
                'Material Transfer': 'انتقال کالا',
                'Material Issue': 'مصرف کالا',
                'Manufacture': 'تولید'
              },
              'default': 'Purchase',
              'required': true,
              'native_key': 'material_request_type',
            }),
            field('required_date', 'تاریخ نیاز', 'Date', {
              'required': true,
              'native_key': 'schedule_date',
            }),
            field('items', 'اقلام', 'Table', {
              'native_key': 'items',
              'min_rows': 1,
              'max_rows': 100,
              'required': true,
              'columns': [
                field('item', 'کالا', 'Link', {
                  'source': 'Item',
                  'native_key': 'item_code',
                  'required': true,
                }),
                field('qty', 'تعداد', 'Decimal', {
                  'min': 0.001,
                  'native_key': 'qty',
                  'required': true,
                }),
                field('date', 'تاریخ نیاز', 'Date', {
                  'native_key': 'schedule_date',
                  'required': true,
                }),
              ],
            }),
          ],
        },
      ],
    },
    {
      ...blankSchema(kind),
      'title': 'سند حسابداری',
      'module': 'Finance',
      'icon': 'receipt',
      'color': '#F57F17',
      'description': 'سند ثبت دستی آرتیکل‌های حسابداری و اسناد مالی',
      'target': 'Journal Entry',
      'sections': [
        {
          'id': 'main',
          'title': 'اطلاعات سند',
          'fields': [
            field('date', 'تاریخ ثبت', 'Date', {
              'native_key': 'posting_date',
              'required': true,
            }),
            field('description', 'شرح', 'LongText', {
              'native_key': 'user_remark',
            }),
            field('accounts', 'آرتیکل‌ها', 'Table', {
              'native_key': 'accounts',
              'min_rows': 2,
              'max_rows': 100,
              'required': true,
              'columns': [
                field('account', 'حساب', 'Link', {
                  'source': 'Account',
                  'native_key': 'account',
                  'required': true,
                }),
                field('debit', 'بدهکار', 'Money', {
                  'native_key': 'debit_in_account_currency',
                  'min': 0,
                }),
                field('credit', 'بستانکار', 'Money', {
                  'native_key': 'credit_in_account_currency',
                  'min': 0,
                }),
              ],
            }),
          ],
        },
      ],
    },
  ];
}
