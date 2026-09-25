import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:flutter_test/flutter_test.dart';

const fileJson = <String, dynamic>{
  'profile_id': 'PARTY-0042',
  'can_edit': true,
  'revision': '2026-09-25 10:41:00',
  'header': {
    'name': 'امیر موفق',
    'employee_code': 'HR-EMP-00042',
    'designation': 'کارشناس فروش',
    'department': 'Sales - T',
    'department_name': 'فروش',
    'company': 'Tabaan',
    'status': 'Active',
    'photo_record': 'native:File:PHOTO-42',
    'employment_type': 'Full-time',
    'date_of_joining': '2020-01-01',
    'service_length': {'years': 6, 'months': 8, 'days': 2459},
    'linked': true,
  },
  'personal': {
    'national_id': '0012345678',
    'father_name': 'علی',
    'birth_date': '1990-01-01',
    'employee_gender': 'Male',
    'marital_status': 'Married',
    'blood_group': 'O+',
    'mobile': '09121234567',
    'phone': '',
    'email': 'amir@example.com',
    'company_email': 'amir@tabaan.example',
    'address_line': 'خیابان آزادی',
    'province': 'تهران',
    'city': 'تهران',
    'postal_code': '1234567890',
    'permanent_address': 'خیابان بهار',
    'emergency': {'name': 'زهرا', 'phone': '09129876543', 'relation': 'همسر'},
    'education': [
      {
        'qualification': 'کارشناسی',
        'school': 'دانشگاه تهران',
        'level': 'Graduate',
        'year_of_passing': 2012,
        'major': 'مدیریت'
      }
    ],
    'previous_work': [
      {'company': 'شرکت پیشین', 'designation': 'فروشنده', 'experience': '3 سال'}
    ],
  },
  'organization': {
    'company': 'Tabaan',
    'department': 'Sales - T',
    'department_name': 'فروش',
    'department_path': ['بازرگانی', 'فروش'],
    'designation': 'کارشناس فروش',
    'branch': 'تهران',
    'employee_number': '0042',
    'direct_reports': 0,
    'reports_to': {
      'employee': 'HR-EMP-00007',
      'name': 'محمد حسینی',
      'designation': 'مدیر فروش',
      'department_name': 'فروش'
    },
  },
  'employment': {
    'employment_type': 'Full-time',
    'date_of_joining': '2020-01-01',
    'status': 'Active',
    'service_length': {'years': 6, 'months': 8, 'days': 2459},
    'scheduled_confirmation_date': '',
    'final_confirmation_date': '2020-04-01',
    'contract_end_date': '2026-12-31',
    'notice_number_of_days': 30,
    'relieving_date': '',
    'holiday_list': 'تعطیلات ۱۴۰۵',
    'default_shift': 'صبح',
  },
  'contracts': [
    {
      'name': 'HR-CONT-0015',
      'start_date': '2026-01-01',
      'end_date': '2026-12-31',
      'status': 'Active',
      'is_signed': 1,
      'signed_on': '2026-01-01',
      'docstatus': 1,
      'state': 'active',
      'days_remaining': 97,
      'terms': 'شرایط قرارداد',
      'file': {'id': 'FILE-15', 'filename': 'contract.pdf'},
    }
  ],
  'salary': {
    'visible': true,
    'currency': 'IRR',
    'current': {
      'name': 'SAL-42',
      'salary_structure': 'حقوق فروش',
      'from_date': '2026-03-21',
      'base': 30000000,
      'variable': 0,
      'currency': 'IRR'
    },
    'history': [
      {
        'name': 'SAL-41',
        'salary_structure': 'حقوق فروش',
        'from_date': '2025-03-21',
        'base': 25000000,
        'variable': 1000000,
        'currency': 'IRR'
      }
    ],
    'latest_slip': {
      'name': 'SLIP-42',
      'start_date': '2026-08-23',
      'end_date': '2026-09-22',
      'gross_pay': 30000000,
      'total_deduction': 2100000,
      'net_pay': 27900000,
      'earnings': [
        {'component': 'حقوق پایه', 'amount': 30000000}
      ],
      'deductions': [
        {'component': 'بیمه', 'amount': 2100000}
      ]
    },
    'legacy': null,
  },
  'documents': [
    {
      'id': 'FILE-42',
      'title': 'کارت ملی',
      'category': 'Identity',
      'document_number': '0012345678',
      'issue_date': '2015-05-01',
      'expiry_date': '2030-05-01',
      'status': 'valid',
      'filename': 'id.pdf'
    }
  ],
  'history': [
    {
      'kind': 'promotion',
      'title': 'ارتقا یا تغییر سمت',
      'date': '2026-09-25',
      'details': 'Designation: کارشناس فروش ← سرپرست فروش',
      'reference': 'HR-EMP-PRO-0001'
    }
  ],
  'attendance': {
    'from_date': '2026-09-01',
    'to_date': '2026-09-25',
    'present': 18,
    'absent': 0,
    'on_leave': 1,
    'half_day': 0,
    'late_entries': 2,
    'early_exits': 0,
    'by_status': {'Present': 18, 'On Leave': 1},
    'last_checkin': {'time': '2026-09-25 08:02:00', 'log_type': 'IN'}
  },
  'leave': [
    {
      'leave_type': 'Casual Leave',
      'total_leaves': 12,
      'leaves_taken': 3,
      'leaves_pending_approval': 1,
      'remaining_leaves': 8,
      'expired_leaves': 0
    }
  ],
  'activity': [
    {
      'date': '2026-09-25 10:41:00',
      'title': 'ویرایش اطلاعات پرسنلی',
      'details': 'سمت، مدیر مستقیم',
      'by': 'مدیر منابع انسانی'
    }
  ],
};

void main() {
  test('parses every section of the personnel file contract', () {
    final file = PersonnelFile.fromJson(fileJson);
    expect([file.profileId, file.canEdit, file.revision],
        ['PARTY-0042', true, '2026-09-25 10:41:00']);
    final h = file.header;
    expect([
      h.name,
      h.employeeCode,
      h.designation,
      h.department,
      h.departmentName,
      h.company,
      h.status,
      h.photoRecord,
      h.employmentType,
      h.dateOfJoining,
      h.linked,
      h.isActive
    ], [
      'امیر موفق',
      'HR-EMP-00042',
      'کارشناس فروش',
      'Sales - T',
      'فروش',
      'Tabaan',
      'Active',
      'native:File:PHOTO-42',
      'Full-time',
      '2020-01-01',
      true,
      true
    ]);
    expect([
      h.serviceLength!.years,
      h.serviceLength!.months,
      h.serviceLength!.days
    ], [
      6,
      8,
      2459
    ]);
    final p = file.personal;
    expect([
      p.nationalId,
      p.fatherName,
      p.birthDate,
      p.gender,
      p.maritalStatus,
      p.bloodGroup,
      p.mobile,
      p.phone,
      p.email,
      p.companyEmail,
      p.address,
      p.province,
      p.city,
      p.postalCode,
      p.permanentAddress
    ], [
      '0012345678',
      'علی',
      '1990-01-01',
      'Male',
      'Married',
      'O+',
      '09121234567',
      '',
      'amir@example.com',
      'amir@tabaan.example',
      'خیابان آزادی',
      'تهران',
      'تهران',
      '1234567890',
      'خیابان بهار'
    ]);
    expect([p.emergency.name, p.emergency.phone, p.emergency.relation],
        ['زهرا', '09129876543', 'همسر']);
    final e = p.education.single;
    expect([e.qualification, e.school, e.level, e.yearOfPassing, e.major],
        ['کارشناسی', 'دانشگاه تهران', 'Graduate', 2012, 'مدیریت']);
    final w = p.previousWork.single;
    expect([w.company, w.designation, w.experience],
        ['شرکت پیشین', 'فروشنده', '3 سال']);
    final o = file.organization;
    expect([
      o.company,
      o.department,
      o.departmentName,
      o.designation,
      o.branch,
      o.employeeNumber,
      o.directReports
    ], [
      'Tabaan',
      'Sales - T',
      'فروش',
      'کارشناس فروش',
      'تهران',
      '0042',
      0
    ]);
    expect(o.departmentPath, ['بازرگانی', 'فروش']);
    final manager = o.reportsTo!;
    expect([
      manager.employee,
      manager.name,
      manager.designation,
      manager.departmentName
    ], [
      'HR-EMP-00007',
      'محمد حسینی',
      'مدیر فروش',
      'فروش'
    ]);
    final job = file.employment;
    expect([
      job.employmentType,
      job.dateOfJoining,
      job.status,
      job.scheduledConfirmationDate,
      job.finalConfirmationDate,
      job.contractEndDate,
      job.noticeDays,
      job.relievingDate,
      job.holidayList,
      job.defaultShift
    ], [
      'Full-time',
      '2020-01-01',
      'Active',
      '',
      '2020-04-01',
      '2026-12-31',
      30,
      '',
      'تعطیلات ۱۴۰۵',
      'صبح'
    ]);
    expect([
      job.serviceLength!.years,
      job.serviceLength!.months,
      job.serviceLength!.days
    ], [
      6,
      8,
      2459
    ]);
    final contract = file.contracts.single;
    expect([
      contract.name,
      contract.startDate,
      contract.endDate,
      contract.status,
      contract.isSigned,
      contract.signedOn,
      contract.docstatus,
      contract.state,
      contract.daysRemaining,
      contract.terms,
      contract.file!.id,
      contract.file!.filename
    ], [
      'HR-CONT-0015',
      '2026-01-01',
      '2026-12-31',
      'Active',
      true,
      '2026-01-01',
      1,
      'active',
      97,
      'شرایط قرارداد',
      'FILE-15',
      'contract.pdf'
    ]);
    final salary = file.salary;
    expect(
        [salary.visible, salary.currency, salary.legacy], [true, 'IRR', null]);
    final current = salary.current!;
    expect([
      current.name,
      current.salaryStructure,
      current.fromDate,
      current.base,
      current.variable,
      current.currency
    ], [
      'SAL-42',
      'حقوق فروش',
      '2026-03-21',
      30000000.0,
      0.0,
      'IRR'
    ]);
    final past = salary.history.single;
    expect([
      past.name,
      past.salaryStructure,
      past.fromDate,
      past.base,
      past.variable,
      past.currency
    ], [
      'SAL-41',
      'حقوق فروش',
      '2025-03-21',
      25000000.0,
      1000000.0,
      'IRR'
    ]);
    final slip = salary.latestSlip!;
    expect([
      slip.name,
      slip.startDate,
      slip.endDate,
      slip.grossPay,
      slip.totalDeduction,
      slip.netPay
    ], [
      'SLIP-42',
      '2026-08-23',
      '2026-09-22',
      30000000.0,
      2100000.0,
      27900000.0
    ]);
    expect([
      slip.earnings.single.component,
      slip.earnings.single.amount,
      slip.deductions.single.component,
      slip.deductions.single.amount
    ], [
      'حقوق پایه',
      30000000.0,
      'بیمه',
      2100000.0
    ]);
    final doc = file.documents.single;
    expect([
      doc.id,
      doc.title,
      doc.category,
      doc.documentNumber,
      doc.issueDate,
      doc.expiryDate,
      doc.status,
      doc.filename
    ], [
      'FILE-42',
      'کارت ملی',
      'Identity',
      '0012345678',
      '2015-05-01',
      '2030-05-01',
      'valid',
      'id.pdf'
    ]);
    final event = file.history.single;
    expect([
      event.kind,
      event.title,
      event.date,
      event.details,
      event.reference
    ], [
      'promotion',
      'ارتقا یا تغییر سمت',
      '2026-09-25',
      'Designation: کارشناس فروش ← سرپرست فروش',
      'HR-EMP-PRO-0001'
    ]);
    final a = file.attendance!;
    expect([
      a.fromDate,
      a.toDate,
      a.present,
      a.absent,
      a.onLeave,
      a.halfDay,
      a.lateEntries,
      a.earlyExits,
      a.lastCheckin!.time,
      a.lastCheckin!.logType
    ], [
      '2026-09-01',
      '2026-09-25',
      18,
      0,
      1,
      0,
      2,
      0,
      '2026-09-25 08:02:00',
      'IN'
    ]);
    final leave = file.leave.single;
    expect([
      leave.leaveType,
      leave.totalLeaves,
      leave.leavesTaken,
      leave.leavesPendingApproval,
      leave.remainingLeaves,
      leave.expiredLeaves
    ], [
      'Casual Leave',
      12.0,
      3.0,
      1.0,
      8.0,
      0.0
    ]);
    final activity = file.activity.single;
    expect([
      activity.date,
      activity.title,
      activity.details,
      activity.by
    ], [
      '2026-09-25 10:41:00',
      'ویرایش اطلاعات پرسنلی',
      'سمت، مدیر مستقیم',
      'مدیر منابع انسانی'
    ]);
  });

  test('missing and null values have safe defaults', () {
    for (final json in [
      <String, dynamic>{},
      {for (final key in fileJson.keys) key: null}
    ]) {
      final file = PersonnelFile.fromJson(json);
      expect(file.profileId, '');
      expect(file.canEdit, isFalse);
      expect(file.header.employeeCode, isNull);
      expect(file.header.photoRecord, isNull);
      expect(file.header.isActive, isFalse);
      expect(file.header.serviceLength, isNull);
      expect(file.personal.emergency.name, '');
      expect(file.personal.education, isEmpty);
      expect(file.personal.previousWork, isEmpty);
      expect(file.organization.departmentPath, isEmpty);
      expect(file.organization.reportsTo, isNull);
      expect(file.organization.directReports, 0);
      expect(file.employment.noticeDays, 0);
      expect(file.employment.serviceLength, isNull);
      expect(file.contracts, isEmpty);
      expect(file.salary.current, isNull);
      expect(file.salary.latestSlip, isNull);
      expect(file.salary.history, isEmpty);
      expect(file.salary.visible, isFalse);
      expect(file.documents, isEmpty);
      expect(file.history, isEmpty);
      expect(file.attendance, isNull);
      expect(file.leave, isEmpty);
      expect(file.activity, isEmpty);
    }
    expect(
        EducationRow.fromJson({'year_of_passing': null}).yearOfPassing, isNull);
    final contract = ContractSummary.fromJson({});
    expect(contract.daysRemaining, isNull);
    expect(contract.file, isNull);
    expect(contract.isSigned, isFalse);
    expect(SalaryAssignment.fromJson({}).base, 0.0);
    expect(SalarySlipSummary.fromJson({}).earnings, isEmpty);
    expect(SalarySlipSummary.fromJson({}).deductions, isEmpty);
    expect(SalaryLine.fromJson({}).amount, 0.0);
    expect(HistoryEvent.fromJson({}).reference, isNull);
    expect(AttendanceSummary.fromJson({}).lastCheckin, isNull);
    expect(LeaveBalance.fromJson({}).remainingLeaves, 0.0);
    expect(Announcement.fromJson({}).expiresOn, '');
    expect(PersonnelHeader.fromJson({'status': 'Inactive'}).isActive, isFalse);
  });

  test(
      'Persian labels cover contract states and document categories and statuses',
      () {
    const states = {
      'draft': 'پیش‌نویس',
      'unsigned': 'امضا نشده',
      'upcoming': 'آینده',
      'active': 'فعال',
      'expired': 'منقضی',
      'unknown': 'unknown'
    };
    for (final entry in states.entries) {
      expect(ContractSummary.fromJson({'state': entry.key}).stateLabel,
          entry.value);
    }
    const categories = {
      'Identity': 'هویتی',
      'Education': 'تحصیلی',
      'Employment': 'استخدامی',
      'Medical': 'پزشکی',
      'Financial': 'مالی',
      'Other': 'سایر',
      '': 'سایر'
    };
    expect(personnelDocumentCategories, [
      'Identity',
      'Education',
      'Employment',
      'Medical',
      'Financial',
      'Other'
    ]);
    for (final entry in categories.entries) {
      expect(documentCategoryLabel(entry.key), entry.value);
      expect(PersonnelDocument.fromJson({'category': entry.key}).categoryLabel,
          entry.value);
    }
    const statuses = {
      'valid': 'معتبر',
      'expiring': 'رو به انقضا',
      'expired': 'منقضی',
      'no_expiry': 'بدون تاریخ انقضا'
    };
    for (final entry in statuses.entries) {
      expect(PersonnelDocument.fromJson({'status': entry.key}).statusLabel,
          entry.value);
    }
    expect(ServiceLength.fromJson({'years': 6, 'months': 8}).label,
        '۶ سال و ۸ ماه');
    expect(ServiceLength.fromJson({'years': 0, 'months': 8}).label, '۸ ماه');
    expect(ServiceLength.fromJson({'years': 0, 'months': 0}).label,
        'کمتر از یک ماه');
    expect(ServiceLength.fromJson({'years': 6}).label, '۶ سال');
  });

  test('employee home parses counts, announcements and first name', () {
    final home = EmployeeHome.fromJson({
      'profile_id': 'PARTY-0042',
      'employee': 'HR-EMP-00042',
      'name': 'امیر موفق',
      'designation': 'کارشناس فروش',
      'department_name': 'فروش',
      'company': 'Tabaan',
      'photo_record': 'native:File:PHOTO-42',
      'date': '2026-09-25',
      'counts': {
        'open_requests': 2,
        'open_tasks': 1,
        'unread_notifications': 3,
        'pending_leave_applications': 0,
        'leave_remaining': 8.5
      },
      'last_checkin': {'time': '2026-09-25 08:02:00', 'log_type': 'IN'},
      'announcements': [
        {
          'name': 'NOTE-1',
          'title': 'جلسه عمومی',
          'summary': 'جلسه فردا',
          'date': '2026-09-25',
          'expires_on': '2026-09-26'
        }
      ],
    });
    expect([
      home.profileId,
      home.employee,
      home.name,
      home.designation,
      home.departmentName,
      home.company,
      home.photoRecord,
      home.date,
      home.firstName
    ], [
      'PARTY-0042',
      'HR-EMP-00042',
      'امیر موفق',
      'کارشناس فروش',
      'فروش',
      'Tabaan',
      'native:File:PHOTO-42',
      '2026-09-25',
      'امیر'
    ]);
    expect([
      home.counts.openRequests,
      home.counts.openTasks,
      home.counts.unreadNotifications,
      home.counts.pendingLeaveApplications,
      home.counts.leaveRemaining
    ], [
      2,
      1,
      3,
      0,
      8.5
    ]);
    expect([home.lastCheckin!.time, home.lastCheckin!.logType],
        ['2026-09-25 08:02:00', 'IN']);
    final note = home.announcements.single;
    expect([note.name, note.title, note.summary, note.date, note.expiresOn],
        ['NOTE-1', 'جلسه عمومی', 'جلسه فردا', '2026-09-25', '2026-09-26']);
    final empty = EmployeeHome.fromJson({});
    expect(empty.profileId, isNull);
    expect(empty.photoRecord, isNull);
    expect(empty.firstName, '');
    expect(empty.lastCheckin, isNull);
    expect(empty.counts.leaveRemaining, 0.0);
    expect(empty.announcements, isEmpty);
    expect(EmployeeHome.fromJson({'name': '  امیر   موفق '}).firstName, 'امیر');
  });

  test('parsed collections and legacy salary values are immutable', () {
    final file = PersonnelFile.fromJson(fileJson);
    expect(() => file.contracts.clear(), throwsUnsupportedError);
    expect(() => file.personal.education.clear(), throwsUnsupportedError);
    expect(
        () => file.organization.departmentPath.clear(), throwsUnsupportedError);
    expect(() => file.salary.history.clear(), throwsUnsupportedError);
    final salary = SalarySummary.fromJson({
      'legacy': {'base': '30000000'}
    });
    expect(salary.legacy, {'base': '30000000'});
    expect(() => salary.legacy!['base'] = '0', throwsUnsupportedError);
  });
}
