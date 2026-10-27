import '../../../core/network/frappe_client.dart';

class HiringOrderPerson {
  const HiringOrderPerson({
    required this.name,
    required this.displayName,
    required this.employeeNumber,
  });

  factory HiringOrderPerson.fromJson(Map<String, dynamic> json) =>
      HiringOrderPerson(
        name: json['name']?.toString() ?? '',
        displayName: json['display_name']?.toString() ?? 'پرسنل منتسب',
        employeeNumber: json['employee_number']?.toString() ?? '',
      );

  final String name;
  final String displayName;
  final String employeeNumber;
}

class HiringOrderPayrollRow {
  const HiringOrderPayrollRow({
    required this.id,
    required this.title,
    required this.period,
    required this.amount,
    required this.state,
    required this.message,
  });

  factory HiringOrderPayrollRow.fromJson(Map<String, dynamic> json) =>
      HiringOrderPayrollRow(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        period: json['period']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble(),
        state: json['state']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
      );

  final String id;
  final String title;
  final String period;
  final double? amount;
  final String state;
  final String message;

  bool get isMissing => state == 'missing' || amount == null;
}

class HiringOrderPayroll {
  const HiringOrderPayroll({required this.currency, required this.rows});

  factory HiringOrderPayroll.fromJson(Map<String, dynamic> json) =>
      HiringOrderPayroll(
        currency: json['currency']?.toString() ?? '',
        rows: ((json['rows'] as List?) ?? const [])
            .map((row) => HiringOrderPayrollRow.fromJson(
                Map<String, dynamic>.from(row as Map)))
            .toList(growable: false),
      );

  final String currency;
  final List<HiringOrderPayrollRow> rows;
}

class HiringOrderRepository {
  HiringOrderRepository(this._client);

  final FrappeApiClient _client;
  static const _prefix = 'asoud_erp.api.v1.hiring_orders.';

  Future<List<HiringOrderPerson>> people({
    required String company,
    String search = '',
  }) async {
    final result = await _client.callAsoudMethod(
      '${_prefix}list_hiring_order_people',
      data: {'company': company, if (search.trim().isNotEmpty) 'search': search},
    ) as List;
    return result
        .map((row) => HiringOrderPerson.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<HiringOrderPayroll> payroll({
    required String company,
    required String employee,
    required String effectiveDate,
  }) async =>
      HiringOrderPayroll.fromJson(Map<String, dynamic>.from(
        await _client.callAsoudMethod('${_prefix}get_hiring_order_payroll', data: {
          'company': company,
          'employee': employee,
          'effective_date': effectiveDate,
        }) as Map,
      ));
}
