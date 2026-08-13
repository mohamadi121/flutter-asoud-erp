import '../../../core/network/frappe_client.dart';
import '../domain/hr_models.dart';
import '../domain/hr_repository.dart';

class FrappeHrRepository implements HrRepository {
  const FrappeHrRepository(this.client);
  final FrappeClient client;
  Future<dynamic> _call(String method, [Map<String, dynamic>? data]) =>
      client.callAsoudMethod('asoud_erp.api.v1.hr.$method', data: data);
  @override
  Future<HrDashboard> dashboard(String company) async =>
      HrDashboard.fromJson(Map<String, dynamic>.from(
          await _call('get_dashboard', {'company': company}) as Map));
  @override
  Future<HrEmployee> myProfile() async => HrEmployee.fromJson(
      Map<String, dynamic>.from(await _call('get_my_profile') as Map));
  @override
  Future<List<HrEmployee>> team({String query = ''}) async =>
      (await _call('list_team', {'query': query}) as List)
          .whereType<Map>()
          .map((e) => HrEmployee.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  @override
  Future<List<Map<String, dynamic>>> organization(String company) async =>
      (await _call('organization_tree', {'company': company}) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  @override
  Future<List<WorkReport>> reports() async =>
      (await _call('list_reports') as List)
          .whereType<Map>()
          .map((e) => WorkReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  @override
  Future<WorkReport> saveReport(WorkReport report) async =>
      WorkReport.fromJson(Map<String, dynamic>.from(
          await _call('save_report', {'payload': report.toJson()}) as Map));
  @override
  Future<List<HrCommunication>> communications({String box = 'inbox'}) async =>
      (await _call('list_communications', {'box': box}) as List)
          .whereType<Map>()
          .map((e) => HrCommunication.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  @override
  Future<HrCommunication> sendCommunication(HrCommunication value) async {
    final result = Map<String, dynamic>.from(
        await _call('create_communication', {'payload': value.toJson()})
            as Map);
    return HrCommunication(
        id: result['name']?.toString() ?? '',
        subject: value.subject,
        content: value.content,
        recipients: value.recipients,
        status: result['status']?.toString() ?? 'Sent');
  }

  @override
  Future<List<Map<String, dynamic>>> notifications() async =>
      (await _call('list_notifications') as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
}
