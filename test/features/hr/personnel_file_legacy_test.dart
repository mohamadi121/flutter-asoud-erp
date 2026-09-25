import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _legacy() => {
      'profile': {
        'id': 'P1',
        'display_name': 'امیر موفق',
        'employee_code': 'EMP-42',
        'employee_status': 'Inactive',
        'disabled': false,
        'photo_record': 'PHOTO1',
        'job_title': 'کارشناس فروش',
        'department': 'فروش',
        'employment_type': 'Full-time',
        'date_of_joining': '2020-01-15',
        'branch': 'تهران',
        'contract_end_date': '2027-01-01',
        'final_confirmation_date': '2020-04-15',
        'notice_number_of_days': '30',
        'national_id': '0012345678',
        'father_name': 'حسن',
        'birth_date': '1990-01-01',
        'employee_gender': 'Male',
        'mobile': '09121234567',
        'phone': '02112345678',
        'email': 'person@example.com',
        'address_line': 'خیابان آزادی',
        'province': 'تهران',
        'city': 'تهران',
        'postal_code': '1234567890',
        'marital_status': 'Married',
        'blood_group': 'O+',
        'company_email': 'work@example.com',
        'emergency_contact_name': 'زهرا',
        'emergency_phone': '09121111111',
        'emergency_relation': 'همسر',
        'base_salary': '100',
        'housing_allowance': '20',
        'transport_allowance': '10',
        'other_allowances': '5',
        'deductions': '0',
        'net_salary': '135',
      },
      'records': [
        for (final day in [2, 6, 1, 4, 3, 5])
          {
            'name': 'R$day',
            'kind': day == 2 ? 'document' : (day == 3 ? 'history' : 'evaluation'),
            'title': 'سابقه $day',
            'record_date': '2026-09-0$day',
          },
      ],
      'can_edit': true,
      'revision': 'revision-1',
    };

void main() {
  test('maps the complete legacy payload without changing it', () {
    final detail = _legacy();
    final file = personnelFileFromLegacy(detail, today: DateTime(2026, 9, 25));
    expect(detail, _legacy());
    expect(file.profileId, 'P1');
    expect(file.revision, 'revision-1');
    expect(file.canEdit, isTrue);
    final h = file.header;
    expect(h.name, 'امیر موفق');
    expect(h.employeeCode, 'EMP-42');
    expect(h.designation, 'کارشناس فروش');
    expect(h.departmentName, 'فروش');
    expect(h.status, 'Active');
    expect(h.photoRecord, 'PHOTO1');
    expect(h.employmentType, 'Full-time');
    expect(h.dateOfJoining, '2020-01-15');
    expect(h.serviceLength!.years, 6);
    expect(h.serviceLength!.months, 8);
    expect(h.serviceLength!.days, 10);
    final p = file.personal;
    expect(p.nationalId, '0012345678');
    expect(p.fatherName, 'حسن');
    expect(p.birthDate, '1990-01-01');
    expect(p.gender, 'Male');
    expect(p.mobile, '09121234567');
    expect(p.phone, '02112345678');
    expect(p.email, 'person@example.com');
    expect(p.address, 'خیابان آزادی');
    expect(p.province, 'تهران');
    expect(p.city, 'تهران');
    expect(p.postalCode, '1234567890');
    expect(p.maritalStatus, 'Married');
    expect(p.bloodGroup, 'O+');
    expect(p.companyEmail, 'work@example.com');
    expect(p.emergency.name, 'زهرا');
    expect(p.emergency.phone, '09121111111');
    expect(p.emergency.relation, 'همسر');
    expect(file.organization.department, 'فروش');
    expect(file.organization.departmentName, 'فروش');
    expect(file.organization.designation, 'کارشناس فروش');
    expect(file.organization.branch, 'تهران');
    final e = file.employment;
    expect(e.employmentType, h.employmentType);
    expect(e.dateOfJoining, h.dateOfJoining);
    expect(e.status, h.status);
    expect(e.serviceLength!.years, 6);
    expect(e.contractEndDate, '2027-01-01');
    expect(e.finalConfirmationDate, '2020-04-15');
    expect(e.noticeDays, 30);
    final doc = file.documents.single;
    expect(doc.id, 'R2');
    expect(doc.title, 'سابقه 2');
    expect(doc.issueDate, '2026-09-02');
    expect(doc.status, 'no_expiry');
    expect(doc.category, '');
    final history = file.history.single;
    expect(history.kind, 'internal');
    expect(history.title, 'سابقه 3');
    expect(history.date, '2026-09-03');
    expect(file.activity.map((a) => a.title),
        ['سابقه 6', 'سابقه 5', 'سابقه 4', 'سابقه 3', 'سابقه 2']);
    expect(file.activity.map((a) => a.date),
        ['2026-09-06', '2026-09-05', '2026-09-04', '2026-09-03', '2026-09-02']);
    expect(file.contracts, isEmpty);
    expect(file.salary.history, isEmpty);
    expect(file.salary.current, isNull);
    expect(file.salary.latestSlip, isNull);
    expect(file.attendance, isNull);
    expect(file.leave, isEmpty);
    expect(file.salary.legacy, {
      'base_salary': '100',
      'housing_allowance': '20',
      'transport_allowance': '10',
      'other_allowances': '5',
      'deductions': '0',
      'net_salary': '135',
    });
  });

  for (final id in ['LOCAL-person', 'personnel-import-person']) {
    test('does not show a local employee code for $id', () {
      final detail = _legacy();
      (detail['profile'] as Map)
        ..['id'] = id
        ..['employee_code'] = id;
      final file = personnelFileFromLegacy(detail);
      expect(file.profileId, id);
      expect(file.header.employeeCode, isNull);
    });
  }

  for (final disabled in [true, 1]) {
    test('disabled $disabled means Left', () {
      final detail = _legacy();
      detail['profile']['disabled'] = disabled;
      final file = personnelFileFromLegacy(detail);
      expect(file.header.status, 'Left');
      expect(file.employment.status, 'Left');
    });
  }

  test('empty payload has safe empty defaults', () {
    final file = personnelFileFromLegacy({});
    expect(file.profileId, '');
    expect(file.revision, '');
    expect(file.canEdit, isFalse);
    expect(file.header.name, '');
    expect(file.header.employeeCode, isNull);
    expect(file.header.serviceLength, isNull);
    expect(file.documents, isEmpty);
    expect(file.history, isEmpty);
    expect(file.activity, isEmpty);
    expect(file.contracts, isEmpty);
    expect(file.salary.legacy, isNull);
    expect(file.salary.history, isEmpty);
    expect(file.attendance, isNull);
    expect(file.leave, isEmpty);
  });

  test('salary legacy requires editing permission and a nonempty amount', () {
    expect(personnelFileFromLegacy({..._legacy(), 'can_edit': false}).salary.legacy,
        isNull);
    expect(personnelFileFromLegacy({
      'can_edit': true,
      'profile': {'base_salary': '', 'net_salary': null}
    }).salary.legacy, isNull);
  });

  test('service length handles month ends, missing and future dates', () {
    PersonnelFile convert(String date, DateTime today) => personnelFileFromLegacy(
        {'profile': {'date_of_joining': date}}, today: today);
    final length = convert('2024-01-31', DateTime(2024, 3, 1)).header.serviceLength!;
    expect([length.years, length.months, length.days], [0, 1, 1]);
    expect(convert('invalid', DateTime(2026)).header.serviceLength, isNull);
    expect(convert('2027-01-01', DateTime(2026)).header.serviceLength, isNull);
  });

  test('only offline failures and missing endpoints allow legacy fallback', () {
    expect(canUseLegacyPersonnelFile(TimeoutException('timeout')), isTrue);
    for (final kind in ApiFailureKind.values) {
      expect(canUseLegacyPersonnelFile(ApiException(kind: kind, message: 'error')),
          [ApiFailureKind.network, ApiFailureKind.timeout, ApiFailureKind.server]
              .contains(kind), reason: kind.name);
    }
    expect(canUseLegacyPersonnelFile(const ApiException(
        kind: ApiFailureKind.protocol, statusCode: 404, message: 'missing')), isTrue);
    expect(canUseLegacyPersonnelFile(StateError('failed')), isFalse);
  });
}
