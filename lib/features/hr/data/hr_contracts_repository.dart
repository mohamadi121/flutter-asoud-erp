import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';

class EmployeeOption {
  const EmployeeOption({
    required this.id,
    required this.name,
    required this.code,
    required this.unit,
    required this.jobTitle,
  });

  factory EmployeeOption.fromJson(Map<String, dynamic> json) => EmployeeOption(
        id: '${json['employee_code'] ?? json['id'] ?? ''}',
        name: '${json['display_name'] ?? json['full_name'] ?? json['name'] ?? ''}',
        code: '${json['employee_code'] ?? json['code'] ?? ''}',
        unit: '${json['department'] ?? json['unit'] ?? ''}',
        jobTitle: '${json['designation'] ?? json['jobTitle'] ?? json['job_title'] ?? ''}',
      );

  final String id;
  final String name;
  final String code;
  final String unit;
  final String jobTitle;
}

abstract class HrContractsRepository {
  Future<Map<String, dynamic>> getPrintPayload({required String company, required String id});
  Future<List<HrContractRecord>> listContracts({
    required String company,
    String? query,
    String? statusFilter,
    int page = 1,
    int pageSize = 20,
  });

  Future<HrContractRecord> getContract({
    required String company,
    required String id,
  });

  Future<HrContractRecord> saveDraftContract({
    required String company,
    required HrContractRecord draft,
  });

  Future<HrContractRecord> submitContract({
    required String company,
    required HrContractRecord draft,
  });

  Future<List<EmployeeOption>> getStaffList({
    required String company,
  });

  Future<Map<String, int?>> getStaffSalaries({
    required String company,
    required String staffId,
  });
}

class FakeHrContractsRepository implements HrContractsRepository {
  @override
  Future<Map<String, dynamic>> getPrintPayload({required String company, required String id}) async {
    final record = await getContract(company: company, id: id);
    return {
      'draft_banner': record.isDraft ? '«پیش‌نویس ـ فاقد اعتبار نهایی»' : null,
      'html': '<html dir="rtl"><body>${record.employeeName}</body></html>',
    };
  }
  FakeHrContractsRepository({List<HrContractRecord>? initial})
      : _records = initial ??
            [
              const HrContractRecord(
                id: 'CRT-1405-021',
                staffId: 'p1',
                employeeName: 'پرسنل نمونه ۱',
                employeeCode: 'HR-101',
                unit: 'امور اداری',
                jobTitle: 'کارشناس اداری',
                kind: 'مدت‌معین',
                status: 'نهایی',
                startDate: '۱۴۰۵/۰۱/۰۱',
                endDate: '۱۴۰۵/۱۲/۲۹',
                workplace: 'دفتر مرکزی',
                salaries: {
                  'payroll.base_salary': 235000000,
                  'payroll.housing': 9000000,
                  'payroll.food': 22000000,
                },
                templateVersion: 1,
              ),
              const HrContractRecord(
                id: 'CRT-1405-026',
                staffId: 'p2',
                employeeName: 'پرسنل نمونه ۲',
                employeeCode: 'HR-102',
                unit: 'فروش',
                jobTitle: 'کارشناس فروش',
                kind: 'مدت‌معین',
                status: 'در جریان',
                startDate: '۱۴۰۵/۰۷/۰۱',
                endDate: '۱۴۰۶/۰۶/۳۱',
                workplace: 'شعبه فروش',
                salaries: {
                  'payroll.base_salary': 210000000,
                  'payroll.housing': null, // Missing value to test "اطلاعات موجود نیست"
                  'payroll.food': 22000000,
                },
                templateVersion: 1,
              ),
              const HrContractRecord(
                id: 'CRT-1405-030',
                staffId: 'p3',
                employeeName: 'پرسنل نمونه ۳',
                employeeCode: 'HR-103',
                unit: 'پشتیبانی',
                jobTitle: 'کارشناس پشتیبانی',
                kind: 'کار معین',
                status: 'پیش‌نویس',
                startDate: '۱۴۰۵/۰۸/۰۱',
                workplace: 'کارگاه',
                salaries: {
                  'payroll.base_salary': 195000000,
                  'payroll.housing': 9000000,
                  'payroll.food': 22000000,
                },
                templateVersion: 1,
              ),
            ];

  final List<HrContractRecord> _records;
  int savedDraftsCount = 0;

  static const _mockStaff = [
    EmployeeOption(
      id: 'p1',
      name: 'پرسنل نمونه ۱',
      code: 'HR-101',
      unit: 'امور اداری',
      jobTitle: 'کارشناس اداری',
    ),
    EmployeeOption(
      id: 'p2',
      name: 'پرسنل نمونه ۲',
      code: 'HR-102',
      unit: 'فروش',
      jobTitle: 'کارشناس فروش',
    ),
    EmployeeOption(
      id: 'p3',
      name: 'پرسنل نمونه ۳',
      code: 'HR-103',
      unit: 'پشتیبانی',
      jobTitle: 'کارشناس پشتیبانی',
    ),
  ];

  static const _mockSalaries = {
    'p1': {
      'payroll.base_salary': 235000000,
      'payroll.housing': 9000000,
      'payroll.food': 22000000,
    },
    'p2': {
      'payroll.base_salary': 210000000,
      'payroll.housing': null, // Missing intentionally
      'payroll.food': 22000000,
    },
    'p3': {
      'payroll.base_salary': 195000000,
      'payroll.housing': 9000000,
      'payroll.food': 22000000,
    },
  };

  HrContractRecord get fakeDraftContract => _records.firstWhere((r) => r.isDraft);

  @override
  Future<List<HrContractRecord>> listContracts({
    required String company,
    String? query,
    String? statusFilter,
    int page = 1,
    int pageSize = 20,
  }) async {
    var filtered = List<HrContractRecord>.from(_records);
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'همه') {
      filtered = filtered.where((r) => r.status == statusFilter).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((r) {
        return r.employeeName.toLowerCase().contains(q) ||
            r.employeeCode.toLowerCase().contains(q) ||
            r.id.toLowerCase().contains(q);
      }).toList();
    }
    return filtered;
  }

  @override
  Future<HrContractRecord> getContract({
    required String company,
    required String id,
  }) async {
    return _records.firstWhere((r) => r.id == id);
  }

  @override
  Future<HrContractRecord> saveDraftContract({
    required String company,
    required HrContractRecord draft,
  }) async {
    savedDraftsCount++;
    final record = draft.copyWith(
      id: draft.id.isEmpty || draft.id == 'شماره پس از صدور'
          ? 'پیش‌نویس-${_records.length + 1}'
          : draft.id,
      status: 'پیش‌نویس',
    );
    _records.removeWhere((r) => r.id == record.id);
    _records.insert(0, record);
    return record;
  }

  @override
  Future<HrContractRecord> submitContract({
    required String company,
    required HrContractRecord draft,
  }) async {
    final record = draft.copyWith(
      id: draft.id.startsWith('CRT-') ? draft.id : 'CRT-1405-0${_records.length + 10}',
      status: 'نهایی',
    );
    _records.removeWhere((r) => r.id == draft.id || r.id == record.id);
    _records.insert(0, record);
    return record;
  }

  @override
  Future<List<EmployeeOption>> getStaffList({required String company}) async {
    return _mockStaff;
  }

  @override
  Future<Map<String, int?>> getStaffSalaries({
    required String company,
    required String staffId,
  }) async {
    return _mockSalaries[staffId] ?? const {};
  }
}

class ServerHrContractsRepository implements HrContractsRepository {
  ServerHrContractsRepository(this.client);
  final FrappeApiClient client;

  @override
  Future<Map<String, dynamic>> getPrintPayload({required String company, required String id}) async {
    final result = await client.callAsoudMethod(
      'asoud_erp.api.v1.employment_contracts.get_contract_print',
      data: {'contract_id': id},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<List<HrContractRecord>> listContracts({
    required String company,
    String? query,
    String? statusFilter,
    int page = 1,
    int pageSize = 20,
  }) async {
    final statusMap = {
      'همه': 'all',
      'پیش‌نویس': 'draft',
      'در جریان': 'in_progress',
      'نهایی': 'final',
    };
    final res = await client.callAsoudMethod(
      'asoud_erp.api.v1.employment_contracts.list_contracts',
      data: {
        'company': company,
        if (query != null && query.isNotEmpty) 'search': query,
        if (statusFilter != null && statusFilter.isNotEmpty)
          'status': statusMap[statusFilter] ?? statusFilter,
        'start': (page - 1) * pageSize,
        'page_length': pageSize,
      },
    );
    if (res is Map<String, dynamic> && res['data'] is List) {
      return (res['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(HrContractRecord.fromJson)
          .toList();
    } else if (res is List) {
      return res
          .whereType<Map<String, dynamic>>()
          .map(HrContractRecord.fromJson)
          .toList();
    }
    return const [];
  }

  @override
  Future<HrContractRecord> getContract({
    required String company,
    required String id,
  }) async {
    final res = await client.callAsoudMethod(
      'asoud_erp.api.v1.employment_contracts.get_contract',
      data: {'contract_id': id},
    );
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      return HrContractRecord.fromJson(data);
    }
    throw Exception('قرارداد با شناسه $id یافت نشد.');
  }

  @override
  Future<HrContractRecord> saveDraftContract({
    required String company,
    required HrContractRecord draft,
  }) async {
    final res = await client.callAsoudMethod(
      'asoud_erp.api.v1.employment_contracts.save_contract_draft',
      data: {
        'company': company,
        'employee': draft.staffId,
        if (draft.clientId != null) 'client_id': draft.clientId,
        'start_date': _isoDate(draft.startDate),
        if (draft.endDate != null && draft.endDate!.isNotEmpty) 'end_date': _isoDate(draft.endDate!),
        'contract_type': draft.kind,
        'work_location': draft.workplace,
        if (draft.subject != null) 'subject': draft.subject,
        if (draft.notes != null) 'notes': draft.notes,
        'salary_values': draft.salaries,
        if (draft.id.isNotEmpty && draft.id != 'شماره پس از صدور' && !draft.id.startsWith('پیش‌نویس'))
          'contract_id': draft.id,
      },
    );
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      return HrContractRecord.fromJson(data);
    }
    throw const FormatException('پاسخ ذخیره قرارداد معتبر نیست.');
  }

  @override
  Future<HrContractRecord> submitContract({
    required String company,
    required HrContractRecord draft,
  }) async {
    final saved = await saveDraftContract(company: company, draft: draft);
    await client.callAsoudMethod(
      'asoud_erp.api.v1.employment_contracts.finalize_contract',
      data: {
        'contract_id': saved.id,
        if (draft.clientId != null) 'client_id': draft.clientId,
      },
    );
    return getContract(company: company, id: saved.id);
  }

  @override
  Future<List<EmployeeOption>> getStaffList({required String company}) async {
      final res = await client.callAsoudMethod(
        'asoud_erp.api.v1.personnel.list_personnel',
        data: {'company': company},
      );
      if (res is Map && res['rows'] is List) {
        return (res['rows'] as List)
            .whereType<Map<String, dynamic>>()
            .map(EmployeeOption.fromJson)
            .toList();
      }
    throw const FormatException('پاسخ فهرست پرسنل معتبر نیست.');
  }

  @override
  Future<Map<String, int?>> getStaffSalaries({
    required String company,
    required String staffId,
  }) async {
      final res = await client.callAsoudMethod(
        'asoud_erp.api.v1.employment_contracts.prepare_contract',
        data: {'company': company, 'employee': staffId},
      );
      if (res is Map<String, dynamic>) {
        final data = res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
        final salaryTable = data['salary_rows'] ?? data['salary_table'];
        if (salaryTable is List) {
          final result = <String, int?>{};
          for (final row in salaryTable) {
            if (row is Map) {
              final ref = '${row['fieldRef'] ?? row['id'] ?? ''}';
              final val = row['has_value'] == false ? null : row['amount'];
              result[ref] = val is num ? val.toInt() : null;
            }
          }
          return result;
        }
      }
    return const {};
  }

  String _isoDate(String value) {
    final latin = toLatinDigits(value);
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(latin) && int.parse(latin.substring(0, 4)) > 1700) return latin;
    final date = parseJalaliDate(value);
    if (date == null) throw const FormatException('تاریخ قرارداد معتبر نیست.');
    return date.toIso8601String().substring(0, 10);
  }
}
