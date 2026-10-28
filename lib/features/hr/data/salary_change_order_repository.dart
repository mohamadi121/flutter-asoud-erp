import '../../../core/network/frappe_client.dart';

class SalaryChangeOrderPerson {
  const SalaryChangeOrderPerson({
    required this.name,
    required this.displayName,
    required this.employeeNumber,
    this.department = '',
    this.designation = '',
  });

  factory SalaryChangeOrderPerson.fromJson(Map<String, dynamic> json) =>
      SalaryChangeOrderPerson(
        name: json['name']?.toString() ?? '',
        displayName: json['display_name']?.toString() ?? 'پرسنل منتسب',
        employeeNumber: json['employee_number']?.toString() ?? '',
        department: json['department']?.toString() ?? '',
        designation: json['designation']?.toString() ?? '',
      );

  final String name;
  final String displayName;
  final String employeeNumber;
  final String department;
  final String designation;
}

class SalaryChangeComparisonRow {
  const SalaryChangeComparisonRow({
    required this.id,
    required this.title,
    required this.period,
    required this.periodLabel,
    required this.oldRef,
    required this.newRef,
    this.previousAmount,
    this.newAmount,
    this.difference,
    this.percentChange,
    this.percentLabel,
    this.state = 'available',
    this.message,
  });

  factory SalaryChangeComparisonRow.fromJson(Map<String, dynamic> json) =>
      SalaryChangeComparisonRow(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? json['name']?.toString() ?? '',
        period: json['period']?.toString() ?? 'monthly',
        periodLabel: json['period_label']?.toString() ??
            (json['period'] == 'yearly'
                ? 'سالانه'
                : json['period'] == 'one_off'
                    ? 'یک‌باره'
                    : 'ماهانه'),
        oldRef: json['old_ref']?.toString() ?? '',
        newRef: json['new_ref']?.toString() ?? '',
        previousAmount: (json['previous_amount'] as num?)?.toInt() ??
            (json['old'] as num?)?.toInt(),
        newAmount: (json['new_amount'] as num?)?.toInt() ??
            (json['new'] as num?)?.toInt(),
        difference: (json['difference'] as num?)?.toInt(),
        percentChange: (json['percent_change'] as num?)?.toDouble(),
        percentLabel: json['percent_label']?.toString(),
        state: json['state']?.toString() ?? 'available',
        message: json['message']?.toString(),
      );

  final String id;
  final String title;
  final String period;
  final String periodLabel;
  final String oldRef;
  final String newRef;
  final int? previousAmount;
  final int? newAmount;
  final int? difference;
  final double? percentChange;
  final String? percentLabel;
  final String state;
  final String? message;

  bool get isMissing => state == 'missing' || previousAmount == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'period': period,
        'period_label': periodLabel,
        'old_ref': oldRef,
        'new_ref': newRef,
        'previous_amount': previousAmount,
        'new_amount': newAmount,
        'difference': difference,
        'percent_change': percentChange,
        'percent_label': percentLabel,
        'state': state,
        if (message != null) 'message': message,
      };
}

class SalaryChangePayrollResult {
  const SalaryChangePayrollResult({
    required this.currency,
    required this.rows,
    this.message,
  });

  factory SalaryChangePayrollResult.fromJson(Map<String, dynamic> json) {
    final list = (json['rows'] as List?) ?? [];
    return SalaryChangePayrollResult(
      currency: json['currency']?.toString() ?? 'IRR',
      rows: list
          .whereType<Map>()
          .map((m) => SalaryChangeComparisonRow.fromJson(
              Map<String, dynamic>.from(m)))
          .toList(),
      message: json['message']?.toString(),
    );
  }

  final String currency;
  final List<SalaryChangeComparisonRow> rows;
  final String? message;

  bool get hasMissing => rows.any((r) => r.isMissing);
}

class SalaryChangeOrderSummary {
  const SalaryChangeOrderSummary({
    required this.name,
    required this.number,
    required this.employee,
    required this.employeeName,
    required this.status,
    required this.statusLabel,
    required this.applicationStatus,
    required this.applicationStatusLabel,
    required this.effectiveDate,
    required this.issueDate,
    required this.draftedOn,
    required this.reason,
    required this.reasonLabel,
    required this.revision,
  });

  factory SalaryChangeOrderSummary.fromJson(Map<String, dynamic> json) =>
      SalaryChangeOrderSummary(
        name: json['name']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        employee: json['employee']?.toString() ?? '',
        employeeName: json['employee_name']?.toString() ?? 'پرسنل منتسب',
        status: json['status']?.toString() ?? 'draft',
        statusLabel: json['status_label']?.toString() ?? 'پیش‌نویس',
        applicationStatus:
            json['application_status']?.toString() ?? 'not_applied',
        applicationStatusLabel:
            json['application_status_label']?.toString() ?? 'اعمال‌نشده',
        effectiveDate: json['effective_date']?.toString() ?? '',
        issueDate: json['issue_date']?.toString() ?? '',
        draftedOn: json['drafted_on']?.toString() ?? '',
        reason: json['reason']?.toString() ?? 'annual',
        reasonLabel: json['reason_label']?.toString() ?? 'افزایش سالانه',
        revision: (json['revision'] as num?)?.toInt() ?? 1,
      );

  final String name;
  final String number;
  final String employee;
  final String employeeName;
  final String status;
  final String statusLabel;
  final String applicationStatus;
  final String applicationStatusLabel;
  final String effectiveDate;
  final String issueDate;
  final String draftedOn;
  final String reason;
  final String reasonLabel;
  final int revision;

  bool get isDraft => status == 'draft';
  bool get isPending => status == 'pending';
  bool get isFinal => status == 'final';
  bool get isRejected => status == 'rejected';
  bool get isApplied => applicationStatus == 'applied';
}

class SalaryChangeOrderDetail {
  const SalaryChangeOrderDetail({
    required this.name,
    required this.number,
    required this.company,
    required this.companyName,
    required this.employee,
    required this.employeeName,
    required this.employeeNumber,
    required this.status,
    required this.statusLabel,
    required this.applicationStatus,
    required this.applicationStatusLabel,
    required this.effectiveDate,
    required this.issueDate,
    required this.draftedOn,
    required this.reason,
    required this.reasonLabel,
    this.department = '',
    this.designation = '',
    this.description = '',
    this.values = const {},
    this.templateSnapshot = const {},
    this.comparisonRows = const [],
    this.monthlyPreviousTotal,
    this.monthlyNewTotal,
    this.monthlyDifference,
    required this.revision,
  });

  factory SalaryChangeOrderDetail.fromJson(Map<String, dynamic> json) {
    final compTable = json['comparison_table'] as Map? ?? {};
    final rawRows = (compTable['rows'] as List?) ?? [];
    return SalaryChangeOrderDetail(
      name: json['name']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      employee: json['employee']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? 'پرسنل منتسب',
      employeeNumber: json['employee_number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      statusLabel: json['status_label']?.toString() ?? 'پیش‌نویس',
      applicationStatus:
          json['application_status']?.toString() ?? 'not_applied',
      applicationStatusLabel:
          json['application_status_label']?.toString() ?? 'اعمال‌نشده',
      effectiveDate: json['effective_date']?.toString() ?? '',
      issueDate: json['issue_date']?.toString() ?? '',
      draftedOn: json['drafted_on']?.toString() ?? '',
      reason: json['reason']?.toString() ?? 'annual',
      reasonLabel: json['reason_label']?.toString() ?? 'افزایش سالانه',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      values: (json['values'] as Map?)?.cast<String, dynamic>() ?? const {},
      templateSnapshot: (json['template_snapshot'] as Map?)
              ?.cast<String, dynamic>() ??
          const {},
      comparisonRows: rawRows
          .whereType<Map>()
          .map((m) => SalaryChangeComparisonRow.fromJson(
              Map<String, dynamic>.from(m)))
          .toList(),
      monthlyPreviousTotal:
          (compTable['monthly_previous_total'] as num?)?.toInt(),
      monthlyNewTotal: (compTable['monthly_new_total'] as num?)?.toInt(),
      monthlyDifference: (compTable['monthly_difference'] as num?)?.toInt(),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
    );
  }

  final String name;
  final String number;
  final String company;
  final String companyName;
  final String employee;
  final String employeeName;
  final String employeeNumber;
  final String status;
  final String statusLabel;
  final String applicationStatus;
  final String applicationStatusLabel;
  final String effectiveDate;
  final String issueDate;
  final String draftedOn;
  final String reason;
  final String reasonLabel;
  final String department;
  final String designation;
  final String description;
  final Map<String, dynamic> values;
  final Map<String, dynamic> templateSnapshot;
  final List<SalaryChangeComparisonRow> comparisonRows;
  final int? monthlyPreviousTotal;
  final int? monthlyNewTotal;
  final int? monthlyDifference;
  final int revision;

  bool get isDraft => status == 'draft';
  bool get isPending => status == 'pending';
  bool get isFinal => status == 'final';
  bool get isRejected => status == 'rejected';
  bool get isApplied => applicationStatus == 'applied';
}

class SalaryChangeOrderPrint {
  const SalaryChangeOrderPrint({
    required this.html,
    required this.status,
    required this.number,
    required this.draftBanner,
  });

  factory SalaryChangeOrderPrint.fromJson(Map<String, dynamic> json) =>
      SalaryChangeOrderPrint(
        html: json['html']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        draftBanner: json['draft_banner'] == true,
      );

  final String html;
  final String status;
  final String number;
  final bool draftBanner;
}

class SalaryChangeOrderRepository {
  SalaryChangeOrderRepository(this._client);

  final FrappeApiClient _client;
  static const _prefix = 'asoud_erp.api.v1.salary_change_orders.';

  Future<Map<String, dynamic>?> getTemplate({required String company}) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}get_salary_change_order_template',
      data: {'company': company},
    ) as Map;
    final tpl = result['template'];
    return tpl != null ? Map<String, dynamic>.from(tpl as Map) : null;
  }

  Future<Map<String, dynamic>> saveTemplate({
    required String company,
    int revision = 0,
    required Map<String, dynamic> template,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}save_salary_change_order_template',
      data: {
        'company': company,
        'revision': revision,
        'template': template,
      },
    ) as Map;
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> publishTemplate({
    required String company,
    int revision = 0,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}publish_salary_change_order_template',
      data: {
        'company': company,
        'revision': revision,
      },
    ) as Map;
    return Map<String, dynamic>.from(result);
  }

  Future<List<SalaryChangeOrderPerson>> people({
    required String company,
    String search = '',
    int limitStart = 0,
    int limitPageLength = 50,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}list_salary_change_order_people',
      data: {
        'company': company,
        'search': search,
        'limit_start': limitStart,
        'limit_page_length': limitPageLength,
      },
    ) as List;
    return result
        .whereType<Map>()
        .map((m) =>
            SalaryChangeOrderPerson.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<SalaryChangePayrollResult> payroll({
    required String company,
    required String employee,
    required String effectiveDate,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}get_salary_change_order_payroll',
      data: {
        'company': company,
        'employee': employee,
        'effective_date': effectiveDate,
      },
    ) as Map;
    return SalaryChangePayrollResult.fromJson(
        Map<String, dynamic>.from(result));
  }

  Future<List<SalaryChangeOrderSummary>> listOrders({
    required String company,
    String search = '',
    String status = '',
    String applicationStatus = '',
    int limitStart = 0,
    int limitPageLength = 20,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}list_salary_change_orders',
      data: {
        'company': company,
        'search': search,
        'status': status,
        'application_status': applicationStatus,
        'limit_start': limitStart,
        'limit_page_length': limitPageLength,
      },
    ) as Map;
    final items = (result['items'] as List?) ?? [];
    return items
        .whereType<Map>()
        .map((m) =>
            SalaryChangeOrderSummary.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<SalaryChangeOrderDetail> getOrder({required String name}) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}get_salary_change_order',
      data: {'name': name},
    ) as Map;
    return SalaryChangeOrderDetail.fromJson(
        Map<String, dynamic>.from(result));
  }

  Future<SalaryChangeOrderDetail> saveOrder({
    required String company,
    required String requestId,
    int revision = 0,
    String? order,
    required String employee,
    required String effectiveDate,
    String reason = 'annual',
    String description = '',
    String? issueDate,
    String? draftedOn,
    Map<String, dynamic> values = const {},
    List<Map<String, dynamic>> comparisonRows = const [],
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}save_salary_change_order',
      data: {
        'company': company,
        'request_id': requestId,
        'revision': revision,
        if (order != null) 'order': order,
        'employee': employee,
        'effective_date': effectiveDate,
        'reason': reason,
        'description': description,
        if (issueDate != null) 'issue_date': issueDate,
        if (draftedOn != null) 'drafted_on': draftedOn,
        'values': values,
        'comparison_rows': comparisonRows,
      },
    ) as Map;
    return SalaryChangeOrderDetail.fromJson(
        Map<String, dynamic>.from(result));
  }

  Future<SalaryChangeOrderDetail> sendForReview({
    required String name,
    required int revision,
    required String requestId,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}send_salary_change_order_for_review',
      data: {
        'name': name,
        'revision': revision,
        'request_id': requestId,
      },
    ) as Map;
    return SalaryChangeOrderDetail.fromJson(
        Map<String, dynamic>.from(result));
  }

  Future<SalaryChangeOrderDetail> approveOrder({
    required String name,
    required int revision,
    required String requestId,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}approve_salary_change_order',
      data: {
        'name': name,
        'revision': revision,
        'request_id': requestId,
      },
    ) as Map;
    return SalaryChangeOrderDetail.fromJson(
        Map<String, dynamic>.from(result));
  }

  Future<SalaryChangeOrderDetail> rejectOrder({
    required String name,
    required int revision,
    String reason = '',
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}reject_salary_change_order',
      data: {
        'name': name,
        'revision': revision,
        'reason': reason,
      },
    ) as Map;
    return SalaryChangeOrderDetail.fromJson(
        Map<String, dynamic>.from(result));
  }

  Future<SalaryChangeOrderDetail> applyToPayroll({
    required String name,
    required String operationId,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}apply_salary_change_order_to_payroll',
      data: {
        'name': name,
        'operation_id': operationId,
      },
    ) as Map;
    return SalaryChangeOrderDetail.fromJson(
        Map<String, dynamic>.from(result));
  }

  Future<SalaryChangeOrderPrint> printOrder({required String name}) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}print_salary_change_order',
      data: {'name': name},
    ) as Map;
    return SalaryChangeOrderPrint.fromJson(
        Map<String, dynamic>.from(result));
  }
}
