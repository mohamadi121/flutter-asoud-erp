import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_failure.dart';
import '../../../core/utils/jalali_date.dart';

Map<String, dynamic> _object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
String _string(Object? value) => value?.toString() ?? '';
int _int(Object? value) => value is num ? value.toInt() : 0;
double _double(Object? value) => value is num ? value.toDouble() : 0;
bool _bool(Object? value) => value == true || value == 1;
T? _optional<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value == null ? null : parse(_object(value));
List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value is List
        ? List<T>.unmodifiable(value.map((row) => parse(_object(row))))
        : const [];

class PersonnelFile {
  PersonnelFile._(Map<String, dynamic> json)
      : profileId = _string(json['profile_id']),
        canEdit = _bool(json['can_edit']),
        revision = _string(json['revision']),
        header = PersonnelHeader.fromJson(_object(json['header'])),
        personal = PersonalInfo.fromJson(_object(json['personal'])),
        organization = OrganizationInfo.fromJson(_object(json['organization'])),
        employment = EmploymentInfo.fromJson(_object(json['employment'])),
        contracts = _list(json['contracts'], ContractSummary.fromJson),
        salary = SalarySummary.fromJson(_object(json['salary'])),
        documents = _list(json['documents'], PersonnelDocument.fromJson),
        history = _list(json['history'], HistoryEvent.fromJson),
        attendance = _optional(json['attendance'], AttendanceSummary.fromJson),
        leave = _list(json['leave'], LeaveBalance.fromJson),
        activity = _list(json['activity'], ActivityItem.fromJson);

  factory PersonnelFile.fromJson(Map<String, dynamic> json) =>
      PersonnelFile._(json);

  final String profileId, revision;
  final bool canEdit;
  final PersonnelHeader header;
  final PersonalInfo personal;
  final OrganizationInfo organization;
  final EmploymentInfo employment;
  final List<ContractSummary> contracts;
  final SalarySummary salary;
  final List<PersonnelDocument> documents;
  final List<HistoryEvent> history;
  final AttendanceSummary? attendance;
  final List<LeaveBalance> leave;
  final List<ActivityItem> activity;
}

class PersonnelHeader {
  PersonnelHeader._(Map<String, dynamic> json)
      : name = _string(json['name']),
        employeeCode = json['employee_code']?.toString(),
        designation = _string(json['designation']),
        department = _string(json['department']),
        departmentName = _string(json['department_name']),
        company = _string(json['company']),
        status = _string(json['status']),
        photoRecord = json['photo_record']?.toString(),
        employmentType = _string(json['employment_type']),
        dateOfJoining = _string(json['date_of_joining']),
        serviceLength =
            _optional(json['service_length'], ServiceLength.fromJson),
        linked = _bool(json['linked']);

  factory PersonnelHeader.fromJson(Map<String, dynamic> json) =>
      PersonnelHeader._(json);

  final String name,
      designation,
      department,
      departmentName,
      company,
      status,
      employmentType,
      dateOfJoining;
  final String? employeeCode, photoRecord;
  final ServiceLength? serviceLength;
  final bool linked;

  bool get isActive => status == 'Active';
}

class ServiceLength {
  const ServiceLength({this.years = 0, this.months = 0, this.days = 0});

  factory ServiceLength.fromJson(Map<String, dynamic> json) => ServiceLength(
      years: _int(json['years']),
      months: _int(json['months']),
      days: _int(json['days']));

  final int years, months, days;

  String get label {
    final parts = [
      if (years > 0) '${toPersianDigits(years)} سال',
      if (months > 0) '${toPersianDigits(months)} ماه',
    ];
    return parts.isEmpty ? 'کمتر از یک ماه' : parts.join(' و ');
  }
}

class PersonalInfo {
  PersonalInfo._(Map<String, dynamic> json)
      : nationalId = _string(json['national_id']),
        fatherName = _string(json['father_name']),
        birthDate = _string(json['birth_date']),
        gender = _string(json['employee_gender']),
        maritalStatus = _string(json['marital_status']),
        bloodGroup = _string(json['blood_group']),
        mobile = _string(json['mobile']),
        phone = _string(json['phone']),
        email = _string(json['email']),
        companyEmail = _string(json['company_email']),
        address = _string(json['address_line']),
        province = _string(json['province']),
        city = _string(json['city']),
        postalCode = _string(json['postal_code']),
        permanentAddress = _string(json['permanent_address']),
        emergency = EmergencyContact.fromJson(_object(json['emergency'])),
        education = _list(json['education'], EducationRow.fromJson),
        previousWork = _list(json['previous_work'], PreviousWork.fromJson);

  factory PersonalInfo.fromJson(Map<String, dynamic> json) =>
      PersonalInfo._(json);

  final String nationalId,
      fatherName,
      birthDate,
      gender,
      maritalStatus,
      bloodGroup,
      mobile,
      phone,
      email,
      companyEmail,
      address,
      province,
      city,
      postalCode,
      permanentAddress;
  final EmergencyContact emergency;
  final List<EducationRow> education;
  final List<PreviousWork> previousWork;
}

class EmergencyContact {
  const EmergencyContact({this.name = '', this.phone = '', this.relation = ''});

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
          name: _string(json['name']),
          phone: _string(json['phone']),
          relation: _string(json['relation']));

  final String name, phone, relation;
}

class EducationRow {
  const EducationRow(
      {this.qualification = '',
      this.school = '',
      this.level = '',
      this.yearOfPassing,
      this.major = ''});

  factory EducationRow.fromJson(Map<String, dynamic> json) => EducationRow(
      qualification: _string(json['qualification']),
      school: _string(json['school']),
      level: _string(json['level']),
      yearOfPassing: json['year_of_passing'] == null
          ? null
          : _int(json['year_of_passing']),
      major: _string(json['major']));

  final String qualification, school, level, major;
  final int? yearOfPassing;
}

class PreviousWork {
  const PreviousWork(
      {this.company = '', this.designation = '', this.experience = ''});

  factory PreviousWork.fromJson(Map<String, dynamic> json) => PreviousWork(
      company: _string(json['company']),
      designation: _string(json['designation']),
      experience: _string(json['experience']));

  final String company, designation, experience;
}

class OrganizationInfo {
  OrganizationInfo._(Map<String, dynamic> json)
      : company = _string(json['company']),
        department = _string(json['department']),
        departmentName = _string(json['department_name']),
        departmentPath = json['department_path'] is List
            ? List<String>.unmodifiable(
                (json['department_path'] as List).map(_string))
            : const [],
        designation = _string(json['designation']),
        branch = _string(json['branch']),
        employeeNumber = _string(json['employee_number']),
        directReports = _int(json['direct_reports']),
        reportsTo = _optional(json['reports_to'], ManagerSummary.fromJson);

  factory OrganizationInfo.fromJson(Map<String, dynamic> json) =>
      OrganizationInfo._(json);

  final String company,
      department,
      departmentName,
      designation,
      branch,
      employeeNumber;
  final List<String> departmentPath;
  final int directReports;
  final ManagerSummary? reportsTo;
}

class ManagerSummary {
  const ManagerSummary(
      {this.employee = '',
      this.name = '',
      this.designation = '',
      this.departmentName = ''});

  factory ManagerSummary.fromJson(Map<String, dynamic> json) => ManagerSummary(
      employee: _string(json['employee']),
      name: _string(json['name']),
      designation: _string(json['designation']),
      departmentName: _string(json['department_name']));

  final String employee, name, designation, departmentName;
}

class EmploymentInfo {
  EmploymentInfo._(Map<String, dynamic> json)
      : employmentType = _string(json['employment_type']),
        dateOfJoining = _string(json['date_of_joining']),
        status = _string(json['status']),
        serviceLength =
            _optional(json['service_length'], ServiceLength.fromJson),
        scheduledConfirmationDate =
            _string(json['scheduled_confirmation_date']),
        finalConfirmationDate = _string(json['final_confirmation_date']),
        contractEndDate = _string(json['contract_end_date']),
        noticeDays = _int(json['notice_number_of_days']),
        relievingDate = _string(json['relieving_date']),
        holidayList = _string(json['holiday_list']),
        defaultShift = _string(json['default_shift']);

  factory EmploymentInfo.fromJson(Map<String, dynamic> json) =>
      EmploymentInfo._(json);

  final String employmentType,
      dateOfJoining,
      status,
      scheduledConfirmationDate,
      finalConfirmationDate,
      contractEndDate,
      relievingDate,
      holidayList,
      defaultShift;
  final ServiceLength? serviceLength;
  final int noticeDays;
}

class ContractSummary {
  ContractSummary._(Map<String, dynamic> json)
      : name = _string(json['name']),
        startDate = _string(json['start_date']),
        endDate = _string(json['end_date']),
        status = _string(json['status']),
        isSigned = _bool(json['is_signed']),
        signedOn = _string(json['signed_on']),
        docstatus = _int(json['docstatus']),
        state = _string(json['state']),
        daysRemaining = json['days_remaining'] == null
            ? null
            : _int(json['days_remaining']),
        terms = _string(json['terms']),
        file = _optional(json['file'], AttachmentRef.fromJson);

  factory ContractSummary.fromJson(Map<String, dynamic> json) =>
      ContractSummary._(json);

  final String name, startDate, endDate, status, signedOn, state, terms;
  final bool isSigned;
  final int docstatus;
  final int? daysRemaining;
  final AttachmentRef? file;

  String get stateLabel => switch (state) {
        'draft' => 'پیش‌نویس',
        'unsigned' => 'امضا نشده',
        'upcoming' => 'آینده',
        'active' => 'فعال',
        'expired' => 'منقضی',
        _ => state,
      };
}

class AttachmentRef {
  const AttachmentRef({this.id = '', this.filename = ''});

  factory AttachmentRef.fromJson(Map<String, dynamic> json) => AttachmentRef(
      id: _string(json['id']), filename: _string(json['filename']));

  final String id, filename;
}

class SalarySummary {
  SalarySummary._(Map<String, dynamic> json)
      : visible = _bool(json['visible']),
        currency = _string(json['currency']),
        current = _optional(json['current'], SalaryAssignment.fromJson),
        history = _list(json['history'], SalaryAssignment.fromJson),
        latestSlip = _optional(json['latest_slip'], SalarySlipSummary.fromJson),
        legacy = json['legacy'] == null
            ? null
            : Map<String, String>.unmodifiable(_object(json['legacy'])
                .map((key, value) => MapEntry(key, _string(value))));

  factory SalarySummary.fromJson(Map<String, dynamic> json) =>
      SalarySummary._(json);

  final bool visible;
  final String currency;
  final SalaryAssignment? current;
  final List<SalaryAssignment> history;
  final SalarySlipSummary? latestSlip;
  final Map<String, String>? legacy;
}

class SalaryAssignment {
  const SalaryAssignment(
      {this.name = '',
      this.salaryStructure = '',
      this.fromDate = '',
      this.base = 0,
      this.variable = 0,
      this.currency = ''});

  factory SalaryAssignment.fromJson(Map<String, dynamic> json) =>
      SalaryAssignment(
          name: _string(json['name']),
          salaryStructure: _string(json['salary_structure']),
          fromDate: _string(json['from_date']),
          base: _double(json['base']),
          variable: _double(json['variable']),
          currency: _string(json['currency']));

  final String name, salaryStructure, fromDate, currency;
  final double base, variable;
}

class SalarySlipSummary {
  SalarySlipSummary._(Map<String, dynamic> json)
      : name = _string(json['name']),
        startDate = _string(json['start_date']),
        endDate = _string(json['end_date']),
        grossPay = _double(json['gross_pay']),
        totalDeduction = _double(json['total_deduction']),
        netPay = _double(json['net_pay']),
        earnings = _list(json['earnings'], SalaryLine.fromJson),
        deductions = _list(json['deductions'], SalaryLine.fromJson);

  factory SalarySlipSummary.fromJson(Map<String, dynamic> json) =>
      SalarySlipSummary._(json);

  final String name, startDate, endDate;
  final double grossPay, totalDeduction, netPay;
  final List<SalaryLine> earnings, deductions;
}

class SalaryLine {
  const SalaryLine({this.component = '', this.amount = 0});

  factory SalaryLine.fromJson(Map<String, dynamic> json) => SalaryLine(
      component: _string(json['component']), amount: _double(json['amount']));

  final String component;
  final double amount;
}

const personnelDocumentCategories = [
  'Identity',
  'Education',
  'Employment',
  'Medical',
  'Financial',
  'Other',
];

String documentCategoryLabel(String key) => switch (key) {
      'Identity' => 'هویتی',
      'Education' => 'تحصیلی',
      'Employment' => 'استخدامی',
      'Medical' => 'پزشکی',
      'Financial' => 'مالی',
      'Other' || '' => 'سایر',
      _ => key,
    };

class PersonnelDocument {
  const PersonnelDocument(
      {this.id = '',
      this.title = '',
      this.category = '',
      this.documentNumber = '',
      this.issueDate = '',
      this.expiryDate = '',
      this.status = '',
      this.filename = ''});

  factory PersonnelDocument.fromJson(Map<String, dynamic> json) =>
      PersonnelDocument(
          id: _string(json['id']),
          title: _string(json['title']),
          category: _string(json['category']),
          documentNumber: _string(json['document_number']),
          issueDate: _string(json['issue_date']),
          expiryDate: _string(json['expiry_date']),
          status: _string(json['status']),
          filename: _string(json['filename']));

  final String id,
      title,
      category,
      documentNumber,
      issueDate,
      expiryDate,
      status,
      filename;

  String get categoryLabel => documentCategoryLabel(category);
  String get statusLabel => switch (status) {
        'valid' => 'معتبر',
        'expiring' => 'رو به انقضا',
        'expired' => 'منقضی',
        'no_expiry' => 'بدون تاریخ انقضا',
        _ => status,
      };
}

class HistoryEvent {
  const HistoryEvent(
      {this.kind = '',
      this.title = '',
      this.date = '',
      this.details = '',
      this.reference});

  factory HistoryEvent.fromJson(Map<String, dynamic> json) => HistoryEvent(
      kind: _string(json['kind']),
      title: _string(json['title']),
      date: _string(json['date']),
      details: _string(json['details']),
      reference: json['reference']?.toString());

  final String kind, title, date, details;
  final String? reference;
}

class AttendanceSummary {
  AttendanceSummary._(Map<String, dynamic> json)
      : fromDate = _string(json['from_date']),
        toDate = _string(json['to_date']),
        present = _int(json['present']),
        absent = _int(json['absent']),
        onLeave = _int(json['on_leave']),
        halfDay = _int(json['half_day']),
        lateEntries = _int(json['late_entries']),
        earlyExits = _int(json['early_exits']),
        lastCheckin = _optional(json['last_checkin'], CheckinSummary.fromJson);

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) =>
      AttendanceSummary._(json);

  final String fromDate, toDate;
  final int present, absent, onLeave, halfDay, lateEntries, earlyExits;
  final CheckinSummary? lastCheckin;
}

class CheckinSummary {
  const CheckinSummary({this.time = '', this.logType = ''});

  factory CheckinSummary.fromJson(Map<String, dynamic> json) => CheckinSummary(
      time: _string(json['time']), logType: _string(json['log_type']));

  final String time, logType;
}

class LeaveBalance {
  const LeaveBalance(
      {this.leaveType = '',
      this.totalLeaves = 0,
      this.leavesTaken = 0,
      this.leavesPendingApproval = 0,
      this.remainingLeaves = 0,
      this.expiredLeaves = 0});

  factory LeaveBalance.fromJson(Map<String, dynamic> json) => LeaveBalance(
      leaveType: _string(json['leave_type']),
      totalLeaves: _double(json['total_leaves']),
      leavesTaken: _double(json['leaves_taken']),
      leavesPendingApproval: _double(json['leaves_pending_approval']),
      remainingLeaves: _double(json['remaining_leaves']),
      expiredLeaves: _double(json['expired_leaves']));

  final String leaveType;
  final double totalLeaves,
      leavesTaken,
      leavesPendingApproval,
      remainingLeaves,
      expiredLeaves;
}

class ActivityItem {
  const ActivityItem(
      {this.date = '', this.title = '', this.details = '', this.by = ''});

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
      date: _string(json['date']),
      title: _string(json['title']),
      details: _string(json['details']),
      by: _string(json['by']));

  final String date, title, details, by;
}

class EmployeeHome {
  EmployeeHome._(Map<String, dynamic> json)
      : profileId = json['profile_id']?.toString(),
        employee = _string(json['employee']),
        name = _string(json['name']),
        designation = _string(json['designation']),
        departmentName = _string(json['department_name']),
        company = _string(json['company']),
        photoRecord = json['photo_record']?.toString(),
        date = _string(json['date']),
        counts = HomeCounts.fromJson(_object(json['counts'])),
        lastCheckin = _optional(json['last_checkin'], CheckinSummary.fromJson),
        announcements = _list(json['announcements'], Announcement.fromJson);

  factory EmployeeHome.fromJson(Map<String, dynamic> json) =>
      EmployeeHome._(json);

  final String? profileId, photoRecord;
  final String employee, name, designation, departmentName, company, date;
  final HomeCounts counts;
  final CheckinSummary? lastCheckin;
  final List<Announcement> announcements;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

class HomeCounts {
  const HomeCounts(
      {this.openRequests = 0,
      this.openTasks = 0,
      this.unreadNotifications = 0,
      this.pendingLeaveApplications = 0,
      this.leaveRemaining = 0});

  factory HomeCounts.fromJson(Map<String, dynamic> json) => HomeCounts(
      openRequests: _int(json['open_requests']),
      openTasks: _int(json['open_tasks']),
      unreadNotifications: _int(json['unread_notifications']),
      pendingLeaveApplications: _int(json['pending_leave_applications']),
      leaveRemaining: _double(json['leave_remaining']));

  final int openRequests,
      openTasks,
      unreadNotifications,
      pendingLeaveApplications;
  final double leaveRemaining;
}

class Announcement {
  const Announcement(
      {this.name = '',
      this.title = '',
      this.summary = '',
      this.date = '',
      this.expiresOn = ''});

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
      name: _string(json['name']),
      title: _string(json['title']),
      summary: _string(json['summary']),
      date: _string(json['date']),
      expiresOn: _string(json['expires_on']));

  final String name, title, summary, date, expiresOn;
}

/// Offline, unreachable or missing-endpoint failures, where the older
/// personnel detail (cache, local profiles, demo) can stand in for the file.
bool canUseLegacyPersonnelFile(Object error) =>
    error is TimeoutException ||
    isRetryableOfflineFailure(error) ||
    (error is ApiException && error.statusCode == 404);

bool isLocalPersonnelId(String id) =>
    id.startsWith('LOCAL-') || id.startsWith('personnel-import-');

const _legacyBenefits = [
  'base_salary',
  'housing_allowance',
  'transport_allowance',
  'other_allowances',
  'deductions',
  'net_salary',
];

DateTime _addMonths(DateTime date, int months) {
  final month = date.month - 1 + months;
  final year = date.year + month ~/ 12;
  final lastDay = DateTime(year, month % 12 + 2, 0).day;
  return DateTime(year, month % 12 + 1, date.day.clamp(1, lastDay));
}

Map<String, int>? _legacyServiceLength(String joining, DateTime today) {
  final start = DateTime.tryParse(joining);
  if (start == null) return null;
  final end = DateTime(today.year, today.month, today.day);
  if (start.isAfter(end)) return null;
  var months = (end.year - start.year) * 12 + end.month - start.month;
  if (_addMonths(start, months).isAfter(end)) months--;
  final days = end.difference(_addMonths(start, months)).inDays;
  return {'years': months ~/ 12, 'months': months % 12, 'days': days};
}

/// Builds a personnel file from the older `get_personnel` detail payload.
PersonnelFile personnelFileFromLegacy(Map<String, dynamic> detail,
    {DateTime? today}) {
  final profile = _object(detail['profile']);
  String value(String key) => _string(profile[key]);
  final id = value('id');
  final code = value('employee_code');
  final status = _bool(profile['disabled']) ? 'Left' : 'Active';
  final service =
      _legacyServiceLength(value('date_of_joining'), today ?? DateTime.now());
  final records = [
    for (final row
        in detail['records'] is List ? detail['records'] as List : [])
      _object(row)
  ];
  final newest = [...records]..sort(
      (a, b) => _string(b['record_date']).compareTo(_string(a['record_date'])));
  final canEdit = _bool(detail['can_edit']);
  final legacy = {
    for (final key in _legacyBenefits)
      if (value(key).isNotEmpty) key: value(key)
  };
  return PersonnelFile.fromJson({
    'profile_id': id,
    'can_edit': canEdit,
    'revision': _string(detail['revision']),
    'header': {
      'name': value('display_name'),
      'employee_code': code.isEmpty || isLocalPersonnelId(code) ? null : code,
      'designation': value('job_title'),
      'department': value('department'),
      'department_name': value('department'),
      'status': status,
      'photo_record': profile['photo_record'],
      'employment_type': value('employment_type'),
      'date_of_joining': value('date_of_joining'),
      'service_length': service,
    },
    'personal': {
      for (final key in [
        'national_id',
        'father_name',
        'birth_date',
        'employee_gender',
        'marital_status',
        'blood_group',
        'mobile',
        'phone',
        'email',
        'company_email',
        'address_line',
        'province',
        'city',
        'postal_code',
      ])
        key: value(key),
      'emergency': {
        'name': value('emergency_contact_name'),
        'phone': value('emergency_phone'),
        'relation': value('emergency_relation'),
      },
    },
    'organization': {
      'department': value('department'),
      'department_name': value('department'),
      'designation': value('job_title'),
      'branch': value('branch'),
    },
    'employment': {
      'employment_type': value('employment_type'),
      'date_of_joining': value('date_of_joining'),
      'status': status,
      'service_length': service,
      'final_confirmation_date': value('final_confirmation_date'),
      'contract_end_date': value('contract_end_date'),
      'notice_number_of_days': int.tryParse(value('notice_number_of_days')),
    },
    'salary': {
      if (canEdit && legacy.isNotEmpty) 'legacy': legacy,
    },
    'documents': [
      for (final row in records)
        if (row['kind'] == 'document')
          {
            'id': row['name'],
            'title': row['title'],
            'issue_date': row['record_date'],
            'status': 'no_expiry',
            'category': '',
          },
    ],
    'history': [
      for (final row in records)
        if (row['kind'] == 'history')
          {
            'kind': 'internal',
            'title': row['title'],
            'date': row['record_date']
          },
    ],
    'activity': [
      for (final row in newest.take(5))
        {'title': row['title'], 'date': row['record_date']},
    ],
  });
}
