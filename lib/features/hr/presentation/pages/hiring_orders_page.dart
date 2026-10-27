import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/capabilities.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_jalali_picker.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/hiring_order_repository.dart';
import '../cubit/hiring_orders_cubit.dart';

enum _HiringViewMode { list, form, preview, templateBuilder }

class HiringOrdersPage extends StatelessWidget {
  const HiringOrdersPage({
    required this.company,
    this.repository,
    this.capabilities,
    super.key,
  });

  final String company;
  final HiringOrderRepository? repository;
  final Capabilities? capabilities;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? HiringOrderRepository(context.read<FrappeApiClient>());
    return BlocProvider(
      create: (_) => HiringOrdersCubit(
        repository: repo,
        company: company,
      )..load()..loadPeople(),
      child: _HiringOrdersView(company: company, capabilities: capabilities),
    );
  }
}

class _HiringOrdersView extends StatefulWidget {
  const _HiringOrdersView({required this.company, this.capabilities});

  final String company;
  final Capabilities? capabilities;

  @override
  State<_HiringOrdersView> createState() => _HiringOrdersViewState();
}

class _HiringOrdersViewState extends State<_HiringOrdersView> {
  _HiringViewMode _mode = _HiringViewMode.list;

  // Form state
  String? _orderId;
  int _revision = 0;
  String _personId = '';
  String _employeeName = '';
  String _employeeNumber = '';
  String _employment = 'تمام‌وقت';
  String _effectiveDate = '1405/08/01';
  String _unit = '';
  String _position = '';
  String _location = '';
  String _note = '';
  String? _validationMessage;

  // Template builder state
  List<Map<String, String>> _builderArticles = [];
  List<Map<String, String>> _builderPayrollRows = [];

  @override
  void initState() {
    super.initState();
    _initDefaultTemplate();
  }

  void _initDefaultTemplate() {
    _builderArticles = [
      {
        'id': 'employee_details',
        'title': 'مشخصات پرسنل',
        'body': 'به موجب این حکم، [نام و نام خانوادگی پرسنل] با کد پرسنلی [کد پرسنلی] و مشخصات ثبت‌شده در پرونده منابع انسانی، مشمول مفاد این حکم می‌گردد.',
      },
      {
        'id': 'employment_effective_date',
        'title': 'نوع استخدام و تاریخ اجرا',
        'body': 'نوع استخدام [نوع استخدام] بوده و تاریخ اجرای حکم از [تاریخ اجرای حکم] تعیین می‌شود.',
      },
      {
        'id': 'organization_position',
        'title': 'واحد سازمانی و جایگاه شغلی',
        'body': 'نامبرده در [واحد سازمانی] و در جایگاه [عنوان شغلی]، در محل خدمت [محل خدمت] مشغول به کار خواهد بود.',
      },
      {
        'id': 'duties',
        'title': 'شرح وظایف و شرایط خدمت',
        'body': 'شرح وظایف، مسئولیت‌ها و شرایط خدمت مطابق شرح شغل مصوب و ضوابط جاری شرکت تعیین می‌شود.',
      },
      {
        'id': 'salary_benefits',
        'title': 'حقوق و مزایا',
        'body': 'حقوق و مزایای مرتبط با این حکم براساس اقلام متصل به سیستم حقوق و دستمزد و جدول زیر تعیین و نمایش داده می‌شود.',
      },
      {
        'id': 'issuing_authority',
        'title': 'مرجع صدور و تأیید حکم',
        'body': 'این حکم توسط [نام نماینده قانونی] با سمت [سمت نماینده قانونی] از طرف [نام قانونی شرکت] صادر می‌شود.',
      },
    ];
    _builderPayrollRows = [
      {
        'id': 'base_salary',
        'title': 'حقوق پایه',
        'period': 'monthly',
        'field_ref': 'base',
      },
    ];
  }

  void _openNewForm() {
    setState(() {
      _mode = _HiringViewMode.form;
      _orderId = null;
      _revision = 0;
      _personId = '';
      _employeeName = '';
      _employeeNumber = '';
      _employment = 'تمام‌وقت';
      _effectiveDate = '1405/08/01';
      _unit = '';
      _position = '';
      _location = '';
      _note = '';
      _validationMessage = null;
    });
  }

  void _openEditForm(HiringOrderDetail order) {
    setState(() {
      _mode = _HiringViewMode.form;
      _orderId = order.name;
      _revision = order.revision;
      _personId = order.employee;
      _employeeName = order.employeeName;
      _employeeNumber = order.employeeNumber;
      _employment = order.values['employment']?.toString() ?? 'تمام‌وقت';
      _effectiveDate = order.effectiveDate.isNotEmpty ? order.effectiveDate : '1405/08/01';
      _unit = order.department;
      _position = order.designation;
      _location = order.location;
      _note = order.values['note']?.toString() ?? '';
      _validationMessage = null;
    });
  }

  bool _canSubmit(HiringOrdersState state) {
    return _personId.isNotEmpty &&
        _location.trim().isNotEmpty &&
        _effectiveDate.trim().isNotEmpty &&
        (state.currentPayroll == null || !state.currentPayroll!.hasMissing);
  }

  String _formatArticle(String body, HiringOrdersState state) {
    var text = body;
    final replacements = {
      'نام و نام خانوادگی پرسنل': _employeeName.isNotEmpty ? _employeeName : 'تکمیل نشده',
      'کد پرسنلی': _employeeNumber.isNotEmpty ? _employeeNumber : 'تکمیل نشده',
      'نوع استخدام': _employment,
      'تاریخ اجرای حکم': toPersianDigits(_effectiveDate),
      'واحد سازمانی': _unit.isNotEmpty ? _unit : 'تکمیل نشده',
      'عنوان شغلی': _position.isNotEmpty ? _position : 'تکمیل نشده',
      'محل خدمت': _location.isNotEmpty ? _location : 'تکمیل نشده',
      'نام نماینده قانونی': widget.company,
      'سمت نماینده قانونی': 'مدیریت عامل',
      'نام قانونی شرکت': widget.company,
    };
    for (final entry in replacements.entries) {
      text = text.replaceAll('[${entry.key}]', entry.value);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: BlocConsumer<HiringOrdersCubit, HiringOrdersState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AsoudColors.danger,
                ),
              );
            }
          },
          builder: (context, state) {
            return Scaffold(
              backgroundColor: AsoudColors.background,
              appBar: AsoudHeader(
                title: _mode == _HiringViewMode.list
                    ? 'احکام استخدام'
                    : _mode == _HiringViewMode.form
                        ? 'صدور حکم استخدام'
                        : _mode == _HiringViewMode.preview
                            ? 'پیش‌نمایش حکم استخدام'
                            : 'قالب حکم استخدام',
                subtitle: _mode == _HiringViewMode.list
                    ? 'احکام کارگزینی / حکم استخدام'
                    : _mode == _HiringViewMode.form
                        ? 'احکام استخدام / حکم جدید'
                        : _mode == _HiringViewMode.preview
                            ? 'احکام استخدام / بازبینی و چاپ'
                            : 'تنظیمات قالب مصوب',
                action: _mode != _HiringViewMode.list
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          setState(() {
                            _mode = _HiringViewMode.list;
                          });
                        },
                      )
                    : null,
              ),
              body: SafeArea(
                child: _buildBody(context, state),
              ),
            );
          },
        ),
      );

  Widget _buildBody(BuildContext context, HiringOrdersState state) {
    switch (_mode) {
      case _HiringViewMode.list:
        return _buildListView(context, state);
      case _HiringViewMode.form:
        return _buildFormView(context, state);
      case _HiringViewMode.preview:
        return _buildPreviewView(context, state);
      case _HiringViewMode.templateBuilder:
        return _buildTemplateBuilderView(context, state);
    }
  }

  // --- 1. LIST VIEW -----------------------------------------------------------

  Widget _buildListView(BuildContext context, HiringOrdersState state) {
    return FutureBuilder<Capabilities>(
      future: widget.capabilities != null
          ? Future.value(widget.capabilities)
          : capabilitiesOf(context),
      builder: (context, capsSnapshot) {
        final caps = capsSnapshot.data ?? widget.capabilities ?? Capabilities.full;
        final canManageTemplates = caps.canManageHiringTemplates;

        return RefreshIndicator(
          onRefresh: () => context.read<HiringOrdersCubit>().load(refresh: true),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Management card
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
                    const AsoudSectionTitle(
                      title: 'مدیریت احکام پرسنلی',
                      subtitle: 'ایجاد، پیگیری و چاپ احکام استخدام',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AsoudColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: _openNewForm,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            '＋ حکم جدید',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (canManageTemplates)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AsoudColors.primary,
                              side: const BorderSide(color: AsoudColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _mode = _HiringViewMode.templateBuilder;
                              });
                            },
                            icon: const Icon(Icons.tune, size: 18),
                            label: const Text('قالب حکم استخدام'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

          // Search & Filter card
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
                const AsoudSectionTitle(
                  title: 'فهرست احکام استخدام',
                  subtitle: 'جست‌وجو میان احکام ثبت‌شده',
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) => context.read<HiringOrdersCubit>().setSearch(val),
                  decoration: InputDecoration(
                    hintText: 'نام، کد پرسنلی یا شماره حکم...',
                    hintStyle: const TextStyle(fontSize: 12, color: AsoudColors.muted),
                    prefixIcon: const Icon(Icons.search, color: AsoudColors.primary),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AsoudColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AsoudColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: state.statusFilter,
                  onChanged: (val) {
                    if (val != null) {
                      context.read<HiringOrdersCubit>().setStatusFilter(val);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'وضعیت حکم',
                    labelStyle: const TextStyle(fontSize: 12, color: AsoudColors.muted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AsoudColors.border),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('همه وضعیت‌ها')),
                    DropdownMenuItem(value: 'draft', child: Text('پیش‌نویس')),
                    DropdownMenuItem(value: 'pending', child: Text('در جریان')),
                    DropdownMenuItem(value: 'final', child: Text('نهایی')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${toPersianDigits(state.orders.length)} حکم',
                  style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Orders list
          if (state.status == HiringOrdersStatus.loading && state.orders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (state.status == HiringOrdersStatus.error && state.orders.isEmpty)
            ErrorState(
              failure: state.errorMessage ?? 'خطا در دریافت اطلاعات احکام',
              onRetry: () => context.read<HiringOrdersCubit>().load(refresh: true),
            )
          else if (state.orders.isEmpty)
            const EmptyState(
              icon: Icons.description_outlined,
              title: 'حکمی یافت نشد',
              description: 'حکمی مطابق جست‌وجو و وضعیت انتخابی پیدا نشد.',
            )
          else
            ...state.orders.map((order) => _buildOrderCard(context, order)),
        ],
      ),
    );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, HiringOrderSummary order) {
    Color badgeBg;
    Color badgeText;
    if (order.isFinal) {
      badgeBg = AsoudColors.successSurface;
      badgeText = AsoudColors.success;
    } else if (order.isPending) {
      badgeBg = AsoudColors.warningSurface;
      badgeText = AsoudColors.warning;
    } else {
      badgeBg = const Color(0xFFEDF2F8);
      badgeText = const Color(0xFF607D9B);
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.employeeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AsoudColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.number.isNotEmpty ? order.number : order.name} · ${order.employee}',
            style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            'تاریخ اجرا: ${toPersianDigits(order.effectiveDate)}',
            style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AsoudColors.primary,
                    side: const BorderSide(color: Color(0xFFC9DBE9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () async {
                    final cubit = context.read<HiringOrdersCubit>();
                    await cubit.loadOrder(order.name);
                    final detail = cubit.state.currentOrder;
                    if (detail != null) {
                      if (order.isDraft) {
                        _openEditForm(detail);
                      } else {
                        setState(() {
                          _mode = _HiringViewMode.preview;
                        });
                      }
                    }
                  },
                  child: Text(
                    order.isDraft ? 'مشاهده / ادامه' : 'مشاهده',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4E6580),
                    side: const BorderSide(color: AsoudColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () async {
                    final cubit = context.read<HiringOrdersCubit>();
                    await cubit.loadOrder(order.name);
                    await cubit.loadPrint(order.name);
                    setState(() {
                      _mode = _HiringViewMode.preview;
                    });
                  },
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text(
                    'چاپ',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. FORM VIEW -----------------------------------------------------------

  Widget _buildFormView(BuildContext context, HiringOrdersState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Blue notice banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F6FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const BorderSide(color: Color(0xFFD8E7F5)).color),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '✓ قالب «حکم استخدام» آماده است',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: Color(0xFF1769AA),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '۶ ماده از فرم‌ساز سند؛ کارشناس HR فقط اطلاعات اجرایی را تکمیل می‌کند.',
                style: TextStyle(fontSize: 11, color: AsoudColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section 1: Personnel
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
              const AsoudSectionTitle(
                title: '۱. مشخصات پرسنل',
                subtitle: 'اطلاعات از پرونده منابع انسانی',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _personId.isNotEmpty ? _personId : null,
                isExpanded: true,
                hint: const Text('جست‌وجو و انتخاب پرسنل...', style: TextStyle(fontSize: 12)),
                items: state.people
                    .map((p) => DropdownMenuItem(
                          value: p.name,
                          child: Text(
                            '${p.displayName} — ${p.employeeNumber.isNotEmpty ? p.employeeNumber : p.name}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    final person = state.people.firstWhere((p) => p.name == val);
                    setState(() {
                      _personId = person.name;
                      _employeeName = person.displayName;
                      _employeeNumber = person.employeeNumber;
                      if (person.department.isNotEmpty) _unit = person.department;
                      if (person.designation.isNotEmpty) _position = person.designation;
                    });
                    context.read<HiringOrdersCubit>().loadPayroll(
                          employee: person.name,
                          effectiveDate: _effectiveDate,
                        );
                  }
                },
                decoration: InputDecoration(
                  labelText: 'انتخاب کارمند *',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AsoudColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _infoRow('نام و نام خانوادگی', _employeeName.isNotEmpty ? _employeeName : 'پس از انتخاب'),
                    _infoRow('کد پرسنلی', _employeeNumber.isNotEmpty ? _employeeNumber : 'پس از انتخاب'),
                    _infoRow('عنوان شغلی فعلی', _position.isNotEmpty ? _position : 'پس از انتخاب'),
                    _infoRow('کارفرما', widget.company),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section 2: Order details
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
              const AsoudSectionTitle(
                title: '۲. مشخصات حکم',
                subtitle: 'اطلاعاتی که در سند استخدام درج می‌شوند',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _employment,
                onChanged: (val) {
                  if (val != null) setState(() => _employment = val);
                },
                decoration: InputDecoration(
                  labelText: 'نوع استخدام / همکاری *',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AsoudColors.border),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'تمام‌وقت', child: Text('تمام‌وقت')),
                  DropdownMenuItem(value: 'پاره‌وقت', child: Text('پاره‌وقت')),
                  DropdownMenuItem(value: 'قراردادی', child: Text('قراردادی')),
                  DropdownMenuItem(value: 'آزمایشی', child: Text('آزمایشی')),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showAsoudJalaliPicker(context);
                  if (picked != null) {
                    final jalali = JalaliDate.fromDateTime(picked);
                    final formatted =
                        '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
                    setState(() => _effectiveDate = formatted);
                    if (_personId.isNotEmpty && context.mounted) {
                      context.read<HiringOrdersCubit>().loadPayroll(
                            employee: _personId,
                            effectiveDate: formatted,
                          );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AsoudColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'تاریخ اجرای حکم: ${toPersianDigits(_effectiveDate)}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.calendar_today, size: 18, color: AsoudColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _unit,
                onChanged: (val) => _unit = val,
                decoration: InputDecoration(
                  labelText: 'واحد سازمانی *',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AsoudColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _position,
                onChanged: (val) => _position = val,
                decoration: InputDecoration(
                  labelText: 'جایگاه سازمانی *',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AsoudColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _location,
                onChanged: (val) => _location = val,
                decoration: InputDecoration(
                  labelText: 'محل خدمت *',
                  hintText: 'مثلاً دفتر مرکزی',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AsoudColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _note,
                onChanged: (val) => _note = val,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'توضیحات مجاز',
                  hintText: 'توضیحات تکمیلی، در صورت نیاز',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AsoudColors.border),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section 3: Payroll & Benefits
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
              const AsoudSectionTitle(
                title: '۳. حقوق و مزایا',
                subtitle: 'ردیف‌های ماده ۵؛ مبالغ از منابع متصل',
              ),
              const SizedBox(height: 12),
              if (state.currentPayroll == null || state.currentPayroll!.rows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'پس از انتخاب پرسنل، اقلام حقوقی نمایش داده می‌شوند.',
                    style: TextStyle(fontSize: 11.5, color: AsoudColors.muted),
                  ),
                )
              else ...[
                ...state.currentPayroll!.rows.map((row) {
                  final amtText = row.isMissing
                      ? row.message.isNotEmpty
                          ? row.message
                          : 'اطلاعات موجود نیست'
                      : '${toPersianDigits(row.amount?.toStringAsFixed(0) ?? "0")} ریال';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AsoudColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                              Text(row.period == 'monthly' ? 'ماهانه' : row.period, style: const TextStyle(fontSize: 10, color: AsoudColors.muted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          amtText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: row.isMissing ? AsoudColors.danger : AsoudColors.text,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F6FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('جمع اقلام ماهانه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.currentPayroll!.hasMissing
                            ? 'ناقص'
                            : '${toPersianDigits((state.currentPayroll!.monthlyTotal ?? 0).toStringAsFixed(0))} ریال',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1769AA)),
                      ),
                    ],
                  ),
                ),
                if (state.currentPayroll!.hasMissing) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF2DFBC)),
                    ),
                    child: const Text(
                      'یکی از فیلدهای حقوق و مزایا در سیستم حقوق و دستمزد پرسنل ثبت نشده است. ارسال تا تکمیل اطلاعات منبع اصلی غیرفعال است.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF8C631B)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section 4: Articles Accordion
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
              const AsoudSectionTitle(
                title: '۴. مفاد حکم استخدام',
                subtitle: 'متن مصوب قالب؛ فقط جهت مشاهده',
              ),
              const SizedBox(height: 8),
              ..._builderArticles.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final art = entry.value;
                return Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    title: Text(
                      'ماده ${toPersianDigits(idx)} ـ ${art['title']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          _formatArticle(art['body'] ?? '', state),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF596C7F), height: 1.8),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_validationMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF2DFBC)),
            ),
            child: Text(
              _validationMessage!,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8C631B)),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Action Buttons
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AsoudColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            if (_personId.isEmpty) {
              setState(() => _validationMessage = 'ابتدا پرسنل را انتخاب کنید.');
              return;
            }
            setState(() {
              _validationMessage = null;
              _mode = _HiringViewMode.preview;
            });
          },
          child: const Text('◉ بازبینی و پیش‌نمایش چاپ', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AsoudColors.primary,
                  side: const BorderSide(color: Color(0xFFC9DBE9)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  if (_personId.isEmpty) {
                    setState(() => _validationMessage = 'ابتدا پرسنل را انتخاب کنید.');
                    return;
                  }
                  final cubit = context.read<HiringOrdersCubit>();
                  final saved = await cubit.saveDraft(
                    requestId: 'req-${DateTime.now().millisecondsSinceEpoch}',
                    revision: _revision,
                    order: _orderId,
                    employee: _personId,
                    effectiveDate: _effectiveDate,
                    unit: _unit,
                    position: _position,
                    location: _location,
                    employment: _employment,
                    note: _note,
                  );
                  if (saved != null) {
                    setState(() => _mode = _HiringViewMode.list);
                  }
                },
                child: const Text('ذخیره پیش‌نویس'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4E6580),
                  side: const BorderSide(color: AsoudColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => setState(() => _mode = _HiringViewMode.list),
                child: const Text('بازگشت'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 3. PREVIEW & PRINT VIEW -----------------------------------------------

  Widget _buildPreviewView(BuildContext context, HiringOrdersState state) {
    final order = state.currentOrder;
    final isFinal = order?.isFinal ?? false;
    final canSub = _canSubmit(state);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Blue info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F6FC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD8E7F5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('وضعیت حکم:', style: TextStyle(fontSize: 12, color: AsoudColors.muted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFinal ? AsoudColors.successSurface : const Color(0xFFEDF2F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFinal ? 'نهایی' : 'پیش‌نویس',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isFinal ? AsoudColors.success : const Color(0xFF607D9B),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // A4 Paper Document
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD6DFE8)),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCDD8E3)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.description, color: AsoudColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF283F58))),
                        const Text('سربرگ رسمی سازمان', style: TextStyle(fontSize: 10, color: Color(0xFF8090A0))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('شماره: ${order != null && isFinal ? order.number : "—"}', style: const TextStyle(fontSize: 10, color: Color(0xFF718499))),
                      Text('تاریخ صدور: ${order != null && order.issueDate.isNotEmpty ? toPersianDigits(order.issueDate) : "—"}', style: const TextStyle(fontSize: 10, color: Color(0xFF718499))),
                    ],
                  ),
                ],
              ),
              const Divider(color: Color(0xFFB9C7D6), height: 24),

              // Title & Watermark
              const Center(
                child: Text(
                  'حکم استخدام',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF263F59)),
                ),
              ),
              if (!isFinal) ...[
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'پیش‌نویس ـ فاقد اعتبار نهایی',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB05228)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Articles
              ..._builderArticles.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final art = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ماده ${toPersianDigits(idx)} ـ ${art['title']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF263E59)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatArticle(art['body'] ?? '', state),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF31475F), height: 1.8),
                      ),
                      if (art['id'] == 'salary_benefits' && state.currentPayroll != null) ...[
                        const SizedBox(height: 8),
                        Table(
                          border: TableBorder.all(color: const Color(0xFFD3DCE6)),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF2F5F9)),
                              children: const [
                                Padding(padding: EdgeInsets.all(6), child: Text('ردیف', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('عنوان قلم', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('دوره', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('مبلغ (ریال)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            ...state.currentPayroll!.rows.asMap().entries.map((pEntry) {
                              final pIdx = pEntry.key + 1;
                              final prow = pEntry.value;
                              return TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(6), child: Text(toPersianDigits(pIdx), style: const TextStyle(fontSize: 9.5))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(prow.title, style: const TextStyle(fontSize: 9.5))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(prow.period == 'monthly' ? 'ماهانه' : prow.period, style: const TextStyle(fontSize: 9.5))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(prow.isMissing ? prow.message : toPersianDigits(prow.amount?.toStringAsFixed(0) ?? '0'), style: const TextStyle(fontSize: 9.5))),
                                ],
                              );
                            }),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'نام و امضای مقام صادرکننده\n...........................',
                      style: TextStyle(fontSize: 9.5, color: Color(0xFF476078)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مهر سازمان\n...........................',
                      textAlign: TextAlign.left,
                      style: TextStyle(fontSize: 9.5, color: Color(0xFF476078)),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFC6D1DB), height: 32),
              const Center(
                child: Text(
                  'اطلاعات پابرگ شرکت ـ سامانه یکپارچه ابری آسود',
                  style: TextStyle(fontSize: 9, color: Color(0xFF8795A5)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action buttons
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AsoudColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('سند آماده چاپ در مرورگر/پرینتر است.'),
                backgroundColor: AsoudColors.success,
              ),
            );
          },
          icon: const Icon(Icons.print, size: 18),
          label: const Text('🖨 چاپ حکم', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AsoudColors.primary,
                  side: const BorderSide(color: Color(0xFFC9DBE9)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  setState(() => _mode = _HiringViewMode.form);
                },
                child: const Text('اصلاح حکم'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4E6580),
                  side: const BorderSide(color: AsoudColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => setState(() => _mode = _HiringViewMode.list),
                child: const Text('بازگشت به فهرست'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canSub ? AsoudColors.primary : Colors.grey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: canSub
              ? () async {
                  final cubit = context.read<HiringOrdersCubit>();
                  // Save draft first if new
                  final current = order ??
                      await cubit.saveDraft(
                        requestId: 'req-${DateTime.now().millisecondsSinceEpoch}',
                        employee: _personId,
                        effectiveDate: _effectiveDate,
                        unit: _unit,
                        position: _position,
                        location: _location,
                        employment: _employment,
                        note: _note,
                      );
                  if (current != null) {
                    final ok = await cubit.sendForReview(
                      name: current.name,
                      revision: current.revision,
                      requestId: 'rev-${DateTime.now().millisecondsSinceEpoch}',
                    );
                    if (ok && context.mounted) {
                      setState(() => _mode = _HiringViewMode.list);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('حکم با موفقیت برای گردش‌کار ارسال شد.'),
                          backgroundColor: AsoudColors.success,
                        ),
                      );
                    }
                  }
                }
              : null,
          child: const Text('ارسال برای گردش‌کار', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // --- 4. TEMPLATE BUILDER VIEW ----------------------------------------------

  Widget _buildTemplateBuilderView(BuildContext context, HiringOrdersState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              const AsoudSectionTitle(
                title: 'قالب پیش‌فرض حکم استخدام',
                subtitle: '۶ ماده مصوب و جدول اقلام حقوقی متصل',
              ),
              const SizedBox(height: 12),
              ..._builderArticles.asMap().entries.map((entry) {
                final idx = entry.key;
                final art = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AsoudColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ماده ${toPersianDigits(idx + 1)}: ${art['title']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: art['body'],
                        maxLines: 3,
                        style: const TextStyle(fontSize: 11),
                        onChanged: (val) => art['body'] = val,
                        decoration: InputDecoration(
                          hintText: 'متن ماده...',
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AsoudColors.border),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AsoudColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final cubit = context.read<HiringOrdersCubit>();
                  final ok = await cubit.publishTemplate({
                    'articles': _builderArticles,
                    'payroll_rows': _builderPayrollRows,
                  });
                  if (ok && context.mounted) {
                    setState(() => _mode = _HiringViewMode.list);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('قالب حکم استخدام با موفقیت ذخیره و منتشر شد.'),
                        backgroundColor: AsoudColors.success,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('انتشار و ذخیره نسخه نهایی قالب', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: Text(
                value,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AsoudColors.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}
