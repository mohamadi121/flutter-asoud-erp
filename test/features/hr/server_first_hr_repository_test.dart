import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/hr/data/server_first_hr_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_models.dart';
import 'package:asoud_erp/features/hr/domain/hr_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

void main() {
  test('داشبورد HR بدون سرور به حالت خالی قابل استفاده برمی‌گردد', () async {
    final repository = ServerFirstHrRepository(_OfflineHrRepository(),
        local: FakeLocalRecordStore());

    final dashboard = await repository.dashboard('دفتر');

    expect(dashboard.employee.id, isEmpty);
    expect(dashboard.employee.company, 'دفتر');
  });

  test('پرسنل ثبت‌شده محلی در فهرست HR دیده می‌شود', () async {
    final local = FakeLocalRecordStore();
    await local.save(
      id: 'party:local-1',
      entityType: 'party_profile',
      payload: const {
        'id': 'local-1',
        'display_name': 'پرسنل محلی',
        'company': 'دفتر',
        'roles': ['employee'],
        'department': 'مالی',
      },
      status: LocalSyncStatus.pendingSync,
    );
    final repository =
        ServerFirstHrRepository(_OfflineHrRepository(), local: local);

    final team = await repository.team();

    expect(team.single.name, 'پرسنل محلی');
    expect(team.single.department, 'مالی');
  });

  test('پیش‌نویس گزارش کار در قطع اتصال روی گوشی باقی می‌ماند', () async {
    final local = FakeLocalRecordStore();
    final repository =
        ServerFirstHrRepository(_OfflineHrRepository(), local: local);
    final report = WorkReport(
        date: DateTime(2026, 8, 13),
        activities: const [WorkActivity(title: 'تحلیل', durationMinutes: 60)]);

    final saved = await repository.saveReport(report);
    final restored = await repository.reports();

    expect(saved.id, startsWith('local-'));
    expect(restored.single.activities.single.title, 'تحلیل');
    expect(local.records.values.single.status, LocalSyncStatus.pendingSync);
  });

  test('پیش‌نویس مکاتبه در قطع اتصال روی گوشی باقی می‌ماند', () async {
    final local = FakeLocalRecordStore();
    final repository =
        ServerFirstHrRepository(_OfflineHrRepository(), local: local);
    const communication = HrCommunication(
        subject: 'درخواست',
        content: 'متن',
        recipients: ['manager@example.com']);

    await repository.sendCommunication(communication);
    final restored = await repository.communications();

    expect(restored.single.subject, 'درخواست');
    expect(restored.single.recipients, ['manager@example.com']);
  });
}

class _OfflineHrRepository implements HrRepository {
  Never get offline => throw const ApiException(
      kind: ApiFailureKind.network, message: 'offline');
  @override
  Future<HrDashboard> dashboard(String company) async => offline;
  @override
  Future<HrEmployee> myProfile() async => offline;
  @override
  Future<List<HrEmployee>> team({String query = ''}) async => offline;
  @override
  Future<List<Map<String, dynamic>>> organization(String company) async =>
      offline;
  @override
  Future<List<WorkReport>> reports() async => offline;
  @override
  Future<WorkReport> saveReport(WorkReport report) async => offline;
  @override
  Future<List<HrCommunication>> communications({String box = 'inbox'}) async =>
      offline;
  @override
  Future<HrCommunication> sendCommunication(
          HrCommunication communication) async =>
      offline;
  @override
  Future<List<Map<String, dynamic>>> notifications() async => offline;
}
