import 'hr_models.dart';

abstract interface class HrRepository {
  Future<HrDashboard> dashboard(String company);
  Future<HrEmployee> myProfile();
  Future<List<HrEmployee>> team({String query = ''});
  Future<List<Map<String, dynamic>>> organization(String company);
  Future<List<WorkReport>> reports();
  Future<WorkReport> saveReport(WorkReport report);
  Future<List<HrCommunication>> communications({String box = 'inbox'});
  Future<HrCommunication> sendCommunication(HrCommunication communication);
  Future<List<Map<String, dynamic>>> notifications();
}
