import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_jalali_picker.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/salary_change_order_repository.dart';
import '../cubit/salary_change_orders_cubit.dart';
import '../widgets/hr_document_print.dart';
import '../widgets/hr_template_status.dart';

enum SalaryChangeOrdersMode { list, form, preview, templateBuilder }

enum _SalaryChangeViewMode { list, form, preview, templateBuilder }

class SalaryChangeOrdersPage extends StatelessWidget {
  const SalaryChangeOrdersPage({
    required this.company,
    this.repository,
    this.canIssue = false,
    this.canDesign = false,
    this.canExecutePayroll = false,
    this.initialMode = SalaryChangeOrdersMode.list,
    super.key,
  });

  final String company;
  final SalaryChangeOrderRepository? repository;
  final bool canIssue;
  final bool canDesign;
  final bool canExecutePayroll;
  final SalaryChangeOrdersMode initialMode;

  @override
  Widget build(BuildContext context) {
    final repo = repository ??
        SalaryChangeOrderRepository(context.read<FrappeApiClient>());
    return BlocProvider(
      create: (_) => SalaryChangeOrdersCubit(
        repository: repo,
        company: company,
      )
        ..load()
        ..loadPeople(),
      child: _SalaryChangeOrdersView(
        company: company,
        canIssue: canIssue,
        canDesign: canDesign,
        canExecutePayroll: canExecutePayroll,
        initialMode: initialMode,
      ),
    );
  }
}

class _SalaryChangeOrdersView extends StatefulWidget {
  const _SalaryChangeOrdersView({
    required this.company,
    required this.canIssue,
    required this.canDesign,
    required this.canExecutePayroll,
    required this.initialMode,
  });

  final String company;
  final bool canIssue;
  final bool canDesign;
  final bool canExecutePayroll;
  final SalaryChangeOrdersMode initialMode;

  @override
  State<_SalaryChangeOrdersView> createState() =>
      _SalaryChangeOrdersViewState();
}

class _SalaryChangeOrdersViewState extends State<_SalaryChangeOrdersView> {
  late _SalaryChangeViewMode _mode;

  // Form state
  String? _orderId;
  int _revision = 0;
  String _personId = '';
  String _employeeName = '';
  String _employeeNumber = '';
  String _unit = '';
  String _position = '';
  String _reason = 'annual';
  String _description = '';
  String _effectiveDate = DateTime.now().toIso8601String().split('T').first;
  final Map<String, TextEditingController> _amountControllers = {};
  String? _validationMessage;

  // Template builder state
  List<Map<String, String>> _builderArticles = [];
  List<Map<String, String>> _builderComparisonRows = [];
  int _builderTab = 0;
  int? _expandedArticleIndex;
  int? _editingArticleIndex;
  final _builderArticleTitleController = TextEditingController();
  final _builderArticleBodyController = TextEditingController();
  bool _showNewArticleForm = false;
  final _newArticleTitleController = TextEditingController();
  final _newArticleBodyController = TextEditingController();

  void _beginEditArticle(int index) {
    setState(() {
      _editingArticleIndex = index;
      _expandedArticleIndex = index;
      _builderArticleTitleController.text = _builderArticles[index]['title'] ?? '';
      _builderArticleBodyController.text = _builderArticles[index]['body'] ?? '';
      _showNewArticleForm = false;
    });
  }

  void _saveEditArticle() {
    final title = _builderArticleTitleController.text.trim();
    final body = _builderArticleBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    setState(() {
      _builderArticles[_editingArticleIndex!]['title'] = title;
      _builderArticles[_editingArticleIndex!]['body'] = body;
      _editingArticleIndex = null;
    });
  }

  void _addNewArticle() {
    final title = _newArticleTitleController.text.trim();
    final body = _newArticleBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    setState(() {
      final newId = 'custom_art_${DateTime.now().millisecondsSinceEpoch}';
      _builderArticles.add({'id': newId, 'title': title, 'body': body});
      _newArticleTitleController.clear();
      _newArticleBodyController.clear();
      _showNewArticleForm = false;
      _expandedArticleIndex = _builderArticles.length - 1;
    });
  }

  void _moveArticle(int from, int to) {
    if (to < 0 || to >= _builderArticles.length) return;
    setState(() {
      final item = _builderArticles.removeAt(from);
      _builderArticles.insert(to, item);
      _editingArticleIndex = null;
      _expandedArticleIndex = to;
    });
  }

  void _showSalaryFieldPicker(TextEditingController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String query = '';
        String activeCategory = 'personnel';

        final Map<String, List<String>> fieldGroups = {
          'personnel': [
            '[نام و نام خانوادگی پرسنل]',
            '[کد پرسنلی]',
            '[عنوان شغلی]',
            '[واحد سازمانی]',
          ],
          'company': [
            '[نام قانونی شرکت]',
            '[نام نماینده قانونی]',
            '[سمت نماینده قانونی]',
            '[نشانی شرکت]',
          ],
          'decree': [
            '[علت تغییر حقوق]',
            '[تاریخ اجرای تغییر]',
            '[شماره حکم]',
            '[تاریخ صدور حکم]',
          ],
          'payroll': [
            '[حقوق پایه]',
            '[حق جذب]',
            '[حق مسکن]',
            '[بن خواربار]',
          ],
        };

        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeList = fieldGroups[activeCategory] ?? [];
            final filtered = activeList.where((f) {
              final q = query.toLowerCase().trim();
              return f.toLowerCase().contains(q);
            }).toList();

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'انتخاب فیلد موجود جهت درج در ماده',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('پرسنل', style: TextStyle(fontSize: 10)),
                            selected: activeCategory == 'personnel',
                            onSelected: (val) {
                              if (val) setModalState(() => activeCategory = 'personnel');
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('شرکت', style: TextStyle(fontSize: 10)),
                            selected: activeCategory == 'company',
                            onSelected: (val) {
                              if (val) setModalState(() => activeCategory = 'company');
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('حکم', style: TextStyle(fontSize: 10)),
                            selected: activeCategory == 'decree',
                            onSelected: (val) {
                              if (val) setModalState(() => activeCategory = 'decree');
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('حقوق', style: TextStyle(fontSize: 10)),
                            selected: activeCategory == 'payroll',
                            onSelected: (val) {
                              if (val) setModalState(() => activeCategory = 'payroll');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'جست‌وجوی نام فیلد...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) => setModalState(() => query = val),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('فیلدی با این نام یافت نشد.', style: TextStyle(fontSize: 11)),
                            )
                          : SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filtered.map((f) {
                                  return ActionChip(
                                    label: Text(f, style: const TextStyle(fontSize: 11)),
                                    avatar: const Icon(Icons.add, size: 16, color: AsoudColors.primary),
                                    onPressed: () {
                                      final text = controller.text;
                                      final sel = controller.selection;
                                      if (sel.isValid && sel.start >= 0 && sel.end >= sel.start) {
                                        final newText = text.replaceRange(sel.start, sel.end, f);
                                        controller.value = TextEditingValue(
                                          text: newText,
                                          selection: TextSelection.collapsed(offset: sel.start + f.length),
                                        );
                                      } else {
                                        controller.text = text.isEmpty ? f : '$text $f';
                                      }
                                      Navigator.of(ctx).pop();
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  final List<Map<String, String>> _reasons = [
    {'value': 'annual', 'label': 'افزایش سالانه'},
    {'value': 'promotion', 'label': 'ارتقای شغلی'},
    {'value': 'adjustment', 'label': 'اصلاح یا تعدیل حقوق'},
    {'value': 'benefits', 'label': 'تغییر مزایا'},
    {'value': 'other', 'label': 'سایر'},
  ];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == SalaryChangeOrdersMode.templateBuilder
        ? _SalaryChangeViewMode.templateBuilder
        : widget.initialMode == SalaryChangeOrdersMode.form
            ? _SalaryChangeViewMode.form
            : widget.initialMode == SalaryChangeOrdersMode.preview
                ? _SalaryChangeViewMode.preview
                : _SalaryChangeViewMode.list;
    _initDefaultTemplate();
  }

  @override
  void dispose() {
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    _builderArticleTitleController.dispose();
    _builderArticleBodyController.dispose();
    _newArticleTitleController.dispose();
    _newArticleBodyController.dispose();
    super.dispose();
  }

  void _initDefaultTemplate() {
    _builderArticles = [
      {
        'id': 'employee_details',
        'title': 'مشخصات پرسنل و مستند تغییر',
        'body':
            'به موجب این حکم، وضعیت حقوق و مزایای [نام و نام خانوادگی پرسنل] با کد [کد پرسنلی] در [نام قانونی شرکت] مورد بازنگری قرار می‌گیرد.',
      },
      {
        'id': 'subject_reason',
        'title': 'موضوع و علت تغییر',
        'body':
            'با توجه به [علت تغییر حقوق] و با رعایت مقررات و مصوبات معتبر، تغییرات حقوق و مزایا برای [عنوان شغلی] در [واحد سازمانی] تعیین می‌شود.',
      },
      {
        'id': 'effective_date',
        'title': 'تاریخ اجرا و دوره اثرگذاری',
        'body':
            'تغییرات از تاریخ [تاریخ اجرای تغییر] لازم‌الاجرا است. تاریخ صدور حکم [تاریخ صدور حکم] بوده و اثرگذاری مالی بر اساس دوره مربوط اعمال می‌شود.',
      },
      {
        'id': 'salary_comparison',
        'title': 'اقلام حقوق و مزایای قبلی و جدید',
        'body':
            'اقلام مشمول تغییر در جدول زیر با مبلغ قبلی، مبلغ جدید و میزان تغییر نمایش داده می‌شوند. مبالغ نهایی تنها پس از تأیید رسمی معتبرند.',
      },
      {
        'id': 'terms',
        'title': 'سایر شرایط و مقررات',
        'body':
            'سایر مفاد همکاری که صراحتاً در این حکم تغییر نکرده‌اند، مطابق قرارداد و احکام معتبر قبلی به قوت خود باقی می‌مانند.',
      },
      {
        'id': 'issuing_authority',
        'title': 'مرجع صدور و تصویب',
        'body':
            'این حکم پس از طی تأییدهای لازم توسط [نام نماینده قانونی] با سمت [سمت نماینده قانونی] صادر و ثبت خواهد شد.',
      },
    ];

    _builderComparisonRows = [
      {
        'id': 'base_salary',
        'title': 'حقوق پایه',
        'period': 'monthly',
        'old_ref': 'payroll.base_salary',
        'new_ref': 'document.new.base_salary',
      },
      {
        'id': 'housing',
        'title': 'حق مسکن',
        'period': 'monthly',
        'old_ref': 'payroll.housing',
        'new_ref': 'document.new.housing',
      },
      {
        'id': 'food',
        'title': 'بن خواربار',
        'period': 'monthly',
        'old_ref': 'payroll.food',
        'new_ref': 'document.new.food',
      },
    ];
  }

  void _syncTemplateFromState(Map<String, dynamic>? published) {
    if (published == null) return;
    final arts = published['articles'] as List?;
    if (arts != null && arts.isNotEmpty) {
      _builderArticles = arts.map((a) {
        final m = Map<String, dynamic>.from(a as Map);
        return {
          'id': m['id']?.toString() ?? '',
          'title': m['title']?.toString() ?? '',
          'body': m['body']?.toString() ?? '',
        };
      }).toList();
    }
    final rows = published['comparison_rows'] as List?;
    if (rows != null && rows.isNotEmpty) {
      _builderComparisonRows = rows.map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        return {
          'id': m['id']?.toString() ?? '',
          'title': m['title']?.toString() ?? '',
          'period': m['period']?.toString() ?? 'monthly',
          'old_ref': m['old_ref']?.toString() ?? '',
          'new_ref': m['new_ref']?.toString() ?? '',
        };
      }).toList();
    }
  }

  String _reasonLabel(String key) {
    final found = _reasons.firstWhere(
      (r) => r['value'] == key,
      orElse: () => {'value': key, 'label': key},
    );
    return found['label']!;
  }

  String _formatArticle(String body) {
    var text = body;
    text = text.replaceAll('[نام و نام خانوادگی پرسنل]',
        _employeeName.isNotEmpty ? _employeeName : '[نام پرسنل]');
    text = text.replaceAll('[کد پرسنلی]',
        _employeeNumber.isNotEmpty ? _employeeNumber : '[کد پرسنلی]');
    text = text.replaceAll('[علت تغییر حقوق]', _reasonLabel(_reason));
    text = text.replaceAll('[نوع تغییر حقوق]', 'افزایش / تغییر حقوق');
    text = text.replaceAll(
        '[واحد سازمانی]', _unit.isNotEmpty ? _unit : '[واحد سازمانی]');
    text = text.replaceAll(
        '[عنوان شغلی]', _position.isNotEmpty ? _position : '[عنوان شغلی]');
    text = text.replaceAll('[تاریخ اجرای تغییر]', formatJalaliIso(_effectiveDate));
    text = text.replaceAll('[تاریخ صدور حکم]', 'پس از صدور رسمی');
    text = text.replaceAll('[نام قانونی شرکت]', widget.company);
    text = text.replaceAll('[نام نماینده قانونی]', 'نماینده مجاز شرکت');
    text = text.replaceAll('[سمت نماینده قانونی]', 'مدیر عامل');
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalaryChangeOrdersCubit, SalaryChangeOrdersState>(
      listener: (context, state) {
        if (state.publishedTemplate != null) {
          _syncTemplateFromState(state.publishedTemplate);
        }
      },
      builder: (context, state) {
        final title = _mode == _SalaryChangeViewMode.list
            ? 'احکام تغییر حقوق و مزایا'
            : _mode == _SalaryChangeViewMode.form
                ? 'صدور حکم تغییر حقوق'
                : _mode == _SalaryChangeViewMode.preview
                    ? 'پیش‌نمایش چاپ حکم'
                    : 'قالب حکم تغییر حقوق و مزایا';

        final subtitle = _mode == _SalaryChangeViewMode.list
            ? 'احکام کارگزینی / تغییر حقوق و مزایا'
            : _mode == _SalaryChangeViewMode.form
                ? 'احکام کارگزینی / حکم جدید'
                : _mode == _SalaryChangeViewMode.preview
                    ? 'احکام کارگزینی / پیش‌نمایش چاپ'
                    : 'احکام کارگزینی / ویرایش قالب';

        return Scaffold(
          backgroundColor: AsoudColors.background,
          appBar: AsoudHeader(
            title: title,
            subtitle: subtitle,
            action: _mode != _SalaryChangeViewMode.list
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() => _mode = _SalaryChangeViewMode.list);
                    },
                  )
                : null,
          ),
          body: HrTemplateStatus(
            error: state.templateError,
            onRetry: () => context.read<SalaryChangeOrdersCubit>().load(refresh: true),
            child: _buildBody(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, SalaryChangeOrdersState state) {
    switch (_mode) {
      case _SalaryChangeViewMode.list:
        return _buildListView(context, state);
      case _SalaryChangeViewMode.form:
        return _buildFormView(context, state);
      case _SalaryChangeViewMode.preview:
        return _buildPreviewView(context, state);
      case _SalaryChangeViewMode.templateBuilder:
        return _buildTemplateBuilderView(context, state);
    }
  }

  Widget _buildListView(
      BuildContext context, SalaryChangeOrdersState state) {
    return RefreshIndicator(
      onRefresh: () =>
          context.read<SalaryChangeOrdersCubit>().load(refresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Action card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AsoudColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const AsoudIconBox(
                        icon: Icons.trending_up, color: AsoudColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('مدیریت احکام تغییر حقوق',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                              'صدور حکم جدید، پیگیری وضعیت و اعمال بر سیستم حقوق',
                              style: TextStyle(
                                  fontSize: 11, color: AsoudColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.canIssue) ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AsoudColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('＋ حکم تغییر حقوق جدید'),
                  onPressed: () {
                    _startNewOrder(state);
                  },
                ),
                const SizedBox(height: 8),
                if (widget.canDesign) OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AsoudColors.primary,
                    side: const BorderSide(color: AsoudColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('ویرایش و انتشار قالب حکم'),
                  onPressed: () {
                    setState(
                        () => _mode = _SalaryChangeViewMode.templateBuilder);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search and Filters Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AsoudColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'نام، کد پرسنلی یا شماره حکم...',
                    hintStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AsoudColors.border),
                    ),
                  ),
                  onChanged: (val) =>
                      context.read<SalaryChangeOrdersCubit>().setSearch(val),
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: state.statusFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'وضعیت تأیید',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AsoudColors.border),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('همه وضعیت‌ها')),
                        DropdownMenuItem(
                            value: 'draft', child: Text('پیش‌نویس')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('در جریان')),
                        DropdownMenuItem(
                            value: 'final', child: Text('نهایی')),
                        DropdownMenuItem(
                            value: 'rejected', child: Text('رد شده')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          context
                              .read<SalaryChangeOrdersCubit>()
                              .setStatusFilter(val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: state.applicationStatusFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'وضعیت اعمال مالی',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AsoudColors.border),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text('همه وضعیت‌های مالی')),
                        DropdownMenuItem(
                            value: 'not_applied',
                            child: Text('اعمال‌نشده بر حقوق')),
                        DropdownMenuItem(
                            value: 'applied',
                            child: Text('اعمال‌شده بر حقوق')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          context
                              .read<SalaryChangeOrdersCubit>()
                              .setApplicationStatusFilter(val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${toPersianDigits(state.orders.length.toString())} حکم یافت شد',
                  style:
                      const TextStyle(fontSize: 11, color: AsoudColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Orders List
          if (state.status == SalaryChangeOrdersStatus.loading &&
              state.orders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (state.status == SalaryChangeOrdersStatus.error &&
              state.orders.isEmpty)
            ErrorState(
              failure: state.errorMessage ?? 'خطا در دریافت احکام.',
              onRetry: () =>
                  context.read<SalaryChangeOrdersCubit>().load(refresh: true),
            )
          else if (state.orders.isEmpty)
            const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'حکمی یافت نشد',
              description:
                  'برای صدور اولین حکم تغییر حقوق، دکمه «حکم جدید» را انتخاب کنید.',
            )
          else
            ...state.orders.map((order) => _buildOrderCard(context, order)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
      BuildContext context, SalaryChangeOrderSummary order) {
    Color statusBg;
    Color statusColor;
    final s = order.status.toLowerCase().trim();
    if (order.isFinal || s == 'final' || s == 'approved' || s == 'completed') {
      statusBg = AsoudColors.successSurface;
      statusColor = AsoudColors.success;
    } else if (order.isPending || s == 'pending' || s == 'progress' || s == 'submitted' || s == 'in_progress' || s == 'in progress' || s == 'open') {
      statusBg = AsoudColors.warningSurface;
      statusColor = AsoudColors.warning;
    } else if (s == 'rejected' || s == 'cancelled' || s == 'failed') {
      statusBg = AsoudColors.dangerSurface;
      statusColor = AsoudColors.danger;
    } else {
      statusBg = const Color(0xFFEDF2F8);
      statusColor = const Color(0xFF607D9B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AsoudColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.employeeName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (order.isApplied
                              ? AsoudColors.success
                              : AsoudColors.muted)
                          .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.applicationStatusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: order.isApplied
                            ? AsoudColors.success
                            : AsoudColors.muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'شماره: ${order.number.isNotEmpty ? toPersianDigits(order.number) : "پیش‌نویس"} · '
            'تاریخ اجرا: ${formatJalaliIso(order.effectiveDate)} · علت: ${order.reasonLabel}',
            style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (widget.canIssue && order.isDraft)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AsoudColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('✎ ادامه ویرایش'),
                  onPressed: () => _editDraftOrder(order),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AsoudColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.visibility, size: 14),
                  label: const Text('◉ مشاهده و بازبینی'),
                  onPressed: () => _viewOrderDetail(order),
                ),
              TextButton.icon(
                icon: const Icon(Icons.print, size: 14),
                label: const Text('▤ چاپ'),
                onPressed: () => _printOrder(order),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startNewOrder(SalaryChangeOrdersState state) {
    setState(() {
      _mode = _SalaryChangeViewMode.form;
      _orderId = null;
      _revision = 0;
      _personId = '';
      _employeeName = '';
      _employeeNumber = '';
      _unit = '';
      _position = '';
      _reason = 'annual';
      _description = '';
      _effectiveDate = DateTime.now().toIso8601String().split('T').first;
      _validationMessage = null;
      _amountControllers.clear();
      for (final row in _builderComparisonRows) {
        final id = row['id'] ?? '';
        _amountControllers[id] = TextEditingController();
      }
    });
  }

  void _editDraftOrder(SalaryChangeOrderSummary order) async {
    final cubit = context.read<SalaryChangeOrdersCubit>();
    await cubit.loadOrder(order.name);
    final detail = cubit.state.currentOrder;
    if (detail != null && mounted) {
      setState(() {
        _mode = _SalaryChangeViewMode.form;
        _orderId = detail.name;
        _revision = detail.revision;
        _personId = detail.employee;
        _employeeName = detail.employeeName;
        _employeeNumber = detail.employeeNumber;
        _unit = detail.department;
        _position = detail.designation;
        _reason = detail.reason;
        _description = detail.description;
        _effectiveDate = detail.effectiveDate;
        _validationMessage = null;
        _amountControllers.clear();
        for (final row in detail.comparisonRows) {
          _amountControllers[row.id] = TextEditingController(
            text: row.newAmount != null ? row.newAmount.toString() : '',
          );
        }
      });
      cubit.loadPayroll(employee: _personId, effectiveDate: _effectiveDate);
    }
  }

  void _viewOrderDetail(SalaryChangeOrderSummary order) async {
    final cubit = context.read<SalaryChangeOrdersCubit>();
    await cubit.loadOrder(order.name);
    final detail = cubit.state.currentOrder;
    if (detail != null && mounted) {
      setState(() {
        _mode = _SalaryChangeViewMode.preview;
        _orderId = detail.name;
        _revision = detail.revision;
        _personId = detail.employee;
        _employeeName = detail.employeeName;
        _employeeNumber = detail.employeeNumber;
        _unit = detail.department;
        _position = detail.designation;
        _reason = detail.reason;
        _description = detail.description;
        _effectiveDate = detail.effectiveDate;
      });
      cubit.loadPrint(detail.name);
    }
  }

  void _printOrder(SalaryChangeOrderSummary order) async {
    final cubit = context.read<SalaryChangeOrdersCubit>();
    await cubit.loadOrder(order.name);
    if (mounted) {
      setState(() {
        _mode = _SalaryChangeViewMode.preview;
        _orderId = order.name;
      });
      cubit.loadPrint(order.name);
    }
  }

  Widget _buildFormView(
      BuildContext context, SalaryChangeOrdersState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Notice Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AsoudColors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AsoudColors.primary.withValues(alpha: .2)),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle, size: 16, color: AsoudColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'قالب حکم تغییر حقوق بارگذاری شده است — ۶ ماده مصوب؛ جدول مقایسه حقوق قبلی و جدید.',
                  style: TextStyle(
                      fontSize: 11,
                      color: AsoudColors.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Employee picker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AsoudColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('۱. مشخصات پرسنل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (state.peopleLoading) const LinearProgressIndicator(),
              if (state.peopleError != null) ...[
                Text(state.peopleError!, style: const TextStyle(color: AsoudColors.danger)),
                TextButton(
                  onPressed: state.peopleLoading ? null
                      : () => context.read<SalaryChangeOrdersCubit>().loadPeople(),
                  child: const Text('دریافت دوباره پرسنل'),
                ),
              ],
              DropdownButtonFormField<String>(
                key: const ValueKey('salary-order-personnel'),
                initialValue: _personId.isNotEmpty ? _personId : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'انتخاب پرسنل *',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: state.people
                    .map((p) => DropdownMenuItem(
                          value: p.name,
                          child: Text('${p.displayName} — ${p.employeeNumber}'),
                        ))
                    .toList(),
                onChanged: state.peopleLoading || state.peopleError != null ? null : (val) {
                  if (val != null) {
                    final p = state.people
                        .firstWhere((element) => element.name == val);
                    setState(() {
                      _personId = p.name;
                      _employeeName = p.displayName;
                      _employeeNumber = p.employeeNumber;
                      _unit = p.department;
                      _position = p.designation;
                    });
                    context.read<SalaryChangeOrdersCubit>().loadPayroll(
                          employee: p.name,
                          effectiveDate: _effectiveDate,
                        );
                  }
                },
              ),
              if (_personId.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AsoudColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نام و نام خانوادگی: $_employeeName',
                          style: const TextStyle(fontSize: 11)),
                      Text('کد پرسنلی: ${toPersianDigits(_employeeNumber)}',
                          style: const TextStyle(fontSize: 11)),
                      Text('واحد سازمانی: ${_unit.isNotEmpty ? _unit : "—"}',
                          style: const TextStyle(fontSize: 11)),
                      Text(
                          'عنوان شغلی: ${_position.isNotEmpty ? _position : "—"}',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Order details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AsoudColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('۲. مشخصات تغییر حقوق',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'علت تغییر *',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: _reasons
                    .map((r) => DropdownMenuItem(
                          value: r['value'],
                          child: Text(r['label']!),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _reason = val);
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showAsoudJalaliPicker(context);
                  if (picked != null && context.mounted) {
                    final formatted = picked.toIso8601String().split('T').first;
                    setState(() => _effectiveDate = formatted);
                    if (_personId.isNotEmpty) {
                      context.read<SalaryChangeOrdersCubit>().loadPayroll(
                            employee: _personId,
                            effectiveDate: formatted,
                          );
                    }
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاریخ اجرای تغییر (شمسی) *',
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(formatJalaliIso(_effectiveDate)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _description,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'شرح علت و مستند تغییر *',
                  hintText: 'توضیحات و مستند مربوط به افزایش یا تغییر حقوق',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) => _description = val,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Comparison Table (Article 4)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AsoudColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('۳. مقایسه حقوق و مزایا',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'جدول ماده ۴؛ اطلاعات قبلی فقط‌خواندنی و مبلغ جدید پیشنهادی',
                style: TextStyle(fontSize: 11, color: AsoudColors.muted),
              ),
              const SizedBox(height: 12),
              if (_personId.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'ابتدا پرسنل را انتخاب کنید تا مبالغ قبلی و فیلدهای مبلغ جدید ظاهر شوند.',
                    style: TextStyle(fontSize: 11, color: AsoudColors.muted),
                  ),
                )
              else
                ..._buildComparisonRowsList(state),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Approved 6 Articles Accordion
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AsoudColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('۴. مفاد مصوب حکم (۶ ماده)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._builderArticles.asMap().entries.map((entry) {
                final idx = entry.key;
                final art = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AsoudColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ماده ${toPersianDigits((idx + 1).toString())}: ${art["title"]}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AsoudColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatArticle(art['body'] ?? ''),
                        style: const TextStyle(fontSize: 10, height: 1.5),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_validationMessage != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AsoudColors.danger.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _validationMessage!,
              style: const TextStyle(fontSize: 11, color: AsoudColors.danger),
            ),
          ),

        // Buttons
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AsoudColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => _submitDraft(context),
          child: const Text('ذخیره پیش‌نویس'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AsoudColors.primary,
            side: const BorderSide(color: AsoudColors.primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => _goToPreview(context),
          child: const Text('پیش‌نمایش چاپ و ارسال'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _mode = _SalaryChangeViewMode.list),
          child: const Text('انصراف و بازگشت'),
        ),
      ],
    );
  }

  List<Widget> _buildComparisonRowsList(SalaryChangeOrdersState state) {
    final widgets = <Widget>[];
    int monthlyPrevSum = 0;
    int monthlyNewSum = 0;
    bool hasMonthly = false;
    bool anyIncomplete = false;

    for (var i = 0; i < _builderComparisonRows.length; i++) {
      final row = _builderComparisonRows[i];
      final id = row['id'] ?? '';
      final title = row['title'] ?? '';
      final period = row['period'] ?? 'monthly';
      final periodLabel = period == 'yearly'
          ? 'سالانه'
          : period == 'one_off'
              ? 'یک‌باره'
              : 'ماهانه';

      final serverRow = state.currentPayroll?.rows.firstWhere(
        (r) => r.id == id || r.oldRef == row['old_ref'],
        orElse: () => SalaryChangeComparisonRow(
          id: id,
          title: title,
          period: period,
          periodLabel: periodLabel,
          oldRef: row['old_ref'] ?? '',
          newRef: row['new_ref'] ?? '',
          previousAmount: null,
          state: 'missing',
        ),
      );

      final prevAmount = serverRow?.previousAmount;
      final ctrl =
          _amountControllers.putIfAbsent(id, () => TextEditingController());
      final newText = ctrl.text.trim();
      final newAmount = int.tryParse(newText.replaceAll(',', ''));

      int? diff;
      String percentStr = '—';
      if (prevAmount != null && newAmount != null) {
        diff = newAmount - prevAmount;
        if (prevAmount == 0) {
          percentStr = 'قابل محاسبه نیست';
        } else {
          final pct = (diff / prevAmount) * 100;
          final sign = pct > 0 ? '+' : '';
          percentStr = '$sign${toPersianDigits(pct.toStringAsFixed(1))}٪';
        }
      } else {
        anyIncomplete = true;
      }

      if (period == 'monthly' && prevAmount != null && newAmount != null) {
        hasMonthly = true;
        monthlyPrevSum += prevAmount;
        monthlyNewSum += newAmount;
      }

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AsoudColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AsoudColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${toPersianDigits((i + 1).toString())}. $title',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AsoudColors.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(periodLabel,
                        style: const TextStyle(
                            fontSize: 9, color: AsoudColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مبلغ قبلی',
                            style: TextStyle(
                                fontSize: 10, color: AsoudColors.muted)),
                        Text(
                          prevAmount != null
                              ? '${toPersianDigits(prevAmount.toString())} ریال'
                              : 'اطلاعات موجود نیست',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: prevAmount == null
                                ? AsoudColors.danger
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مبلغ جدید',
                            style: TextStyle(
                                fontSize: 10, color: AsoudColors.muted)),
                        Text(
                          newAmount != null
                              ? '${toPersianDigits(newAmount.toString())} ریال'
                              : 'ثبت نشده',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('میزان تغییر',
                            style: TextStyle(
                                fontSize: 10, color: AsoudColors.muted)),
                        Text(
                          diff != null
                              ? '${diff > 0 ? "+" : ""}${toPersianDigits(diff.toString())} ($percentStr)'
                              : '—',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: diff == null
                                ? AsoudColors.muted
                                : diff >= 0
                                    ? AsoudColors.success
                                    : AsoudColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'مبلغ جدید پیشنهادی (ریال)',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Text(
                '↗ منبع قبلی: ${row["old_ref"]} · جدید: ${row["new_ref"]}',
                style: const TextStyle(fontSize: 9, color: AsoudColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    // Totals card
    if (hasMonthly) {
      final monthlyDiff = monthlyNewSum - monthlyPrevSum;
      widgets.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AsoudColors.primary.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AsoudColors.primary.withValues(alpha: .2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('جمع ماهانه قبلی:',
                      style: TextStyle(fontSize: 11)),
                  Text('${toPersianDigits(monthlyPrevSum.toString())} ریال',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('جمع ماهانه جدید:',
                      style: TextStyle(fontSize: 11)),
                  Text('${toPersianDigits(monthlyNewSum.toString())} ریال',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('خالص تغییر ماهانه:',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(
                    '${monthlyDiff > 0 ? "+" : ""}${toPersianDigits(monthlyDiff.toString())} ریال',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: monthlyDiff >= 0
                          ? AsoudColors.success
                          : AsoudColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (anyIncomplete) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'اطلاعات یک یا چند قلم ناقص است؛ تا تکمیل از منبع معتبر ثبت نهایی مجاز نیست. صفر جایگزین مبلغ ناموجود نمی‌شود.',
            style: TextStyle(
                fontSize: 10, color: AsoudColors.warning.withValues(alpha: .9)),
          ),
        ),
      );
    }

    return widgets;
  }

  void _submitDraft(BuildContext context) async {
    if (_personId.isEmpty) {
      setState(() => _validationMessage = 'لطفاً ابتدا پرسنل را انتخاب کنید.');
      return;
    }
    final comparisonRows = _buildPayloadRows();
    final cubit = context.read<SalaryChangeOrdersCubit>();
    final saved = await cubit.saveDraft(
      requestId: 'draft_${DateTime.now().millisecondsSinceEpoch}',
      revision: _revision,
      order: _orderId,
      employee: _personId,
      effectiveDate: _effectiveDate,
      reason: _reason,
      description: _description,
      unit: _unit,
      position: _position,
      comparisonRows: comparisonRows,
    );
    if (saved != null && mounted && context.mounted) {
      setState(() {
        _orderId = saved.name;
        _revision = saved.revision;
        _validationMessage = null;
        _mode = _SalaryChangeViewMode.list;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پیش‌نویس حکم با موفقیت ذخیره شد.')),
      );
    }
  }

  void _goToPreview(BuildContext context) {
    if (_personId.isEmpty) {
      setState(() => _validationMessage = 'لطفاً ابتدا پرسنل را انتخاب کنید.');
      return;
    }
    setState(() {
      _mode = _SalaryChangeViewMode.preview;
    });
    final comparisonRows = _buildPayloadRows();
    final cubit = context.read<SalaryChangeOrdersCubit>();
    cubit
        .saveDraft(
      requestId: 'draft_${DateTime.now().millisecondsSinceEpoch}',
      revision: _revision,
      order: _orderId,
      employee: _personId,
      effectiveDate: _effectiveDate,
      reason: _reason,
      description: _description,
      unit: _unit,
      position: _position,
      comparisonRows: comparisonRows,
    )
        .then((saved) {
      if (saved != null && mounted) {
        setState(() {
          _orderId = saved.name;
          _revision = saved.revision;
        });
      }
    });
  }

  List<Map<String, dynamic>> _buildPayloadRows() {
    return _builderComparisonRows.map((r) {
      final id = r['id'] ?? '';
      final ctrl = _amountControllers[id];
      final newAmt = int.tryParse(ctrl?.text.replaceAll(',', '').trim() ?? '');
      return {
        'id': id,
        'title': r['title'],
        'period': r['period'] ?? 'monthly',
        'old_ref': r['old_ref'],
        'new_ref': r['new_ref'],
        'new_amount': newAmt,
      };
    }).toList();
  }

  Widget _buildPreviewView(
      BuildContext context, SalaryChangeOrdersState state) {
    final order = state.currentOrder;
    final isFinal = order?.isFinal ?? false;
    final isPending = order?.isPending ?? false;
    final isApplied = order?.isApplied ?? false;

    int monthlyPrevSum = 0;
    int monthlyNewSum = 0;
    bool anyIncomplete = false;

    for (final row in _builderComparisonRows) {
      final id = row['id'] ?? '';
      final period = row['period'] ?? 'monthly';
      final prevAmount = state.currentPayroll?.rows
          .firstWhere((r) => r.id == id || r.oldRef == row['old_ref'],
              orElse: () => SalaryChangeComparisonRow(
                    id: id,
                    title: '',
                    period: period,
                    periodLabel: '',
                    oldRef: '',
                    newRef: '',
                    previousAmount: null,
                    state: 'missing',
                  ))
          .previousAmount;
      final newText = _amountControllers[id]?.text.trim() ?? '';
      final newAmount = int.tryParse(newText.replaceAll(',', ''));

      if (prevAmount != null && newAmount != null) {
        if (period == 'monthly') {
          monthlyPrevSum += prevAmount;
          monthlyNewSum += newAmount;
        }
      } else {
        anyIncomplete = true;
      }
    }
    final monthlyDiff = monthlyNewSum - monthlyPrevSum;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Simulated Paper Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AsoudColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                widget.company,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'حکم افزایش یا تغییر حقوق و مزایا',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AsoudColors.primary),
              ),
              const Divider(),

              // Draft watermark if not final
              if (!isFinal)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF2DFBC)),
                  ),
                  child: Text(
                    isPending ? 'در جریان تأیید ـ فاقد اعتبار نهایی' : 'پیش‌نویس ـ فاقد اعتبار نهایی',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB05228)),
                  ),
                ),

              // Meta row
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'شماره حکم: ${order != null && order.number.isNotEmpty ? toPersianDigits(order.number) : "پیش‌نویس"}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text('تاریخ اجرا: ${formatJalaliIso(_effectiveDate)}',
                      style: const TextStyle(fontSize: 10)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AsoudColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text('پرسنل: $_employeeName',
                        style: const TextStyle(fontSize: 10)),
                    Text('کد: ${toPersianDigits(_employeeNumber)}',
                        style: const TextStyle(fontSize: 10)),
                    Text('سمت: ${_position.isNotEmpty ? _position : "—"}',
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Rendered Articles
              ..._builderArticles.asMap().entries.map((entry) {
                final idx = entry.key;
                final art = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ماده ${toPersianDigits((idx + 1).toString())} ـ ${art["title"]}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AsoudColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatArticle(art['body'] ?? ''),
                        style: const TextStyle(fontSize: 10, height: 1.6),
                        textAlign: TextAlign.justify,
                      ),
                      if (art['id'] == 'salary_comparison') ...[
                        const SizedBox(height: 8),
                        Table(
                          border: TableBorder.all(color: const Color(0xFFD3DCE6)),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF2F5F9)),
                              children: const [
                                Padding(padding: EdgeInsets.all(6), child: Text('قلم', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('قبلی (ریال)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('جدید (ریال)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('تغییر', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            ..._builderComparisonRows.map((r) {
                              final id = r['id'] ?? '';
                              final rowName = r['title'] ?? r['name'] ?? id;
                              final prev = state.currentPayroll?.rows
                                  .firstWhere((item) => item.id == id || item.oldRef == r['old_ref'],
                                      orElse: () => SalaryChangeComparisonRow(
                                            id: id,
                                            title: '',
                                            period: 'monthly',
                                            periodLabel: '',
                                            oldRef: '',
                                            newRef: '',
                                            previousAmount: null,
                                            state: 'missing',
                                          ))
                                  .previousAmount;
                              final newText = _amountControllers[id]?.text.trim() ?? '';
                              final next = int.tryParse(newText.replaceAll(',', ''));
                              final delta = (prev != null && next != null) ? next - prev : null;
                              return TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(6), child: Text(rowName, style: const TextStyle(fontSize: 9.5))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(prev != null ? toPersianDigits(prev.toString()) : 'ناموجود', style: const TextStyle(fontSize: 9.5))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(next != null ? toPersianDigits(next.toString()) : 'ثبت نشده', style: const TextStyle(fontSize: 9.5))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(delta != null ? '${delta >= 0 ? "+" : ""}${toPersianDigits(delta.toString())}' : '—', style: const TextStyle(fontSize: 9.5))),
                                ],
                              );
                            }),
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF2F5F9)),
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Text('جمع ماهانه', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    anyIncomplete ? 'ناقص' : toPersianDigits(monthlyPrevSum.toString()),
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    anyIncomplete ? 'ناقص' : toPersianDigits(monthlyNewSum.toString()),
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    anyIncomplete ? 'ناقص' : '${monthlyDiff >= 0 ? "+" : ""}${toPersianDigits(monthlyDiff.toString())}',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (anyIncomplete)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8ED),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF2DFBC)),
                              ),
                              child: const Text(
                                'اطلاعات یک یا چند قلم ناقص است. تا تکمیل از منبع معتبر، ثبت نهایی مجاز نیست؛ صفر جایگزین مبلغ ناموجود نمی‌شود.',
                                style: TextStyle(fontSize: 10, color: Color(0xFF8C631B)),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 16,
                runSpacing: 8,
                children: const [
                  Text('مقام تأییدکننده / صادرکننده\nامضا و مهر',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9)),
                  Text('ملاحظه و اطلاع پرسنل\nامضا و تاریخ',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'چاپ پیش‌نویس و حکم در جریان، با برچسب «فاقد اعتبار نهایی» انجام می‌شود. احکام نمونه صرفاً برای نمایش‌اند.',
          style: TextStyle(fontSize: 10, color: AsoudColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Action Buttons
        if (widget.canIssue && !isFinal && !isPending)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AsoudColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              final cubit = context.read<SalaryChangeOrdersCubit>();
              var targetId = _orderId;
              var targetRev = _revision;
              if (targetId == null) {
                final comparisonRows = _buildPayloadRows();
                final saved = await cubit.saveDraft(
                  requestId: 'draft_${DateTime.now().millisecondsSinceEpoch}',
                  revision: _revision,
                  order: _orderId,
                  employee: _personId,
                  effectiveDate: _effectiveDate,
                  reason: _reason,
                  description: _description,
                  unit: _unit,
                  position: _position,
                  comparisonRows: comparisonRows,
                );
                if (saved != null) {
                  targetId = saved.name;
                  targetRev = saved.revision;
                }
              }
              if (targetId != null) {
                final ok = await cubit.sendForReview(
                  name: targetId,
                  revision: targetRev,
                  requestId: 'rev_${DateTime.now().millisecondsSinceEpoch}',
                );
                if (ok && mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('حکم برای بررسی و گردش‌کار ارسال شد.')),
                  );
                  setState(() => _mode = _SalaryChangeViewMode.list);
                }
              }
            },
            child: const Text('ارسال جهت بررسی و گردش‌کار'),
          ),
        if (widget.canIssue && isPending && _orderId != null) ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AsoudColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final cubit = context.read<SalaryChangeOrdersCubit>();
                final ok = await cubit.approveOrder(
                  name: _orderId!,
                  revision: _revision,
                  requestId: 'app_${DateTime.now().millisecondsSinceEpoch}',
                );
                if (ok && mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('حکم کارگزینی با موفقیت نهایی و تأیید شد.')),
                  );
                  setState(() => _mode = _SalaryChangeViewMode.list);
                }
              },
              child: const Text('تأیید نهایی حکم'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AsoudColors.danger,
                side: const BorderSide(color: AsoudColors.danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final cubit = context.read<SalaryChangeOrdersCubit>();
                final ok = await cubit.rejectOrder(
                  name: _orderId!,
                  revision: _revision,
                  reason: 'رد توسط مقام صادرکننده',
                );
                if (ok && mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حکم رد شد.')),
                  );
                  setState(() => _mode = _SalaryChangeViewMode.list);
                }
              },
              child: const Text('رد حکم'),
            ),
          ],
          if (widget.canExecutePayroll && isFinal && !isApplied) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AsoudColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.account_balance_wallet, size: 18),
              label: const Text('اعمال بر سیستم حقوق و دستمزد'),
              onPressed: () async {
                final cubit = context.read<SalaryChangeOrdersCubit>();
                final ok = await cubit.applyToPayroll(
                  name: _orderId!,
                  operationId: 'salary-change-$_orderId',
                );
                if (ok && mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('تغییرات حقوق با موفقیت بر سیستم ثبت شد.')),
                  );
                  setState(() => _mode = _SalaryChangeViewMode.list);
                }
              },
            ),
          ],
          if (isApplied)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AsoudColors.success.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '✓ تغییرات این حکم بر سیستم حقوق و دستمزد اعمال شده است.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AsoudColors.success),
              ),
            ),
          const SizedBox(height: 8),
          HrDocumentPrintButton(
            label: 'چاپ سند',
            loadHtml: () async {
              if (_orderId == null) return '';
              final document = await context.read<SalaryChangeOrdersCubit>().repository.printOrder(name: _orderId!);
              return document.html;
            },
          ),
          const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _mode = _SalaryChangeViewMode.list),
          child: const Text('بازگشت به فهرست'),
        ),
      ],
    );
  }

  Widget _buildTemplateBuilderView(
      BuildContext context, SalaryChangeOrdersState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tabs: ویرایش قالب (0) / پیش‌نمایش سند (1)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _builderTab = 0),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _builderTab == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _builderTab == 0
                          ? [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 4)]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'ویرایش قالب',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _builderTab == 0 ? FontWeight.bold : FontWeight.normal,
                        color: _builderTab == 0 ? AsoudColors.primary : AsoudColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _builderTab = 1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _builderTab == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _builderTab == 1
                          ? [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 4)]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'پیش‌نمایش سند',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _builderTab == 1 ? FontWeight.bold : FontWeight.normal,
                        color: _builderTab == 1 ? AsoudColors.primary : AsoudColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_builderTab == 0) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AsoudColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('قالب حکم تغییر حقوق و مزایا',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  '۶ ماده پیش‌فرض و جدول تکرارشونده مقایسه؛ تغییرات در احکام بعدی اعمال می‌شود.',
                  style: TextStyle(fontSize: 11, color: AsoudColors.muted),
                ),
                const SizedBox(height: 16),
                ..._builderArticles.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final art = entry.value;
                  final isExpanded = _expandedArticleIndex == idx;
                  final isEditing = _editingArticleIndex == idx;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isEditing ? Colors.white : AsoudColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isEditing ? const Color(0xFF8DBDEB) : AsoudColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _expandedArticleIndex = isExpanded ? null : idx;
                              if (!isExpanded) _editingArticleIndex = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF5FC),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    toPersianDigits((idx + 1).toString()),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Color(0xFF2379BE),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ماده ${toPersianDigits((idx + 1).toString())}: ${art["title"]}',
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: const Color(0xFF748398),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 1, color: Color(0xFFE8ECF2)),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: isEditing
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _builderArticleTitleController,
                                        decoration: InputDecoration(
                                          labelText: 'عنوان ماده',
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _builderArticleBodyController,
                                        maxLines: 4,
                                        decoration: InputDecoration(
                                          labelText: 'متن ماده *',
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.all(10),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.add_circle_outline, size: 16),
                                        label: const Text('درج فیلد در متن ماده',
                                            style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                            foregroundColor: AsoudColors.primary),
                                        onPressed: () => _showSalaryFieldPicker(
                                            _builderArticleBodyController),
                                      ),
                                      if (art['id'] == 'salary_comparison') ...[
                                        const SizedBox(height: 12),
                                        const Divider(),
                                        const Text('ردیف‌های مقایسه حقوق و مزایا:',
                                            style: TextStyle(
                                                fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        ..._builderComparisonRows.asMap().entries.map((rEntry) {
                                          final rIdx = rEntry.key;
                                          final r = rEntry.value;
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AsoudColors.border),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'ردیف ${toPersianDigits((rIdx + 1).toString())}: ${r["title"] ?? ""}',
                                                      style: const TextStyle(
                                                          fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline,
                                                          size: 16, color: AsoudColors.danger),
                                                      onPressed: _builderComparisonRows.length <= 1
                                                          ? null
                                                          : () => setState(() =>
                                                              _builderComparisonRows.removeAt(rIdx)),
                                                    ),
                                                  ],
                                                ),
                                                TextFormField(
                                                  initialValue: r['title'],
                                                  decoration: const InputDecoration(
                                                    labelText: 'عنوان قلم حقوق و مزایا',
                                                    contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 6),
                                                  ),
                                                  onChanged: (val) => r['title'] = val,
                                                ),
                                                DropdownButtonFormField<String>(
                                                  initialValue: r['period'] ?? 'monthly',
                                                  decoration: const InputDecoration(
                                                    labelText: 'دوره پرداخت',
                                                    contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 6),
                                                  ),
                                                  items: const [
                                                    DropdownMenuItem(
                                                        value: 'monthly', child: Text('ماهانه')),
                                                    DropdownMenuItem(
                                                        value: 'yearly', child: Text('سالانه')),
                                                    DropdownMenuItem(
                                                        value: 'one_off', child: Text('یک‌باره')),
                                                  ],
                                                  onChanged: (val) =>
                                                      setState(() => r['period'] = val ?? 'monthly'),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.add, size: 14),
                                          label: const Text('افزودن ردیف حقوقی',
                                              style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            setState(() {
                                              final id = 'row_${_builderComparisonRows.length + 1}';
                                              _builderComparisonRows.add({
                                                'id': id,
                                                'key': id,
                                                'title': 'قلم جدید',
                                                'period': 'monthly',
                                                'old_ref': 'base_pay',
                                                'new_ref': 'base_pay_proposed',
                                              });
                                            });
                                          },
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AsoudColors.primary,
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: _saveEditArticle,
                                              child: const Text('ذخیره تغییرات'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  setState(() => _editingArticleIndex = null),
                                              child: const Text('انصراف'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        art['body'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 11, height: 1.8, color: Color(0xFF42556B)),
                                      ),
                                      if (art['id'] == 'salary_comparison') ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AsoudColors.border),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: _builderComparisonRows
                                                .map((r) => Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(r['title'] ?? '',
                                                              style: const TextStyle(
                                                                  fontSize: 10.5,
                                                                  fontWeight: FontWeight.bold)),
                                                          Text(
                                                            r['period'] == 'yearly'
                                                                ? 'سالانه'
                                                                : r['period'] == 'one_off'
                                                                    ? 'یک‌باره'
                                                                    : 'ماهانه',
                                                            style: const TextStyle(fontSize: 10),
                                                          ),
                                                        ],
                                                      ),
                                                    ))
                                                .toList(),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.arrow_upward, size: 16),
                                            onPressed: idx > 0 ? () => _moveArticle(idx, idx - 1) : null,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.arrow_downward, size: 16),
                                            onPressed: idx < _builderArticles.length - 1
                                                ? () => _moveArticle(idx, idx + 1)
                                                : null,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          const SizedBox(width: 4),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.edit_outlined, size: 14),
                                            label: const Text('ویرایش', style: TextStyle(fontSize: 11)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AsoudColors.primary,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                            ),
                                            onPressed: () => _beginEditArticle(idx),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                if (_showNewArticleForm) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF8DBDEB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('افزودن ماده جدید به قالب',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _newArticleTitleController,
                          decoration: const InputDecoration(
                            labelText: 'عنوان ماده جدید',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _newArticleBodyController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'متن ماده جدید',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: const Text('درج فیلد در ماده جدید', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(foregroundColor: AsoudColors.primary),
                          onPressed: () => _showSalaryFieldPicker(_newArticleBodyController),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AsoudColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _addNewArticle,
                                child: const Text('افزودن ماده'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _showNewArticleForm = false),
                                child: const Text('انصراف'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('افزودن ماده جدید'),
                    style: OutlinedButton.styleFrom(foregroundColor: AsoudColors.primary),
                    onPressed: () {
                      setState(() {
                        _showNewArticleForm = true;
                        _editingArticleIndex = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AsoudColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final cubit = context.read<SalaryChangeOrdersCubit>();
                    final ok = await cubit.publishTemplate({
                      'articles': _builderArticles,
                      'comparison_rows': _builderComparisonRows,
                    });
                    if (ok && mounted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'نسخه نهایی قالب با موفقیت ذخیره و منتشر شد.')),
                      );
                      setState(() => _mode = _SalaryChangeViewMode.list);
                    }
                  },
                  child: const Text('انتشار نسخه نهایی قالب'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      setState(() => _mode = _SalaryChangeViewMode.list),
                  child: const Text('بازگشت به فهرست'),
                ),
              ],
            ),
          ),
        ] else ...[
          // Tab 1: پیش‌نمایش سند (قالب)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AsoudColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.company,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'حکم افزایش / تغییر حقوق و مزایا',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AsoudColors.primary),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'پیش‌نمایش قالب ـ فاقد اعتبار نهایی',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB05228)),
                  ),
                ),
                const Divider(),
                ..._builderArticles.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final art = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ماده ${toPersianDigits((idx + 1).toString())} ـ ${art["title"]}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AsoudColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          art['body'] ?? '',
                          style: const TextStyle(fontSize: 10, height: 1.6),
                        ),
                        if (art['id'] == 'salary_comparison') ...[
                          const SizedBox(height: 8),
                          Table(
                            border: TableBorder.all(color: const Color(0xFFD3DCE6)),
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(color: Color(0xFFF2F5F9)),
                                children: const [
                                  Padding(padding: EdgeInsets.all(6), child: Text('قلم', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('قبلی (ریال)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('جدید (ریال)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('تغییر', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              ..._builderComparisonRows.map((r) => TableRow(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(6), child: Text(r['title'] ?? '', style: const TextStyle(fontSize: 9.5))),
                                      const Padding(padding: EdgeInsets.all(6), child: Text('[مبلغ قبلی]', style: TextStyle(fontSize: 9.5))),
                                      const Padding(padding: EdgeInsets.all(6), child: Text('[مبلغ جدید]', style: TextStyle(fontSize: 9.5))),
                                      const Padding(padding: EdgeInsets.all(6), child: Text('[اختلاف]', style: TextStyle(fontSize: 9.5))),
                                    ],
                                  )),
                              const TableRow(
                                decoration: BoxDecoration(color: Color(0xFFF2F5F9)),
                                children: [
                                  Padding(padding: EdgeInsets.all(6), child: Text('جمع ماهانه', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('[جمع قبلی]', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('[جمع جدید]', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('[تغییر کل]', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 16,
                  runSpacing: 8,
                  children: const [
                    Text('نام و امضای مقام صادرکننده\n...........................',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9)),
                    Text('مهر شرکت\n...........................',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: const Text('چاپ / ذخیره PDF پیش‌نمایش'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AsoudColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('پیش‌نمایش آماده چاپ است.')),
              );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() => _builderTab = 0),
            child: const Text('بازگشت به ویرایش قالب'),
          ),
        ],
      ],
    );
  }
}
