import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/employee/data/preview_hr_repository.dart';
import 'package:asoud_erp/features/employee/data/self_service_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_models.dart';
import 'package:asoud_erp/features/hr/domain/hr_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements FrappeApiClient {}

class _ThrowingHr extends Fake implements HrRepository {
  @override
  Future<HrDashboard> dashboard(String company) => throw UnimplementedError();
  @override
  Future<HrEmployee> myProfile() => throw UnimplementedError();
  @override
  Future<List<HrEmployee>> team({String query = ''}) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> organization(String company) =>
      throw UnimplementedError();
  @override
  Future<List<WorkReport>> reports() => throw UnimplementedError();
  @override
  Future<WorkReport> saveReport(WorkReport report) =>
      throw UnimplementedError();
  @override
  Future<List<HrCommunication>> communications({String box = 'inbox'}) =>
      throw UnimplementedError();
  @override
  Future<HrCommunication> sendCommunication(HrCommunication communication) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> notifications() =>
      throw UnimplementedError();
}

void main() {
  late _Client client;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream.empty());
  });

  test('preview attendance has check-in history relative to now', () async {
    final repository = SelfServiceRepository(client);
    final logs = await repository.checkins();
    expect(logs, isNotEmpty);
    expect(logs.first['log_type'], anyOf(['IN', 'OUT']));
    final last = DateTime.parse('${logs.first['time']}');
    expect(DateTime.now().difference(last).inHours, lessThan(24));
    final days = await repository.attendance('2000-01-01', '2100-01-01');
    expect(days.map((day) => day['status']), contains('Present'));
    expect(days.map((day) => day['status']), contains('On Leave'));
  });

  test('preview check-in is recorded on the device', () async {
    final repository = SelfServiceRepository(client);
    final before = (await repository.checkins()).length;
    await repository.checkin('IN');
    final after = await repository.checkins();
    expect(after.length, before + 1);
    expect(after.first['log_type'], 'IN');
  });

  test('preview HR home has status, reports and both boxes', () async {
    final repository =
        PreviewHrRepository(_ThrowingHr(), isPreview: () => true);
    final dashboard = await repository.dashboard('شرکت نمونه آسود');
    expect(dashboard.employee.name, 'سارا محمدی');
    expect(dashboard.todayReportStatus, 'ثبت شده');
    expect(dashboard.pendingTasks, 3);

    final reports = await repository.reports();
    expect(reports.map((report) => report.status),
        containsAll(['Draft', 'Submitted']));
    final submitted =
        reports.firstWhere((report) => report.status == 'Submitted');
    expect(submitted.managerComment, isNotEmpty);
    expect(submitted.activities, isNotEmpty);

    final inbox = await repository.communications();
    expect(inbox.map((item) => item.subject), contains('جلسه هماهنگی فروش'));
    final sent = await repository.communications(box: 'sent');
    expect(
        sent.map((item) => item.subject), contains('درخواست مرخصی استحقاقی'));
  });

  test('preview notifications are five with mixed read flags', () async {
    final repository =
        PreviewHrRepository(_ThrowingHr(), isPreview: () => true);
    final items = await repository.notifications();
    expect(items, hasLength(5));
    expect(
        items.map((item) => item['subject']), contains('مرخصی شما تأیید شد'));
    expect(items.where((item) => item['is_read'] == true), hasLength(2));
    expect(items.where((item) => item['is_read'] != true), hasLength(3));
  });

  test('a saved draft stays local in preview and is listed', () async {
    final repository =
        PreviewHrRepository(_ThrowingHr(), isPreview: () => true);
    final saved = await repository.saveReport(WorkReport(
      date: DateTime.now(),
      activities: const [
        WorkActivity(title: 'پیگیری مشتری', durationMinutes: 60)
      ],
    ));
    expect(saved.id, startsWith('LOCAL-DEMO-'));
    expect((await repository.reports()).first.activities.single.title,
        'پیگیری مشتری');
    final sent = await repository.sendCommunication(const HrCommunication(
        subject: 'درخواست جلسه',
        content: 'لطفاً زمان جلسه را اعلام کنید.',
        recipients: ['احمد رضایی']));
    expect(sent.status, 'Sent');
    expect((await repository.communications(box: 'sent')).length, 3);
  });

  test('an authenticated session delegates to the real repository', () async {
    final remote = _ThrowingHr();
    final repository = PreviewHrRepository(remote, isPreview: () => false);
    await expectLater(
        () => repository.dashboard('x'), throwsUnimplementedError);
    await expectLater(() => repository.reports(), throwsUnimplementedError);
    await expectLater(
        () => repository.communications(), throwsUnimplementedError);
  });
}
