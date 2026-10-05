import 'dart:convert';

import 'package:asoud_erp/features/hr/data/demo/hr_demo_data.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _clock = HrDemoData.at(DateTime(2026, 10, 5));

/// Independent Iranian national-id check, so the demo cannot "verify itself"
/// with the same helper that generated it.
bool _validNationalId(String value) {
  if (value.length != 10 || !RegExp(r'^\d{10}$').hasMatch(value)) return false;
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += int.parse(value[i]) * (10 - i);
  }
  final check = sum % 11;
  return int.parse(value[9]) == (check == 10 ? 0 : check);
}

int _serviceDays(ServiceLength length) =>
    length.years * 365 + length.months * 30 + length.days;

/// Fields the server legitimately leaves empty: a serving employee has no
/// relieving date, part-timers and contractors never sit a probation period,
/// and some documents never expire.
const _optionalKeys = {
  'relieving_date',
  'final_confirmation_date',
  'expiry_date',
  'national_code',
};

void _requireFilled(Map<String, Object?> json, String path) {
  for (final entry in json.entries) {
    final value = entry.value;
    if (value is Map<String, Object?>) {
      _requireFilled(value, '$path.${entry.key}');
    } else if (value is String && !_optionalKeys.contains(entry.key)) {
      expect(value.trim(), isNotEmpty, reason: '$path.${entry.key} is empty');
    }
  }
}

void main() {
  test('seeded files parse and fill every personal, contract and salary field',
      () {
    for (final code in hrDemoEmployeeCodes) {
      final file = PersonnelFile.fromJson(_clock.file(code));
      expect(file.profileId, code);
      expect(file.canEdit, isFalse, reason: 'sample rows stay read-only');
      expect(file.header.name.trim(), isNotEmpty);
      expect(file.header.employeeCode, code);
      expect(file.header.isActive, isTrue);
      expect(file.header.serviceLength?.label, isNotEmpty);
      expect(file.personal.nationalId, isNotEmpty);
      expect(file.personal.fatherName, isNotEmpty);
      expect(file.personal.birthDate, isNotEmpty);
      expect(file.personal.gender, isNotEmpty);
      expect(file.personal.maritalStatus, isNotEmpty);
      expect(file.personal.bloodGroup, isNotEmpty);
      expect(file.personal.mobile, isNotEmpty);
      expect(file.personal.phone, isNotEmpty);
      expect(file.personal.email, isNotEmpty);
      expect(file.personal.companyEmail, isNotEmpty);
      expect(file.personal.address, isNotEmpty);
      expect(file.personal.permanentAddress, isNotEmpty);
      expect(file.personal.province, isNotEmpty);
      expect(file.personal.city, isNotEmpty);
      expect(file.personal.postalCode, isNotEmpty);
      expect(file.personal.emergency.name, isNotEmpty);
      expect(file.personal.emergency.phone, isNotEmpty);
      expect(file.personal.emergency.relation, isNotEmpty);
      expect(file.personal.education, isNotEmpty);
      expect(file.personal.previousWork, isNotEmpty, reason: code);
      expect(file.organization.company, hrDemoCompany);
      expect(file.organization.departmentPath, isNotEmpty);
      expect(file.organization.branch, isNotEmpty);
      expect(file.organization.employeeNumber, code);
      expect(file.employment.employmentType, isNotEmpty);
      expect(file.employment.status, 'Active');
      expect(file.employment.serviceLength?.label, isNotEmpty);
      expect(file.employment.contractEndDate, isNotEmpty);
      expect(file.employment.noticeDays, greaterThan(0));
      expect(file.attendance, isNotNull);
      expect(file.attendance!.lastCheckin?.time, isNotEmpty);
      expect(file.leave, hasLength(2));
      expect(file.leave.first.leaveType, 'Privilege Leave');
      expect(file.leave.last.leaveType, 'Sick Leave');
      expect(file.contracts, isNotEmpty);
      expect(file.history, isNotEmpty);
      expect(file.activity, isNotEmpty);
      for (final activity in file.activity) {
        expect(activity.by.trim(), isNotEmpty);
        expect(activity.title.trim(), isNotEmpty);
        expect(activity.date, isNotEmpty);
      }
      _requireFilled(_clock.file(code), 'file($code)');
    }
  });

  test('every seeded national id passes the Iranian mod-11 checksum', () {
    for (final code in hrDemoEmployeeCodes) {
      final id = PersonnelFile.fromJson(_clock.file(code)).personal.nationalId;
      expect(_validNationalId(id), isTrue, reason: '$code has $id');
    }
    // The generator is not self-fulfilling: a changed digit must be caught.
    expect(_validNationalId('${_clock.rows().first['national_id']}1'), isFalse);
  });

  test('org chart has one CEO, four managers and no reporting cycle', () {
    final byCode = {
      for (final row in _clock.rows()) '${row['id']}': row,
    };
    final managers = byCode.values
        .where((row) => '${row['reports_to']}'.isNotEmpty)
        .toList();
    final ceos =
        byCode.values.where((row) => '${row['reports_to']}'.isEmpty).toList();
    final heads = byCode.values
        .where((row) =>
            '${row['job_title']}'.startsWith('مدیر ') &&
            '${row['job_title']}' != 'مدیرعامل')
        .toList();
    expect(ceos, hasLength(1));
    expect('${ceos.single['job_title']}', 'مدیرعامل');
    expect(managers, hasLength(11));
    expect(heads, hasLength(4), reason: 'one manager per department');
    expect(heads.map((row) => '${row['department']}').toSet(),
        {'فروش', 'مالی', 'فناوری اطلاعات', 'اداری و منابع انسانی'});
    expect(heads.every((row) => (row['direct_reports']! as int) > 0), isTrue,
        reason: 'every department manager actually leads someone');
    expect(
      byCode.values.map((row) => '${row['department']}').toSet(),
      {'فروش', 'مالی', 'فناوری اطلاعات', 'اداری و منابع انسانی'},
    );
    for (final row in byCode.values) {
      var current = '${row['id']}';
      var hops = 0;
      final seen = <String>{};
      while (true) {
        expect(seen.add(current), isTrue,
            reason: 'reporting cycle through $current');
        final manager = '${byCode[current]!['reports_to']}';
        if (manager.isEmpty) break;
        expect(byCode[manager], isNotNull,
            reason: '$manager is not one of the seeded profiles');
        current = manager;
        hops++;
        expect(hops, lessThanOrEqualTo(byCode.length));
      }
      expect(current, ceos.single['id']);
    }
    // Direct-report counts are real, not decoration.
    final files = {
      for (final code in hrDemoEmployeeCodes)
        code: PersonnelFile.fromJson(_clock.file(code))
    };
    expect(files['EMP-0001']!.organization.directReports, 4);
    expect(files['EMP-0002']!.organization.directReports, 2);
    expect(files['EMP-0004']!.organization.directReports, 2);
    expect(files['EMP-0001']!.organization.reportsTo, isNull);
    expect(files['EMP-0006']!.organization.reportsTo?.employee, 'EMP-0002');
    expect(files['EMP-0006']!.organization.reportsTo!.name, 'مریم کاظمی');
  });

  test('contracts follow the injected clock and cover every state', () {
    for (final code in hrDemoEmployeeCodes) {
      final contracts = PersonnelFile.fromJson(_clock.file(code)).contracts;
      final current = contracts.where((c) => c.state != 'expired');
      expect(current, isNotEmpty, reason: '$code needs a live contract');
      for (final contract in contracts) {
        final start = DateTime.parse(contract.startDate);
        final end = DateTime.parse(contract.endDate);
        expect(start.isBefore(end), isTrue);
        expect(
            contract.state,
            contract.isSigned
                ? (start.isAfter(_clock.today)
                    ? 'upcoming'
                    : (end.isBefore(_clock.today) ? 'expired' : 'active'))
                : 'unsigned');
        expect(contract.terms.trim(), isNotEmpty);
        expect(contract.file?.filename, isNotEmpty);
        if (contract.state != 'unsigned') {
          expect(contract.isSigned, isTrue);
        }
      }
    }
    final all = [
      for (final code in hrDemoEmployeeCodes)
        ...PersonnelFile.fromJson(_clock.file(code)).contracts,
    ];
    expect(
        all.where((c) => c.state == 'active').length, greaterThanOrEqualTo(4));
    expect(all.where((c) => c.state == 'upcoming').length,
        greaterThanOrEqualTo(2));
    expect(all.where((c) => c.state == 'unsigned').length, 2,
        reason: 'two renewals are still waiting for a signature');
    expect(
        all.where((c) => c.state == 'expired').length, greaterThanOrEqualTo(3));
    final soon = all
        .where((c) =>
            c.state == 'active' &&
            c.daysRemaining != null &&
            c.daysRemaining! <= 30)
        .toList();
    expect(soon, hasLength(greaterThanOrEqualTo(2)));
    for (final contract in soon) {
      expect(contract.daysRemaining, inInclusiveRange(0, 30));
    }
// Moving the clock shifts every relative window by the same amount, and
    // turns the drafted renewals into active contracts.
    final now = PersonnelFile.fromJson(_clock.file('EMP-0005'))
        .contracts
        .firstWhere((c) => c.state != 'expired');
    final tomorrow = PersonnelFile.fromJson(
            HrDemoData.at(DateTime(2026, 10, 6)).file('EMP-0005'))
        .contracts
        .firstWhere((c) => c.state != 'expired');
    expect(
        DateTime.parse(tomorrow.endDate)
            .difference(DateTime.parse(now.endDate))
            .inDays,
        1);
    expect(tomorrow.daysRemaining, now.daysRemaining);
    final ceo = PersonnelFile.fromJson(
            HrDemoData.at(DateTime(2026, 10, 6)).file('EMP-0001'))
        .contracts
        .firstWhere((c) => c.name.endsWith('-1'));
    expect(ceo.daysRemaining, 18);
    expect(ceo.state, 'active');
    // A drafted renewal starts one month after the running contract ends.
    final hr = PersonnelFile.fromJson(_clock.file('EMP-0011'));
    final renewal = hr.contracts.firstWhere((c) => c.name.endsWith('-3'));
    final running = hr.contracts.firstWhere((c) => c.name.endsWith('-1'));
    expect(renewal.state, 'upcoming');
    expect(
        DateTime.parse(renewal.startDate)
            .difference(DateTime.parse(running.endDate))
            .inDays,
        30);
    expect(renewal.daysRemaining, greaterThan(300));
  });

  test('documents carry real statuses, numbers and small real attachments', () {
    final all = <PersonnelDocument>[];
    for (final code in hrDemoEmployeeCodes) {
      final documents = PersonnelFile.fromJson(_clock.file(code)).documents;
      expect(documents, hasLength(6), reason: code);
      final statuses = documents.map((d) => d.status).toSet();
      expect(statuses,
          containsAll(<String>['valid', 'expiring', 'no_expiry', 'pending']),
          reason: '$code covers every status an employee can see');
      for (final document in documents) {
        expect(document.title.trim(), isNotEmpty);
        expect(document.documentNumber.trim(), isNotEmpty);
        expect(document.issueDate, isNotEmpty);
        expect(document.categoryLabel, isNotEmpty);
        expect(personnelDocumentCategories, contains(document.category));
        expect(document.statusLabel, isNotEmpty);
        expect(document.statusLabel, isNot(contains('—')),
            reason: '$code/${document.title}');
        final expiry = DateTime.tryParse(document.expiryDate);
        expect(
            document.status,
            document.expiryDate.isEmpty
                ? 'no_expiry'
                : anyOf('valid', 'expiring', 'expired', 'pending'));
        if (document.status != 'pending' && expiry != null) {
          expect(
              document.status,
              expiry.isBefore(_clock.today)
                  ? 'expired'
                  : (expiry.difference(_clock.today).inDays <= 30
                      ? 'expiring'
                      : 'valid'));
        }
        final record = _clock.record(document.id);
        final bytes = base64Decode('${record?['file']}');
        expect(ascii.decode(bytes.take(8).toList()), startsWith('%PDF-1.4'));
        expect(record?['filename'], document.filename);
        expect(bytes.length, lessThan(2048));
        all.add(document);
      }
    }
    final statuses = all.map((document) => document.status).toSet();
    expect(
        statuses,
        containsAll(
            <String>['valid', 'expiring', 'expired', 'no_expiry', 'pending']));
    expect(
        all.map((document) => document.category).toSet(),
        containsAll(
            <String>['Identity', 'Education', 'Employment', 'Medical']));
  });

  testWidgets('avatar bytes are a decodable PNG', (tester) async {
    for (var index = 0; index < hrDemoEmployeeCodes.length; index++) {
      final record =
          _clock.record(_clock.photoRecordId(hrDemoEmployeeCodes[index]));
      final bytes = base64Decode('${record?['file']}');
      expect(bytes.take(8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      var broken = false;
      await tester.pumpWidget(MaterialApp(
        home: Image.memory(bytes, errorBuilder: (_, __, ___) {
          broken = true;
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      expect(broken, isFalse, reason: hrDemoEmployeeCodes[index]);
    }
  });

  test('salary shows for managers only, and never in the self view', () {
    final ceo = PersonnelFile.fromJson(_clock.file('EMP-0001'));
    expect(ceo.salary.visible, isTrue);
    expect(ceo.salary.currency, 'IRR');
    expect(ceo.salary.current, isNotNull);
    expect(ceo.salary.history, hasLength(3));
    expect(ceo.salary.latestSlip, isNotNull);
    expect(ceo.salary.latestSlip!.earnings, isNotEmpty);
    expect(ceo.salary.latestSlip!.deductions, isNotEmpty);
    expect(
        ceo.salary.latestSlip!.netPay,
        ceo.salary.latestSlip!.grossPay -
            ceo.salary.latestSlip!.totalDeduction);

    for (final code in ['EMP-0006', 'EMP-0008', 'EMP-0012']) {
      final file = PersonnelFile.fromJson(_clock.file(code));
      expect(file.salary.visible, isFalse, reason: code);
      expect(file.salary.current, isNull);
      expect(file.salary.history, isEmpty);
      expect(file.salary.latestSlip, isNull);
    }

    final mine = PersonnelFile.fromJson(
        _clock.file(hrDemoSelfEmployeeCode, selfView: true));
    expect(mine.salary.visible, isFalse);
    expect(mine.salary.current, isNull);
    expect(mine.salary.history, isEmpty);
    expect(mine.salary.latestSlip, isNull);
    expect(mine.salary.currency, isNotEmpty);
    // The rest of the self file is still complete.
    expect(mine.personal.nationalId, isNotEmpty);
    expect(mine.documents, isNotEmpty);
    expect(mine.attendance, isNotNull);
  });

  test(
      'history covers joining, internal, promotion, transfer, contract, '
      'salary and relieving events', () {
    final kinds = <String>{};
    for (final code in hrDemoEmployeeCodes) {
      for (final event in PersonnelFile.fromJson(_clock.file(code)).history) {
        expect(event.title.trim(), isNotEmpty, reason: code);
        expect(event.details.trim(), isNotEmpty, reason: '$code/${event.kind}');
        expect(DateTime.tryParse(event.date), isNotNull, reason: code);
        kinds.add(event.kind);
      }
    }
    expect(
        kinds,
        containsAll(<String>[
          'joining',
          'internal',
          'promotion',
          'transfer',
          'contract',
          'salary',
          'relieving'
        ]));
  });

  test('service length, attendance and leave follow the clock', () {
    final early = PersonnelFile.fromJson(
        HrDemoData.at(DateTime(2026, 1, 20)).file('EMP-0001'));
    final late = PersonnelFile.fromJson(
        HrDemoData.at(DateTime(2026, 10, 5)).file('EMP-0001'));
    final gap = DateTime(2026, 10, 5).difference(DateTime(2026, 1, 20)).inDays;
    expect(
        _serviceDays(late.header.serviceLength!) -
            _serviceDays(early.header.serviceLength!),
        closeTo(gap, 2));
    expect(
        PersonnelFile.fromJson(
                HrDemoData.at(DateTime(2026, 1, 3)).file('EMP-0006'))
            .header
            .serviceLength!
            .label,
        isNotEmpty);
    final attendance =
        PersonnelFile.fromJson(_clock.file('EMP-0006')).attendance!;
    expect(attendance.fromDate, '2026-10-01');
    expect(attendance.toDate, '2026-10-05');
    expect(
        attendance.present +
            attendance.absent +
            attendance.onLeave +
            attendance.halfDay,
        greaterThanOrEqualTo(attendance.present));
    expect(attendance.present, greaterThan(0));
    expect(attendance.lateEntries, lessThanOrEqualTo(attendance.present));
  });

  test('every seeded row is marked as a sample and local people stay local',
      () {
    expect(hrDemoEmployeeCodes, hasLength(12));
    for (final row in _clock.rows()) {
      expect(row['is_sample'], isTrue);
      expect(row['is_user_created'], isFalse);
      expect(_clock.isSeeded('${row['id']}'), isTrue);
      expect(_clock.row('LOCAL-1'), isNull);
      expect(_clock.isSeeded('LOCAL-1'), isFalse);
      expect(_clock.record('DEMO-DOC-LOCAL-1-1'), isNull);
    }
    final json = _clock.file('EMP-0003');
    expect(json['is_sample'], isTrue);
    expect(json['header'], isA<Map<String, dynamic>>());
    for (final section in [
      'header',
      'personal',
      'organization',
      'employment'
    ]) {
      expect((json[section]! as Map)['is_sample'], isTrue, reason: section);
    }
    for (final row in json['contracts']! as List) {
      expect((row as Map)['is_sample'], isTrue);
    }
    for (final row in json['documents']! as List) {
      expect((row as Map)['is_sample'], isTrue);
    }
    for (final row in json['history']! as List) {
      expect((row as Map)['is_sample'], isTrue);
    }
    for (final row in json['activity']! as List) {
      expect((row as Map)['is_sample'], isTrue);
    }
    expect(_clock.detail('EMP-0003')['is_sample'], isTrue);
    expect(_clock.detail('EMP-0003')['can_edit'], isFalse);
    expect((_clock.detail('EMP-0003')['profile']! as Map)['is_sample'], isTrue);
    final legacy = (_clock.detail('EMP-0003')['records']! as List)
        .cast<Map<String, dynamic>>();
    expect(legacy, isNotEmpty);
    for (final row in legacy) {
      expect(row['is_sample'], isTrue);
      expect('${row['title']}'.trim(), isNotEmpty);
      expect(_clock.record('${row['name']}')?['file'], isNotNull);
    }
    expect(_clock.home()['profile_id'], hrDemoSelfEmployeeCode);
    expect(_clock.announcements(), hasLength(3));
    for (final note in _clock.announcements()) {
      expect(note['is_sample'], isTrue);
      expect('${note['title']}'.trim(), isNotEmpty);
      expect(DateTime.tryParse('${note['date']}'), isNotNull);
    }
  });

  test('attachments stay small enough for a phone preview', () {
    var total = 0;
    for (final code in hrDemoEmployeeCodes) {
      total +=
          base64Decode('${_clock.record(_clock.photoRecordId(code))?['file']}')
              .length;
      final file = _clock.file(code);
      for (final row in (file['documents']! as List).cast<Map>()) {
        total +=
            base64Decode('${_clock.record('${row['id']}')?['file']}').length;
      }
      for (final row in (file['contracts']! as List).cast<Map>()) {
        total += base64Decode(
                '${_clock.contractFile('${row['name']}')?.contentBase64}')
            .length;
      }
      for (final row in (_clock.detail(code)['records']! as List).cast<Map>()) {
        total +=
            base64Decode('${_clock.record('${row['name']}')?['file']}').length;
      }
    }
    expect(total, lessThan(300 * 1024));
    expect(total, greaterThan(0));
  });
}
