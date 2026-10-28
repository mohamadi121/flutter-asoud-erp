import 'package:flutter/material.dart';

import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/core/widgets/asoud_ui.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/data/hr_contract_template_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';
import 'hr_contract_builder_page.dart';
import 'hr_contract_issue_page.dart';
import 'hr_contract_print_page.dart';

class HrContractsPage extends StatefulWidget {
  const HrContractsPage({
    required this.company,
    this.repository,
    this.templateRepository,
    this.canManageTemplate = false,
    super.key,
  });

  final String company;
  final HrContractsRepository? repository;
  final HrContractTemplateRepository? templateRepository;
  final bool canManageTemplate;

  @override
  State<HrContractsPage> createState() => _HrContractsPageState();
}

class _HrContractsPageState extends State<HrContractsPage> {
  late final HrContractsRepository repository =
      widget.repository ?? FakeHrContractsRepository();
  late final HrContractTemplateRepository templateRepository =
      widget.templateRepository ?? FakeHrContractTemplateRepository();

  bool loading = true;
  String? error;
  List<HrContractRecord> records = [];

  String searchQuery = '';
  String statusFilter = 'همه';
  final TextEditingController searchController = TextEditingController();

  static const List<String> statusOptions = [
    'همه',
    'پیش‌نویس',
    'در جریان',
    'نهایی',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String _normalize(String input) {
    return input
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .toLowerCase()
        .trim();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final list = await repository.listContracts(
        company: widget.company,
        query: searchQuery,
        statusFilter: statusFilter,
      );
      if (mounted) {
        setState(() {
          records = list;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'دریافت فهرست قراردادها ممکن نشد؛ دوباره تلاش کنید.';
          loading = false;
        });
      }
    }
  }

  List<HrContractRecord> get filteredRecords {
    final q = _normalize(searchQuery);
    return records.where((r) {
      if (statusFilter != 'همه' && r.status != statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final haystack = _normalize(
          '${r.employeeName} ${r.employeeCode} ${r.id} ${r.kind} ${r.status}');
      return haystack.contains(q);
    }).toList();
  }

  Color _statusColor(String status) => switch (status) {
        'نهایی' => AsoudColors.success,
        'در جریان' => AsoudColors.primary,
        _ => const Color(0xFFD97706),
      };

  Color _statusBg(String status) => switch (status) {
        'نهایی' => const Color(0xFFECFDF5),
        'در جریان' => const Color(0xFFEFF6FF),
        _ => const Color(0xFFFFFBEB),
      };

  Future<void> _openNewContract() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HrContractIssuePage(
          company: widget.company,
          repository: repository,
          templateRepository: templateRepository,
        ),
      ),
    );
    if (result == true && mounted) {
      _load();
    }
  }

  Future<void> _continueDraft(HrContractRecord contract) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HrContractIssuePage(
          company: widget.company,
          repository: repository,
          templateRepository: templateRepository,
          initialDraft: contract,
        ),
      ),
    );
    if (result == true && mounted) {
      _load();
    }
  }

  void _openPrint(HrContractRecord contract) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HrContractPrintPage(
          contract: contract,
          loadPayload: () => repository.getPrintPayload(company: widget.company, id: contract.id),
        ),
      ),
    );
  }

  void _openTemplateBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HrContractBuilderPage(
          company: widget.company,
          repository: templateRepository,
          canManageTemplate: widget.canManageTemplate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = filteredRecords;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
          title: 'قراردادهای پرسنلی',
          subtitle: widget.company,
          action: widget.canManageTemplate
              ? IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'قالب قرارداد کار',
                  onPressed: _openTemplateBuilder,
                )
              : null,
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Action Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.badge_outlined,
                              color: AsoudColors.primary),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مدیریت قراردادهای کارکنان',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'ایجاد، جست‌وجو و پیگیری قراردادها',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _openNewContract,
                      style: FilledButton.styleFrom(
                        backgroundColor: AsoudColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('＋ قرارداد جدید'),
                    ),
                    if (widget.canManageTemplate) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _openTemplateBuilder,
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('تنظیم قالب قرارداد'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Search & Filter Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.search, size: 18, color: AsoudColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'فهرست قراردادها',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'نام، کد پرسنلی یا شماره قرارداد...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() => searchQuery = '');
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => searchQuery = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: statusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'وضعیت قرارداد',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: statusOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => statusFilter = v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${toPersianDigits('${displayed.length}')} قرارداد',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'برای مشاهده هر ردیف، دکمه مشاهده را بزنید',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Results
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (displayed.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'قراردادی مطابق عبارت جست‌وجو پیدا نشد.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                )
              else
                for (final contract in displayed) ...[
                  _buildContractCard(contract),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractCard(HrContractRecord c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                c.employeeName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusBg(c.status),
                  border: Border.all(color: _statusColor(c.status)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor(c.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${c.id} · ${c.employeeCode}\n${c.kind} · شروع ${c.startDate}',
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openPrint(c),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('مشاهده'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _openPrint(c),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('چاپ'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              if (c.isDraft) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _continueDraft(c),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('ادامه'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
