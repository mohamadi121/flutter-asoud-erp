/// Demo rows for the employee panel in the offline preview (no session):
/// home greeting, announcements, attendance history, work reports with
/// feedback, inbox/sent communications and HR notifications.
///
/// Dates are relative to now. Served only in preview; an authenticated
/// session always reads the server.
library;

import '../../../office_setup/data/demo/office_demo_data.dart';
import '../../../hr/domain/hr_models.dart';
import '../../../hr/domain/personnel_file.dart';

const demoEmployeeName = 'سارا محمدی';
const demoEmployeeDesignation = 'کارشناس فروش';
const demoEmployeeDepartment = 'فروش';
const demoManagerName = 'احمد رضایی';

String _iso(DateTime value) => value.toIso8601String();

/// «خانه» of the employee panel: greeting, counts, today's check-in and
/// five announcements.
EmployeeHome demoEmployeeHome({DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  return EmployeeHome.fromJson({
    'profile_id': 'DEMO-PARTY-1',
    'employee': 'DEMO-EMP-001',
    'name': demoEmployeeName,
    'designation': demoEmployeeDesignation,
    'department_name': demoEmployeeDepartment,
    'company': demoCompanyName,
    'date': _iso(current).substring(0, 10),
    'counts': {
      'open_requests': 4,
      'open_tasks': 3,
      'unread_notifications': 5,
      'pending_leave_applications': 1,
      'leave_remaining': 12,
    },
    'last_checkin': {
      'time': _iso(today.add(const Duration(hours: 8, minutes: 12))),
      'log_type': 'IN',
    },
    'announcements': demoAnnouncementMaps(now: current).take(3).toList(),
  });
}

/// Five announcements; the home page shows the first three.
List<Announcement> demoAnnouncements({DateTime? now}) => [
      for (final row in demoAnnouncementMaps(now: now))
        Announcement.fromJson(row),
    ];

List<Map<String, dynamic>> demoAnnouncementMaps({DateTime? now}) {
  final current = now ?? DateTime.now();
  String day(int daysAgo) =>
      _iso(current.subtract(Duration(days: daysAgo))).substring(0, 10);
  String future(int days) =>
      _iso(current.add(Duration(days: days))).substring(0, 10);
  return [
    {
      'name': 'DEMO-ANN-1',
      'title': 'جلسه هماهنگی فروش',
      'summary': 'شنبه ساعت ۹ در سالن جلسات؛ گزارش هفتگی همراه باشد.',
      'date': day(0),
      'expires_on': future(6),
    },
    {
      'name': 'DEMO-ANN-2',
      'title': 'مرخصی شما تأیید شد',
      'summary': 'مرخصی استحقاقی تابستان به تأیید مدیر مستقیم رسید.',
      'date': day(1),
      'expires_on': future(5),
    },
    {
      'name': 'DEMO-ANN-3',
      'title': 'کارگاه آموزش سامانه',
      'summary': 'کارگاه آشنایی با گردش کار، چهارشنبه ساعت ۱۰ برگزار می‌شود.',
      'date': day(2),
      'expires_on': future(4),
    },
    {
      'name': 'DEMO-ANN-4',
      'title': 'تنخواه خرداد بسته شد',
      'summary': 'اسناد تنخواه خرداد تا پایان هفته به مالی تحویل شود.',
      'date': day(3),
      'expires_on': future(3),
    },
    {
      'name': 'DEMO-ANN-5',
      'title': 'نظرسنجی رضایت شغلی',
      'summary': 'در نظرسنجی فصلی منابع انسانی شرکت کنید.',
      'date': day(4),
      'expires_on': future(10),
    },
  ];
}

/// Today's status card of the HR dashboard.
HrDashboard demoHrDashboard({DateTime? now, String? company}) => HrDashboard(
      employee: const HrEmployee(
        id: 'DEMO-EMP-001',
        name: demoEmployeeName,
        company: demoCompanyName,
        department: demoEmployeeDepartment,
        designation: demoEmployeeDesignation,
        manager: demoManagerName,
        phone: '۰۹۱۲۳۴۵۶۷۸۹',
        email: 'sara.mohammadi@asoud-demo.ir',
      ),
      pendingTasks: 3,
      unreadNotifications: 5,
      unreadCommunications: 2,
      todayReportStatus: 'ثبت شده',
    );

/// A draft of today and a submitted report with the manager's feedback.
List<WorkReport> demoReports({DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  return [
    WorkReport(
      id: 'DEMO-REPORT-TODAY',
      date: today,
      status: 'Draft',
      activities: const [
        WorkActivity(
            title: 'پیگیری مشتریان',
            description: 'تماس با سه مشتری برای قرارداد پشتیبانی',
            durationMinutes: 120,
            progress: 60),
        WorkActivity(
            title: 'ثبت درخواست خرید',
            description: 'ثبت درخواست لپ‌تاپ در سامانه',
            durationMinutes: 30,
            progress: 100),
      ],
      totalMinutes: 150,
    ),
    WorkReport(
      id: 'DEMO-REPORT-YESTERDAY',
      date: today.subtract(const Duration(days: 1)),
      status: 'Submitted',
      activities: const [
        WorkActivity(
            title: 'بازدید از نمایشگاه',
            description: 'حضور در نمایشگاه تهران و گفت‌وگو با تأمین‌کنندگان',
            durationMinutes: 300,
            progress: 100,
            output: 'فهرست پنج تأمین‌کننده جدید'),
      ],
      totalMinutes: 300,
      managerComment:
          'گزارش کامل است؛ فهرست تأمین‌کنندگان را به بازرگانی بدهید.',
    ),
  ];
}

/// Inbox (received) and sent communications.
List<HrCommunication> demoCommunications({String box = 'inbox'}) {
  const inbox = [
    HrCommunication(
      id: 'DEMO-COMM-1',
      subject: 'جلسه هماهنگی فروش',
      content: 'شنبه ساعت ۹ در سالن جلسات حاضر باشید.',
      sender: 'احمد رضایی',
      priority: 'High',
      status: 'Received',
      recipients: ['سارا محمدی'],
    ),
    HrCommunication(
      id: 'DEMO-COMM-2',
      subject: 'تحویل اسناد تنخواه',
      content: 'اسناد تنخواه خرداد تا پایان هفته تحویل مالی شود.',
      sender: 'مدیر مالی',
      status: 'Received',
      recipients: ['سارا محمدی'],
    ),
    HrCommunication(
      id: 'DEMO-COMM-3',
      subject: 'کارگاه آموزش سامانه',
      content: 'سرفصل کارگاه چهارشنبه اعلام شد.',
      sender: 'واحد آموزش',
      status: 'Received',
      recipients: ['سارا محمدی'],
    ),
  ];
  const sent = [
    HrCommunication(
      id: 'DEMO-COMM-4',
      subject: 'درخواست مرخصی استحقاقی',
      content: 'درخواست سه روز مرخصی استحقاقی برای هفته آینده.',
      sender: 'سارا محمدی',
      status: 'Sent',
      recipients: ['احمد رضایی'],
    ),
    HrCommunication(
      id: 'DEMO-COMM-5',
      subject: 'گزارش بازدید نمایشگاه',
      content: 'فهرست تأمین‌کنندگان جدید پیوست شد.',
      sender: 'سارا محمدی',
      status: 'Sent',
      recipients: ['احمد رضایی'],
    ),
  ];
  return box == 'sent' ? sent : inbox;
}

/// Five HR notifications; two already read.
List<Map<String, dynamic>> demoHrNotifications({DateTime? now}) {
  final current = now ?? DateTime.now();
  String at(int daysAgo, int hour) {
    final day = current.subtract(Duration(days: daysAgo));
    return _iso(DateTime(day.year, day.month, day.day, hour));
  }

  return [
    {
      'subject': 'مرخصی شما تأیید شد',
      'creation': at(0, 9),
      'is_read': false,
      'is_sample': true,
    },
    {
      'subject': 'کار جدید در کارتابل شماست',
      'creation': at(1, 10),
      'is_read': false,
      'is_sample': true,
    },
    {
      'subject': 'یادآوری ثبت گزارش کار امروز',
      'creation': at(1, 17),
      'is_read': false,
      'is_sample': true,
    },
    {
      'subject': 'تنخواه تیر تأیید شد',
      'creation': at(2, 11),
      'is_read': true,
      'is_sample': true,
    },
    {
      'subject': 'اطلاعیه جدید منابع انسانی',
      'creation': at(3, 8),
      'is_read': true,
      'is_sample': true,
    },
  ];
}

/// Recent check-in/out logs, newest first, relative to now.
List<Map<String, dynamic>> demoCheckins({DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final yesterday = today.subtract(const Duration(days: 1));
  String at(DateTime day, int hour, int minute) =>
      _iso(day.add(Duration(hours: hour, minutes: minute)));
  return [
    {'time': at(today, 8, 12), 'log_type': 'IN', 'is_sample': true},
    {'time': at(yesterday, 17, 45), 'log_type': 'OUT', 'is_sample': true},
    {'time': at(yesterday, 8, 5), 'log_type': 'IN', 'is_sample': true},
  ];
}

/// This month's attendance up to today.
List<Map<String, dynamic>> demoAttendance(String fromDate, String toDate,
    {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final from = DateTime.tryParse(fromDate) ?? DateTime(today.year, today.month);
  final to = DateTime.tryParse(toDate) ?? today;
  final end = to.isAfter(today) ? today : to;
  final rows = <Map<String, dynamic>>[];
  var day = DateTime(from.year, from.month, from.day);
  while (!day.isAfter(end)) {
    final weekend = day.weekday == DateTime.friday;
    rows.add({
      'attendance_date': _iso(day).substring(0, 10),
      'status': weekend ? 'Absent' : 'Present',
      'is_sample': true,
    });
    day = day.add(const Duration(days: 1));
  }
  // One leave day inside the range so the status is always tryable.
  if (rows.length >= 4) {
    final leave = rows[rows.length - 3];
    if (leave['status'] == 'Present') {
      rows[rows.length - 3] = {...leave, 'status': 'On Leave'};
    }
  }
  return rows.reversed.toList(growable: false);
}
