import 'dart:async';

import 'package:asoud_erp/features/office_setup/data/repositories/server_first_office_repository.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

void main() {
  Office office(String name) => Office(
        name: name,
        type: OfficeType.legal,
        fiscalYearStart: DateTime(2025, 3, 21),
      );

  test('preview without an office selects the demo company', () async {
    final repository = ServerFirstOfficeRepository(
      _Remote(),
      local: FakeLocalRecordStore(),
      localPreview: () => true,
    );

    final current = await repository.getDefaultOffice();
    expect(current, isNotNull);
    expect(current!.name, 'شرکت نمونه آسود');
    expect(current.fiscalYear, contains('سال مالی'));
    expect(current.chartTemplate, 'استاندارد ایران');
    expect((await repository.listOffices()).single.name, 'شرکت نمونه آسود');
  });

  test('a created office replaces the demo company in preview', () async {
    final local = FakeLocalRecordStore();
    final repository = ServerFirstOfficeRepository(
      _Remote(),
      local: local,
      localPreview: () => true,
    );

    await repository.createOffice(office('دفتر واقعی من'));
    await repository.setDefaultOffice(office('دفتر واقعی من'));

    expect((await repository.getDefaultOffice())?.name, 'دفتر واقعی من');
    expect(
      (await repository.listOffices()).map((item) => item.name),
      contains('دفتر واقعی من'),
    );
    expect(
      (await repository.listOffices()).map((item) => item.name),
      isNot(contains('شرکت نمونه آسود')),
    );
  });

  test('an authenticated session never sees the demo company', () async {
    final repository = ServerFirstOfficeRepository(
      _Remote(),
      local: FakeLocalRecordStore(),
      defaultOfficeTimeout: const Duration(milliseconds: 10),
    );

    expect(await repository.getDefaultOffice(), isNull);
    expect(await repository.listOffices(), isEmpty);
  });
}

class _Remote implements OfficeRepository {
  @override
  Future<Office> createOffice(Office value) async => value;

  @override
  Future<Office> updateOffice(String id, Office value) async => value;

  @override
  Future<List<Office>> listOffices() async => const [];

  @override
  Future<Office?> getDefaultOffice() => Completer<Office?>().future;

  @override
  Future<Office> setDefaultOffice(Office value) async => value;
}
