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
  Future<HrDashboard> dashboard(String company) async {
    try {
      final value = await remote.dashboard(company);
      await local.save(
        id: 'hr-dashboard:${Uri.encodeComponent(company)}',
        entityType: 'hr_dashboard:$company',
        payload: _dashboardToJson(value),
        status: LocalSyncStatus.synced,
      );
      return value;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final cached = await local.get(
        'hr-dashboard:${Uri.encodeComponent(company)}',
      );
      if (cached != null) return HrDashboard.fromJson(cached.payload);
      return HrDashboard(
        employee: HrEmployee(id: '', name: '', company: company),
      );
    }
  }

  @override
  Future<HrEmployee> myProfile() async {
    try {
      final value = await remote.myProfile();
      await local.save(
        id: 'hr-profile:me',
        entityType: 'hr_profile',
        payload: value.toJson(),
        status: LocalSyncStatus.synced,
      );
      return value;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final cached = await local.get('hr-profile:me');
      return cached == null
          ? const HrEmployee(id: '', name: '', company: '')
          : HrEmployee.fromJson(cached.payload);
    }
  }

  @override
  Future<List<HrEmployee>> team({String query = ''}) async {
    try {
      final values = await remote.team(query: query);
      for (final value in values) {
        await local.save(
          id: 'hr-employee:${value.id}',
          entityType: 'hr_employee',
          payload: value.toJson(),
          status: LocalSyncStatus.synced,
        );
      }
      return values;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final values = (await local.list(entityType: 'hr_employee'))
          .map((record) => HrEmployee.fromJson(record.payload));
      final partyEmployees = (await local.list(entityType: 'party_profile'))
          .where((record) => (record.payload['roles'] as List? ?? const [])
              .map((role) => role.toString())
              .contains('employee'))
          .map((record) => HrEmployee(
                id: record.payload['id']?.toString() ?? '',
                name: record.payload['display_name']?.toString() ?? '',
                company: record.payload['company']?.toString() ?? '',
                department: record.payload['department']?.toString() ?? '',
                designation: record.payload['job_title']?.toString() ?? '',
                phone: record.payload['mobile']?.toString() ?? '',
                email: record.payload['email']?.toString() ?? '',
              ));
      return [...values, ...partyEmployees]
          .where((item) => query.isEmpty || item.name.contains(query))
          .toList(growable: false);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> organization(String company) async {
    try {
      final values = await remote.organization(company);
      await local.save(
        id: 'hr-organization:${Uri.encodeComponent(company)}',
        entityType: 'hr_organization:$company',
        payload: {'items': values},
        status: LocalSyncStatus.synced,
      );
      return values;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final cached = await local.get(
        'hr-organization:${Uri.encodeComponent(company)}',
      );
      return (cached?.payload['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
  }

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
  Future<List<Map<String, dynamic>>> notifications() async {
    try {
      final values = await remote.notifications();
      await local.save(
        id: 'hr-notifications',
        entityType: 'hr_notifications',
        payload: {'items': values},
        status: LocalSyncStatus.synced,
      );
      return values;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final cached = await local.get('hr-notifications');
      return (cached?.payload['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
  }

  Map<String, dynamic> _dashboardToJson(HrDashboard value) => {
        'employee': value.employee.toJson(),
        'pending_tasks': value.pendingTasks,
        'unread_notifications': value.unreadNotifications,
        'unread_communications': value.unreadCommunications,
        'today_report': value.todayReportStatus == null
            ? null
            : {'status': value.todayReportStatus},
      };
}
