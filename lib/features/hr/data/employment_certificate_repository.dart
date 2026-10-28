import '../../../core/network/frappe_client.dart';

class CertificateClause {
  const CertificateClause({
    required this.id,
    required this.title,
    required this.body,
    this.enabled = true,
  });

  factory CertificateClause.fromMap(Map<String, dynamic> map) => CertificateClause(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        body: map['body']?.toString() ?? '',
        enabled: map['enabled'] != false,
      );

  final String id;
  final String title;
  final String body;
  final bool enabled;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'enabled': enabled,
      };

  CertificateClause copyWith({String? id, String? title, String? body, bool? enabled}) => CertificateClause(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        enabled: enabled ?? this.enabled,
      );
}

class SalaryRowDefinition {
  const SalaryRowDefinition({
    required this.id,
    required this.title,
    required this.fieldRef,
    this.period = 'monthly',
  });

  factory SalaryRowDefinition.fromMap(Map<String, dynamic> map) => SalaryRowDefinition(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        fieldRef: map['field_ref']?.toString() ?? '',
        period: map['period']?.toString() ?? 'monthly',
      );

  final String id;
  final String title;
  final String fieldRef;
  final String period;

  SalaryRowDefinition copyWith({
    String? id,
    String? title,
    String? fieldRef,
    String? period,
  }) =>
      SalaryRowDefinition(
        id: id ?? this.id,
        title: title ?? this.title,
        fieldRef: fieldRef ?? this.fieldRef,
        period: period ?? this.period,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'field_ref': fieldRef,
        'period': period,
      };

  String get periodLabel => switch (period) {
        'yearly' => 'سالانه',
        'one_off' => 'یک‌باره',
        _ => 'ماهانه',
      };
}

class EmploymentCertificateTemplate {
  const EmploymentCertificateTemplate({
    required this.name,
    required this.revision,
    required this.status,
    required this.salaryEnabled,
    required this.clauses,
    required this.salaryRows,
  });

  factory EmploymentCertificateTemplate.fromMap(Map<String, dynamic> map) => EmploymentCertificateTemplate(
        name: map['name']?.toString() ?? '',
        revision: map['revision'] is int ? map['revision'] as int : int.tryParse(map['revision']?.toString() ?? '1') ?? 1,
        status: map['status']?.toString() ?? 'Draft',
        salaryEnabled: map['salary_enabled'] == true,
        clauses: (map['clauses'] as List? ?? const [])
            .map((c) => CertificateClause.fromMap(Map<String, dynamic>.from(c as Map)))
            .toList(),
        salaryRows: (map['salary_rows'] as List? ?? const [])
            .map((r) => SalaryRowDefinition.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList(),
      );

  final String name;
  final int revision;
  final String status;
  final bool salaryEnabled;
  final List<CertificateClause> clauses;
  final List<SalaryRowDefinition> salaryRows;

  Map<String, dynamic> toMap() => {
        'name': name,
        'revision': revision,
        'status': status,
        'salary_enabled': salaryEnabled,
        'clauses': clauses.map((c) => c.toMap()).toList(),
        'salary_rows': salaryRows.map((r) => r.toMap()).toList(),
      };
}

class EmploymentCertificate {
  const EmploymentCertificate({
    required this.name,
    required this.employeeName,
    required this.employeeNumber,
    required this.number,
    required this.addresseeName,
    required this.status,
    this.purpose = '',
    this.issueDate = '',
  });

  factory EmploymentCertificate.fromMap(Map<String, dynamic> map) => EmploymentCertificate(
        name: map['name']?.toString() ?? '',
        employeeName: map['employee_name']?.toString().trim().isNotEmpty == true
            ? map['employee_name'].toString()
            : 'پرسنل منتسب',
        employeeNumber: map['employee_number']?.toString() ?? '',
        number: map['number']?.toString() ?? '—',
        addresseeName: map['addressee_name']?.toString() ?? '',
        status: map['status']?.toString() ?? 'Draft',
        purpose: map['purpose']?.toString() ?? '',
        issueDate: map['issue_date']?.toString() ?? '',
      );

  final String name;
  final String employeeName;
  final String employeeNumber;
  final String number;
  final String addresseeName;
  final String status;
  final String purpose;
  final String issueDate;

  static String mapStatusToGroup(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'draft' || s == 'پیش‌نویس') return 'پیش‌نویس';
    if (s == 'in review' ||
        s == 'in_review' ||
        s == 'pending' ||
        s == 'در جریان' ||
        s == 'در انتظار بررسی') {
      return 'در جریان';
    }
    if (s == 'final' ||
        s == 'submitted' ||
        s == 'active' ||
        s == 'نهایی' ||
        s == 'ارسال‌شده') {
      return 'نهایی';
    }
    if (s == 'rejected' ||
        s == 'cancelled' ||
        s == 'canceled' ||
        s == 'ردشده' ||
        s == 'لغوشده') {
      return 'ردشده';
    }
    return raw;
  }

  String get statusGroup => mapStatusToGroup(status);
  String get statusLabel => statusGroup;
  bool get isFinal => statusGroup == 'نهایی';
  bool get isDraft => statusGroup == 'پیش‌نویس';
  bool get isInReview => statusGroup == 'در جریان';
  bool get isRejected => statusGroup == 'ردشده';
}

class EmploymentCertificateDetail {
  const EmploymentCertificateDetail({
    required this.name,
    required this.company,
    required this.employee,
    required this.employeeName,
    required this.employeeNumber,
    required this.number,
    required this.addresseeType,
    required this.addresseeName,
    required this.addresseeTitle,
    required this.purpose,
    required this.location,
    required this.notes,
    required this.status,
    required this.revision,
    required this.templateVersion,
    required this.renderedHtml,
    required this.printHtml,
    required this.salaryRows,
    required this.hasSalary,
    required this.issueDate,
  });

  factory EmploymentCertificateDetail.fromMap(Map<String, dynamic> map) => EmploymentCertificateDetail(
        name: map['name']?.toString() ?? '',
        company: map['company']?.toString() ?? '',
        employee: map['employee']?.toString() ?? '',
        employeeName: map['employee_name']?.toString().trim().isNotEmpty == true
            ? map['employee_name'].toString()
            : 'پرسنل منتسب',
        employeeNumber: map['employee_number']?.toString() ?? '',
        number: map['number']?.toString() ?? '—',
        addresseeType: map['addressee_type']?.toString() ?? '',
        addresseeName: map['addressee_name']?.toString() ?? '',
        addresseeTitle: map['addressee_title']?.toString() ?? '',
        purpose: map['purpose']?.toString() ?? '',
        location: map['location']?.toString() ?? '',
        notes: map['notes']?.toString() ?? '',
        status: map['status']?.toString() ?? 'Draft',
        revision: map['revision'] is int ? map['revision'] as int : int.tryParse(map['revision']?.toString() ?? '1') ?? 1,
        templateVersion: map['template_version'] is int
            ? map['template_version'] as int
            : int.tryParse(map['template_version']?.toString() ?? '1') ?? 1,
        renderedHtml: map['rendered_html']?.toString() ?? '',
        printHtml: map['print_html']?.toString() ?? '',
        salaryRows: (map['salary_rows'] as List? ?? const [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
        hasSalary: map['has_salary'] == true,
        issueDate: map['issue_date']?.toString() ?? '',
      );

  final String name;
  final String company;
  final String employee;
  final String employeeName;
  final String employeeNumber;
  final String number;
  final String addresseeType;
  final String addresseeName;
  final String addresseeTitle;
  final String purpose;
  final String location;
  final String notes;
  final String status;
  final int revision;
  final int templateVersion;
  final String renderedHtml;
  final String printHtml;
  final List<Map<String, dynamic>> salaryRows;
  final bool hasSalary;
  final String issueDate;

  bool get isFinal => statusGroup == 'نهایی';
  bool get isDraft => statusGroup == 'پیش‌نویس';
  bool get isInReview => statusGroup == 'در جریان';
  bool get isRejected => statusGroup == 'ردشده';
  String get statusGroup => EmploymentCertificate.mapStatusToGroup(status);
  String get statusLabel => statusGroup;
}

class EmploymentCertificateRepository {
  EmploymentCertificateRepository(this._client);
  final FrappeApiClient _client;
  static const _module = 'asoud_erp.api.v1.employment_certificates';

  Future<EmploymentCertificateTemplate> getTemplate({required String company}) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.get_template', data: {'company': company}) as Map,
    );
    return EmploymentCertificateTemplate.fromMap(raw);
  }

  Future<EmploymentCertificateTemplate> saveTemplateDraft({
    required String company,
    required int revision,
    required List<CertificateClause> clauses,
    required bool salaryEnabled,
    required List<SalaryRowDefinition> salaryRows,
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.save_template_draft', data: {
        'company': company,
        'revision': revision,
        'clauses': clauses.map((c) => c.toMap()).toList(),
        'salary_enabled': salaryEnabled,
        'salary_rows': salaryRows.map((r) => r.toMap()).toList(),
      }) as Map,
    );
    return EmploymentCertificateTemplate.fromMap(raw);
  }

  Future<EmploymentCertificateTemplate> publishTemplate({
    required String company,
    required int revision,
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.publish_template', data: {
        'company': company,
        'revision': revision,
      }) as Map,
    );
    return EmploymentCertificateTemplate.fromMap(raw);
  }

  Future<({List<EmploymentCertificate> items, int total})> list({
    required String company,
    String query = '',
    String status = '',
    int start = 0,
    int pageLength = 20,
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.list_certificates', data: {
        'company': company,
        'query': query,
        'status': status,
        'start': start,
        'page_length': pageLength,
      }) as Map,
    );
    final items = (raw['items'] as List? ?? const [])
        .map((row) => EmploymentCertificate.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
    return (items: items, total: raw['total'] is int ? raw['total'] as int : items.length);
  }

  Future<EmploymentCertificateDetail> getCertificate({required String name}) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.get_certificate', data: {'name': name}) as Map,
    );
    return EmploymentCertificateDetail.fromMap(raw);
  }

  Future<EmploymentCertificateDetail> saveDraft({
    required String company,
    required String employee,
    String addresseeType = '',
    required String addresseeName,
    String addresseeTitle = '',
    String purpose = '',
    required String requestKey,
    int revision = 0,
    String name = '',
    String notes = '',
    bool includeSalary = false,
    String location = '',
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.save_draft', data: {
        'company': company,
        'employee': employee,
        'addressee_type': addresseeType,
        'addressee_name': addresseeName,
        'addressee_title': addresseeTitle,
        'purpose': purpose,
        'request_key': requestKey,
        'revision': revision,
        'name': name,
        'notes': notes,
        'include_salary': includeSalary,
        'location': location,
      }) as Map,
    );
    return EmploymentCertificateDetail.fromMap(raw);
  }

  Future<EmploymentCertificateDetail> finalizeCertificate({
    required String name,
    required int revision,
    required String requestKey,
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.finalize_certificate', data: {
        'name': name,
        'revision': revision,
        'request_key': requestKey,
      }) as Map,
    );
    return EmploymentCertificateDetail.fromMap(raw);
  }

  Future<List<Map<String, dynamic>>> getEmployeeOptions({required String company}) async {
    final raw = await _client.callAsoudMethod('$_module.get_employee_options', data: {'company': company});
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return const [];
  }
}
