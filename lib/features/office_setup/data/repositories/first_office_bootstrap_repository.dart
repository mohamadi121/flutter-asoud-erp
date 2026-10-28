import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';

class FirstOfficeBootstrapStatus {
  const FirstOfficeBootstrapStatus(
      {this.fullName,
      this.username,
      this.hrReady = false,
      this.completed = false});

  factory FirstOfficeBootstrapStatus.fromJson(Map<String, dynamic> json) {
    final lead = json['hr_lead'];
    if (json['hr_ready'] is! bool ||
        json['completed'] is! bool ||
        (lead != null &&
            (lead is! Map ||
                lead['full_name'] is! String ||
                lead['username'] is! String))) {
      throw const ApiException.protocol();
    }
    return FirstOfficeBootstrapStatus(
        fullName: lead is Map ? lead['full_name'] as String : null,
        username: lead is Map ? lead['username'] as String : null,
        hrReady: json['hr_ready'] == true,
        completed: json['completed'] == true);
  }
  final String? fullName, username;
  final bool hrReady, completed;
}

/// Online only: never queue credentials or save temporary passwords on device.
class FirstOfficeBootstrapRepository {
  FirstOfficeBootstrapRepository(this.client);
  final FrappeApiClient client;

  Future<FirstOfficeBootstrapStatus> _call(
      String method, Map<String, dynamic> data) async {
    final body = await client
        .callMethod('asoud_erp.api.v1.first_office_setup.$method', data: data);
    final envelope = body['message'];
    final result = envelope is Map ? envelope['data'] : null;
    if (envelope is! Map || envelope['ok'] != true || result is! Map) {
      throw const ApiException.protocol();
    }
    return FirstOfficeBootstrapStatus.fromJson(
        Map<String, dynamic>.from(result));
  }

  // The paired server serializes status and create_hr_lead on the company row.
  // A null lead is definitive only after that lock settles; a lock timeout is
  // an error and must leave credential editing disabled in the setup page.
  Future<FirstOfficeBootstrapStatus> status(String company) =>
      _call('status', {'company': company});
  Future<FirstOfficeBootstrapStatus> complete(String company) =>
      _call('complete', {'company': company});
  Future<FirstOfficeBootstrapStatus> create(
          {required String company,
          required String fullName,
          required String username,
          required String contact,
          required String temporaryPassword}) =>
      _call('create_hr_lead', {
        'company': company,
        'full_name': fullName,
        'username': username,
        'contact': contact,
        'temporary_password': temporaryPassword,
      });
}
