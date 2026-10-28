import '../../../core/network/frappe_client.dart';

class HiringOrderPerson {
  const HiringOrderPerson({
    required this.name,
    required this.displayName,
    required this.employeeNumber,
    this.department = '',
    this.designation = '',
  });

  factory HiringOrderPerson.fromJson(Map<String, dynamic> json) =>
      HiringOrderPerson(
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

class HiringOrderPayrollRow {
  const HiringOrderPayrollRow({
    required this.id,
    required this.title,
    required this.period,
    required this.amount,
    required this.state,
    required this.message,
    this.fieldRef = '',
  });

  factory HiringOrderPayrollRow.fromJson(Map<String, dynamic> json) =>
      HiringOrderPayrollRow(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        period: json['period']?.toString() ?? 'monthly',
        amount: (json['amount'] as num?)?.toDouble(),
        state: json['state']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        fieldRef: json['field_ref']?.toString() ?? '',
      );

  final String id;
  final String title;
  final String period;
  final double? amount;
  final String state;
  final String message;
  final String fieldRef;

  bool get isMissing => state == 'missing' || amount == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'period': period,
        'amount': amount,
        if (fieldRef.isNotEmpty) 'field_ref': fieldRef,
      };
}

class HiringOrderPayroll {
  const HiringOrderPayroll({
    required this.currency,
    required this.rows,
    this.monthlyTotal,
  });

  factory HiringOrderPayroll.fromJson(Map<String, dynamic> json) =>
      HiringOrderPayroll(
        currency: json['currency']?.toString() ?? 'ریال',
        monthlyTotal: (json['monthly_total'] as num?)?.toDouble(),
        rows: ((json['rows'] as List?) ?? const [])
            .map((row) => HiringOrderPayrollRow.fromJson(
                Map<String, dynamic>.from(row as Map)))
            .toList(growable: false),
      );

  final String currency;
  final List<HiringOrderPayrollRow> rows;
  final double? monthlyTotal;

  bool get hasMissing => rows.any((r) => r.isMissing);
}

class HiringOrderSummary {
  const HiringOrderSummary({
    required this.name,
    required this.number,
    required this.employee,
    required this.employeeName,
    required this.status,
    required this.statusLabel,
    required this.effectiveDate,
    required this.issueDate,
    required this.draftedOn,
    required this.revision,
  });

  factory HiringOrderSummary.fromJson(Map<String, dynamic> json) =>
      HiringOrderSummary(
        name: json['name']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        employee: json['employee']?.toString() ?? '',
        employeeName: json['employee_name']?.toString() ?? '',
        status: json['status']?.toString() ?? 'draft',
        statusLabel: json['status_label']?.toString() ?? 'پیش‌نویس',
        effectiveDate: json['effective_date']?.toString() ?? '',
        issueDate: json['issue_date']?.toString() ?? '',
        draftedOn: json['drafted_on']?.toString() ?? '',
        revision: (json['revision'] as num?)?.toInt() ?? 1,
      );

  final String name;
  final String number;
  final String employee;
  final String employeeName;
  final String status;
  final String statusLabel;
  final String effectiveDate;
  final String issueDate;
  final String draftedOn;
  final int revision;

  bool get isDraft => status == 'draft';
  bool get isFinal => status == 'final';
  bool get isPending => status == 'pending';
}

class HiringOrderDetail {
  const HiringOrderDetail({
    required this.name,
    required this.number,
    required this.company,
    required this.companyName,
    required this.employee,
    required this.employeeName,
    required this.employeeNumber,
    required this.status,
    required this.statusLabel,
    required this.effectiveDate,
    required this.issueDate,
    required this.draftedOn,
    required this.department,
    required this.designation,
    required this.location,
    required this.values,
    required this.templateSnapshot,
    required this.payrollSnapshot,
    required this.revision,
  });

  factory HiringOrderDetail.fromJson(Map<String, dynamic> json) =>
      HiringOrderDetail(
        name: json['name']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        company: json['company']?.toString() ?? '',
        companyName: json['company_name']?.toString() ?? '',
        employee: json['employee']?.toString() ?? '',
        employeeName: json['employee_name']?.toString() ?? 'پرسنل منتسب',
        employeeNumber: json['employee_number']?.toString() ?? '',
        status: json['status']?.toString() ?? 'draft',
        statusLabel: json['status_label']?.toString() ?? 'پیش‌نویس',
        effectiveDate: json['effective_date']?.toString() ?? '',
        issueDate: json['issue_date']?.toString() ?? '',
        draftedOn: json['drafted_on']?.toString() ?? '',
        department: json['department']?.toString() ?? '',
        designation: json['designation']?.toString() ?? '',
        location: json['location']?.toString() ?? '',
        values: Map<String, dynamic>.from((json['values'] as Map?) ?? const {}),
        templateSnapshot: Map<String, dynamic>.from(
            (json['template_snapshot'] as Map?) ?? const {}),
        payrollSnapshot: json['payroll_snapshot'] != null
            ? HiringOrderPayroll.fromJson(
                Map<String, dynamic>.from(json['payroll_snapshot'] as Map))
            : null,
        revision: (json['revision'] as num?)?.toInt() ?? 1,
      );

  final String name;
  final String number;
  final String company;
  final String companyName;
  final String employee;
  final String employeeName;
  final String employeeNumber;
  final String status;
  final String statusLabel;
  final String effectiveDate;
  final String issueDate;
  final String draftedOn;
  final String department;
  final String designation;
  final String location;
  final Map<String, dynamic> values;
  final Map<String, dynamic> templateSnapshot;
  final HiringOrderPayroll? payrollSnapshot;
  final int revision;

  bool get isDraft => status == 'draft';
  bool get isFinal => status == 'final';
  bool get isPending => status == 'pending';
}

class HiringOrderPrint {
  const HiringOrderPrint({
    required this.html,
    required this.status,
    required this.number,
    required this.draftBanner,
  });

  factory HiringOrderPrint.fromJson(Map<String, dynamic> json) =>
      HiringOrderPrint(
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

class HiringOrderRepository {
  HiringOrderRepository(this._client);

  final FrappeApiClient _client;
  static const _prefix = 'asoud_erp.api.v1.hiring_orders.';

  Future<Map<String, dynamic>?> getTemplate({required String company}) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}get_hiring_order_template',
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
      '${_prefix}save_hiring_order_template',
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
      '${_prefix}publish_hiring_order_template',
      data: {
        'company': company,
        'revision': revision,
      },
    ) as Map;
    return Map<String, dynamic>.from(result);
  }

  Future<List<HiringOrderPerson>> people({
    required String company,
    String search = '',
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}list_hiring_order_people',
      data: {'company': company, if (search.trim().isNotEmpty) 'search': search},
    ) as List;
    return result
        .map((row) =>
            HiringOrderPerson.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<HiringOrderPayroll> payroll({
    required String company,
    required String employee,
    required String effectiveDate,
  }) async =>
      HiringOrderPayroll.fromJson(Map<String, dynamic>.from(
        await _client.callAsoudMethod(
          '${_prefix}get_hiring_order_payroll',
          data: {
            'company': company,
            'employee': employee,
            'effective_date': effectiveDate,
          },
        ) as Map,
      ));

  Future<List<Map<String, dynamic>>> payrollCatalog({
    required String company,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}get_hiring_order_payroll_catalog',
      data: {'company': company},
    ) as Map;
    final items = (result['items'] as List?) ?? const [];
    return items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<List<HiringOrderSummary>> listOrders({
    required String company,
    String search = '',
    String status = '',
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}list_hiring_orders',
      data: {
        'company': company,
        if (search.trim().isNotEmpty) 'search': search,
        if (status.trim().isNotEmpty) 'status': status,
      },
    ) as Map;
    final items = (result['items'] as List?) ?? const [];
    return items
        .map((row) =>
            HiringOrderSummary.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<HiringOrderDetail> getOrder({required String name}) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}get_hiring_order',
      data: {'name': name},
    ) as Map;
    return HiringOrderDetail.fromJson(Map<String, dynamic>.from(result));
  }

  Future<HiringOrderDetail> saveOrder({
    required String company,
    required String requestId,
    int revision = 0,
    String? order,
    required String employee,
    required String effectiveDate,
    String? issueDate,
    String? draftedOn,
    required Map<String, dynamic> values,
    List<Map<String, dynamic>>? payrollRows,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}save_hiring_order',
      data: {
        'company': company,
        'request_id': requestId,
        'revision': revision,
        if (order != null) 'order': order,
        'employee': employee,
        'effective_date': effectiveDate,
        if (issueDate != null) 'issue_date': issueDate,
        if (draftedOn != null) 'drafted_on': draftedOn,
        'values': values,
        if (payrollRows != null) 'payroll_rows': payrollRows,
      },
    ) as Map;
    return HiringOrderDetail.fromJson(Map<String, dynamic>.from(result));
  }

  Future<HiringOrderDetail> sendForReview({
    required String name,
    required int revision,
    required String requestId,
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}send_hiring_order_for_review',
      data: {
        'name': name,
        'revision': revision,
        'request_id': requestId,
      },
    ) as Map;
    return HiringOrderDetail.fromJson(Map<String, dynamic>.from(result));
  }

  Future<HiringOrderPrint> printOrder({required String name}) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}print_hiring_order',
      data: {'name': name},
    ) as Map;
    return HiringOrderPrint.fromJson(Map<String, dynamic>.from(result));
  }
}
