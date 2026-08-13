import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_failure.dart';
import '../domain/hr_models.dart';
import '../domain/hr_repository.dart';

class ServerFirstHrRepository implements HrRepository {
  ServerFirstHrRepository(this.remote, {LocalRecordStore? local})
      : local = local ?? LocalDatabaseStore.instance;
  final HrRepository remote;
  final LocalRecordStore local;

  @override
  Future<HrDashboard> dashboard(String company) => remote.dashboard(company);
  @override
  Future<HrEmployee> myProfile() => remote.myProfile();
  @override
  Future<List<HrEmployee>> team({String query = ''}) =>
      remote.team(query: query);
  @override
  Future<List<Map<String, dynamic>>> organization(String company) =>
      remote.organization(company);

  @override
  Future<List<WorkReport>> reports() async {
    try {
      final values = await remote.reports();
      for (final value in values) {
        await _saveReport(value, LocalSyncStatus.synced);
      }
      return _mergeReports(values, await _localReports());
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      return _localReports();
    }
  }

  @override
  Future<WorkReport> saveReport(WorkReport report) async {
    try {
      final saved = await remote.saveReport(report);
      await _saveReport(saved, LocalSyncStatus.synced);
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final localValue = report.id.isEmpty
          ? WorkReport(
              id: 'local-${DateTime.now().microsecondsSinceEpoch}',
              date: report.date,
              status: report.status,
              activities: report.activities,
              totalMinutes: report.activities
                  .fold(0, (sum, item) => sum + item.durationMinutes),
              managerComment: report.managerComment)
          : report;
      await _saveReport(localValue, LocalSyncStatus.pendingSync);
      return localValue;
    }
  }

  Future<void> _saveReport(WorkReport value, LocalSyncStatus status) =>
      local.save(
          id: 'hr-report:${value.id}',
          entityType: 'hr_work_report',
          payload: value.toJson(),
          status: status);
  Future<List<WorkReport>> _localReports() async =>
      (await local.list(entityType: 'hr_work_report'))
          .map((e) => WorkReport.fromJson(e.payload))
          .toList();
  List<WorkReport> _mergeReports(
          List<WorkReport> remoteValues, List<WorkReport> localValues) =>
      <String, WorkReport>{
        for (final e in remoteValues) e.id: e,
        for (final e in localValues) e.id: e
      }.values.toList();

  @override
  Future<List<HrCommunication>> communications({String box = 'inbox'}) async {
    try {
      final values = await remote.communications(box: box);
      for (final value in values) {
        await _saveCommunication(value, LocalSyncStatus.synced);
      }
      return _mergeCommunications(values, await _localCommunications());
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      return _localCommunications();
    }
  }

  @override
  Future<HrCommunication> sendCommunication(HrCommunication value) async {
    try {
      final saved = await remote.sendCommunication(value);
      await _saveCommunication(saved, LocalSyncStatus.synced);
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final localValue = HrCommunication(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          subject: value.subject,
          content: value.content,
          sender: value.sender,
          type: value.type,
          priority: value.priority,
          status: 'Draft',
          confidential: value.confidential,
          recipients: value.recipients);
      await _saveCommunication(localValue, LocalSyncStatus.pendingSync);
      return localValue;
    }
  }

  Future<void> _saveCommunication(
          HrCommunication value, LocalSyncStatus status) =>
      local.save(
          id: 'hr-communication:${value.id}',
          entityType: 'hr_communication',
          payload: value.toJson()
            ..['name'] = value.id
            ..['status'] = value.status,
          status: status);
  Future<List<HrCommunication>> _localCommunications() async =>
      (await local.list(entityType: 'hr_communication'))
          .map((e) => HrCommunication.fromJson(e.payload))
          .toList();
  List<HrCommunication> _mergeCommunications(
          List<HrCommunication> a, List<HrCommunication> b) =>
      <String, HrCommunication>{
        for (final e in a) e.id: e,
        for (final e in b) e.id: e
      }.values.toList();
  @override
  Future<List<Map<String, dynamic>>> notifications() => remote.notifications();
}
