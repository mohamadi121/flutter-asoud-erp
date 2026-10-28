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
          body: _buildBody(context, state),
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
    Color statusColor;
    switch (order.status) {
      case 'final':
        statusColor = AsoudColors.success;
        break;
      case 'pending':
        statusColor = AsoudColors.primary;
        break;
      case 'rejected':
        statusColor = AsoudColors.danger;
        break;
      case 'draft':
      default:
        statusColor = AsoudColors.warning;
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
                      color: statusColor.withValues(alpha: .12),
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
              DropdownButtonFormField<String>(
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
                onChanged: (val) {
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
                    color: AsoudColors.danger.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AsoudColors.danger.withValues(alpha: .3)),
                  ),
                  child: const Text(
                    'پیش‌نویس ـ فاقد اعتبار نهایی',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AsoudColors.danger),
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
          OutlinedButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: const Text('چاپ سند'),
            onPressed: () async {
              if (_orderId != null) {
                await context
                    .read<SalaryChangeOrdersCubit>()
                    .loadPrint(_orderId!);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('سند آماده چاپ در مرورگر/پرینتر است.'),
                    backgroundColor: AsoudColors.success,
                  ),
                );
              }
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
                return Container(
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
                      TextFormField(
                        initialValue: art['title'],
                        decoration: InputDecoration(
                          labelText:
                              'ماده ${toPersianDigits((idx + 1).toString())}: ${art["title"]}',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) => art['title'] = val,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: art['body'],
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'متن ماده *',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) => art['body'] = val,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _fieldChip('[نام و نام خانوادگی پرسنل]', art),
                          _fieldChip('[کد پرسنلی]', art),
                          _fieldChip('[علت تغییر حقوق]', art),
                          _fieldChip('[تاریخ اجرای تغییر]', art),
                          _fieldChip('[عنوان شغلی]', art),
                          _fieldChip('[واحد سازمانی]', art),
                        ],
                      ),
                      if (art['id'] == 'salary_comparison') ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const Text('ردیف‌های مقایسه حقوق و مزایا:',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        ..._builderComparisonRows.map((r) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AsoudColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(r['title'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  Text('دوره: ${r["period"]}',
                                      style: const TextStyle(fontSize: 10)),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                );
              }),
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
      ],
    );
  }

  Widget _fieldChip(String label, Map<String, String> art) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 9)),
      onPressed: () {
        setState(() {
          art['body'] = '${art["body"] ?? ""} $label';
        });
      },
    );
  }
}
