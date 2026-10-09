import 'dart:async';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/demo/hr_demo_data.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeClient {}

/// The repositories only serve the seeded people while nobody is signed in; a
/// real session keeps talking to the server.
void main() {
  final clock = HrDemoData.at(DateTime(2026, 10, 5));

  _Client offline() {
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.serverIdentity).thenReturn('https://preview.example');
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream<bool>.empty());
    return client;
  }

  test('detail exposes every demo document and photo through legacy records',
      () async {
    final repository = PersonnelRepository(offline(),
        local: FakeLocalRecordStore(), demoData: clock);
    addTearDown(repository.dispose);
    for (final code in hrDemoEmployeeCodes) {
      final detail = await repository.detail(code);
      final profile = detail['profile'] as Map;
      final records = (detail['records'] as List).cast<Map>();
      final file = clock.file(code);
      final documents = (file['documents'] as List).cast<Map>();
      expect(
          records
              .where((row) => row['kind'] == 'document')
              .map((row) => row['name']),
          documents.map((row) => row['id']));
      expect(records.where((row) => row['kind'] == 'photo').single['name'],
          clock.photoRecordId(code));
      expect(
          profile['company_email'], (file['personal'] as Map)['company_email']);
      expect(profile['emergency_contact_name'],
          ((file['personal'] as Map)['emergency'] as Map)['name']);
      for (final row in records) {
        final record = await repository.record(row['name'] as String);
        expect(record['date'], row['record_date']);
        expect(record['kind'], row['kind']);
        expect(record['file'], isNotEmpty);
        expect(record['_can_edit'], isFalse);
      }
      for (final field in financialPersonnelFields) {
        expect(profile.containsKey(field), isFalse, reason: '$code/$field');
      }
    }
  });

  test('an offline preview lists the seeded people of the sample company',
      () async {
    final store = FakeLocalRecordStore();
    final repository =
        PersonnelRepository(offline(), local: store, demoData: clock);
    addTearDown(repository.dispose);
    await store
        .save(id: 'party:LOCAL-1', entityType: 'party_profile', payload: {
      'id': 'LOCAL-1',
      'company': hrDemoCompany,
      'roles': ['employee'],
      'display_name': 'کارمنل محلی',
    });

    final result = await repository.list(hrDemoCompany);
    final rows = (result['rows'] as List).cast<Map<String, dynamic>>();
    expect(rows, hasLength(13));
    final seeded = rows.where((row) => row['is_sample'] == true).toList();
    expect(seeded, hasLength(12));
    expect(seeded.map((row) => '${row['id']}').toList(), hrDemoEmployeeCodes);
    for (final row in rows) {
      expect(row['display_name'], isNotEmpty);
    }
    for (final row in seeded) {
      expect(row['is_sample'], isTrue);
      expect(row['is_user_created'], isFalse);
      expect(row['national_id'], isNotEmpty);
      expect(row['employee_code'], '${row['id']}');
      expect(row['photo_record'], clock.photoRecordId('${row['id']}'));
    }
    // Seeded rows never carry financial fields, not even for managers.
    for (final field in financialPersonnelFields) {
      expect(seeded.first.containsKey(field), isFalse, reason: field);
    }
    // Another company only sees its own people.
    final other = (await repository.list('شرکت دیگر'))['rows'] as List;
    expect(other, isEmpty);
  });

  test('seeded profiles and their attachments are read-only', () async {
    final store = FakeLocalRecordStore();
    final repository =
        PersonnelRepository(offline(), local: store, demoData: clock);
    addTearDown(repository.dispose);

    final detail = await repository.detail('EMP-0004');
    expect(detail['can_edit'], isFalse);
    expect((detail['profile'] as Map)['is_sample'], isTrue);
    expect((detail['records'] as List), isNotEmpty);

    final photo = await repository.record('DEMO-PHOTO-EMP-0004');
    expect('${photo['file']}', isNotEmpty);
    final document = await repository.record('DEMO-DOC-EMP-0004-1');
    expect('${document['file']}', isNotEmpty);
    expect(document['_can_edit'], isFalse);

    expect(() => repository.update('EMP-0004', {'mobile': '09120000000'}, 'x'),
        throwsA(anything));
    expect(
        () => repository.add('EMP-0004', {'kind': 'document'}, 'request-1234'),
        throwsA(anything));
    expect(() => repository.record('DEMO-DOC-EMP-9999-1'), throwsA(anything));
  });

  test('the file repository serves the preview while signed out', () async {
    final store = FakeLocalRecordStore();
    final repository =
        PersonnelFileRepository(offline(), store: store, demoData: clock);

    final file = await repository.file('EMP-0002');
    expect(file.profileId, 'EMP-0002');
    expect(file.documents, isNotEmpty);
    expect(file.contracts, isNotEmpty);
    expect(file.history, isNotEmpty);

    final self = await repository.myFile();
    expect(self.profileId, hrDemoSelfEmployeeCode);
    expect(self.salary.visible, isFalse);
    expect(self.header.name, isNotEmpty);

    final home = await repository.myHome();
    expect(home.profileId, hrDemoSelfEmployeeCode);
    expect(home.announcements, isNotEmpty);
    expect((await repository.announcements()).length, greaterThan(1));

    final contract = await repository.contractFile('CT-EMP-0002-1');
    expect(contract.filename, 'contract-EMP-0002-1.pdf');
    expect(contract.contentBase64, isNotEmpty);
  });

  test('a signed-in session reads the server, never the sample data', () async {
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.serverIdentity).thenReturn('https://erp.example');
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream<bool>.empty());
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
            userId: 'hr@example.com', fullName: 'HR', roles: ['HR Manager']));
    when(() => client.callMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => {
              'message': {
                'data': {
                  'rows': [
                    {'id': 'EMP-9001', 'display_name': 'کارمند واقعی'},
                  ],
                  'can_edit': true,
                }
              }
            });
    // `callAsoudMethod` hands back the unwrapped `message.data` payload.
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      final method = call.positionalArguments.first as String;
      if (method.endsWith('list_announcements')) {
        return <Map<String, dynamic>>[
          {'name': 'NEWS-1', 'title': 'خبر سرور', 'content': 'متن'}
        ];
      }
      if (method.endsWith('get_contract_file')) {
        return {
          'filename': 'server-contract.pdf',
          'content_base64': 'JVBERi0='
        };
      }
      return {
        'profile_id': 'EMP-9001',
        'profile': {'id': 'EMP-9001', 'display_name': 'کارمند واقعی'},
      };
    });
    final store = FakeLocalRecordStore();
    final personnel =
        PersonnelRepository(client, local: store, demoData: clock);
    final files =
        PersonnelFileRepository(client, store: store, demoData: clock);
    addTearDown(personnel.dispose);

    final rows = ((await personnel.list(hrDemoCompany))['rows'] as List)
        .cast<Map<String, dynamic>>();
    expect(rows, hasLength(1));
    expect(rows.single['id'], 'EMP-9001');

    final file = await files.file('EMP-0002');
    expect(file.profileId, 'EMP-9001');
    expect((await files.announcements()).single.title, 'خبر سرور');
    expect((await files.contractFile('CT-EMP-0002-1')).filename,
        'server-contract.pdf');
  });
}
