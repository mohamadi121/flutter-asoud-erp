import '../../../core/network/api_exception.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/hr_models.dart';

/// What `hr.save_report` answers: `{name, status, report_date, total_minutes,
/// review: {route, superior, superior_name, note}}`.
class WorkReportSendResult {
  const WorkReportSendResult({
    required this.name,
    required this.status,
    this.route = '',
    this.superiorName,
    this.note,
  });

  factory WorkReportSendResult.fromJson(Map<String, dynamic> json) {
    final review = json['review'];
    final map =
        review is Map ? Map<String, dynamic>.from(review) : const <String, dynamic>{};
    String? text(Object? v) {
      final value = '${v ?? ''}'.trim();
      return value.isEmpty ? null : value;
    }

    return WorkReportSendResult(
      name: '${json['name'] ?? ''}',
      status: '${json['status'] ?? ''}',
      route: '${map['route'] ?? ''}',
      superiorName: text(map['superior_name']),
      note: text(map['note']),
    );
  }

  final String name;
  final String status;

  /// `direct_manager` or `managers_pool` (no direct superior defined).
  final String route;
  final String? superiorName;
  final String? note;

  /// The line shown after a successful send.
  String get message => route == 'managers_pool'
      ? (note ?? 'گزارش برای مدیر کل سیستم یا مدیر منابع انسانی ارسال شد.')
      : superiorName == null
          ? 'گزارش برای مافوق ارسال شد.'
          : 'گزارش برای $superiorName ارسال شد.';
}

/// Sends a work report to the reporting superior.
///
/// The backend has no separate "submit" method: `hr.save_report` stores the
/// report with `status: "Submitted"` and answers who reviews it. The payload
/// must contain the activities (the server replaces them), which is why only a
/// report whose activities are known on the device can be sent.
///
/// The call is online-only (`callMethod`): a send must never be reported as
/// delivered while it only sits in the offline queue.
class WorkReportSubmissionRepository {
  WorkReportSubmissionRepository(this.client);
  final FrappeApiClient client;

  Future<WorkReportSendResult> send(WorkReport report) async {
    final body = await client.callMethod('asoud_erp.api.v1.hr.save_report',
        data: {
          'payload': {...report.toJson(), 'status': 'Submitted'}
        });
    final envelope = body['message'];
    final data = envelope is Map ? envelope['data'] : null;
    if (envelope is! Map || envelope['ok'] != true || data is! Map) {
      throw const ApiException.protocol();
    }
    return WorkReportSendResult.fromJson(Map<String, dynamic>.from(data));
  }
}
