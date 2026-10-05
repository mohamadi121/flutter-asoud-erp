import '../../hr/domain/hr_models.dart';
import '../../hr/domain/hr_repository.dart';
import '../../office_setup/data/demo/office_demo_data.dart';
import 'demo/employee_demo_data.dart';

/// Serves the employee-panel demo rows while the app runs in the offline
/// preview (no session): home status, work reports, inbox/sent
/// communications and HR notifications. Everything else — and every
/// authenticated session — delegates to the real repository untouched.
class PreviewHrRepository implements HrRepository {
  PreviewHrRepository(this._remote, {this.isPreview});

  final HrRepository _remote;

  /// True only in the offline preview.
  final bool Function()? isPreview;

  bool get _preview => isPreview?.call() ?? false;

  final List<WorkReport> _reports = demoReports();
  final List<HrCommunication> _communications = [
    ...demoCommunications(),
    ...demoCommunications(box: 'sent'),
  ];

  @override
  Future<HrDashboard> dashboard(String company) => _preview
      ? Future.value(demoHrDashboard(company: company))
      : _remote.dashboard(company);

  @override
  Future<HrEmployee> myProfile() =>
      _preview ? Future.value(demoHrDashboard().employee) : _remote.myProfile();

  @override
  Future<List<HrEmployee>> team({String query = ''}) {
    if (!_preview) return _remote.team(query: query);
    const team = [
      HrEmployee(
          id: 'DEMO-EMP-002',
          name: 'احمد رضایی',
          company: demoCompanyName,
          department: 'فروش',
          designation: 'مدیر فروش'),
      HrEmployee(
          id: 'DEMO-EMP-003',
          name: 'مریم کریمی',
          company: demoCompanyName,
          department: 'فروش',
          designation: 'کارشناس فروش'),
      HrEmployee(
          id: 'DEMO-EMP-004',
          name: 'مدیر مالی',
          company: demoCompanyName,
          department: 'مالی و حسابداری',
          designation: 'مدیر مالی'),
    ];
    return Future.value(team
        .where((item) => query.isEmpty || item.name.contains(query))
        .toList());
  }

  @override
  Future<List<Map<String, dynamic>>> organization(String company) =>
      _remote.organization(company);

  @override
  Future<List<WorkReport>> reports() =>
      _preview ? Future.value([..._reports]) : _remote.reports();

  @override
  Future<WorkReport> saveReport(WorkReport report) async {
    if (!_preview) return _remote.saveReport(report);
    final saved = WorkReport(
      id: report.id.isEmpty
          ? 'LOCAL-DEMO-${DateTime.now().microsecondsSinceEpoch}'
          : report.id,
      date: report.date,
      status: report.status,
      activities: report.activities,
      totalMinutes: report.activities
          .fold(0, (sum, activity) => sum + activity.durationMinutes),
      managerComment: report.managerComment,
    );
    final index = _reports.indexWhere((item) => item.id == saved.id);
    if (index >= 0) {
      _reports[index] = saved;
    } else {
      _reports.insert(0, saved);
    }
    return saved;
  }

  @override
  Future<List<HrCommunication>> communications({String box = 'inbox'}) {
    if (!_preview) return _remote.communications(box: box);
    return Future.value(box == 'sent'
        ? _communications
            .where((item) =>
                item.status == 'Sent' || item.sender == demoEmployeeName)
            .toList()
        : _communications
            .where((item) => item.sender != demoEmployeeName)
            .toList());
  }

  @override
  Future<HrCommunication> sendCommunication(HrCommunication value) async {
    if (!_preview) return _remote.sendCommunication(value);
    final sent = HrCommunication(
      id: 'LOCAL-DEMO-${DateTime.now().microsecondsSinceEpoch}',
      subject: value.subject,
      content: value.content,
      sender: demoEmployeeName,
      type: value.type,
      priority: value.priority,
      status: 'Sent',
      confidential: value.confidential,
      recipients: value.recipients,
    );
    _communications.insert(0, sent);
    return sent;
  }

  @override
  Future<List<Map<String, dynamic>>> notifications() =>
      _preview ? Future.value(demoHrNotifications()) : _remote.notifications();
}
