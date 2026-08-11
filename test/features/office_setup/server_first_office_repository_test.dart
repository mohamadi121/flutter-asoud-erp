import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/office_setup/data/repositories/server_first_office_repository.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

void main() {
  final office = Office(
    name: 'دفتر نمونه',
    type: OfficeType.personal,
    fiscalYearStart: DateTime(2026),
  );

  test('در اتصال سالم ابتدا سرور ثبت و سپس نسخه محلی synced می‌شود', () async {
    final local = FakeLocalRecordStore();
    final remote = _OfficeRepository(office);
    final repository = ServerFirstOfficeRepository(remote, local: local);

    expect(await repository.createOffice(office), office);

    expect(remote.createCalls, 1);
    expect(local.records.values.single.status, LocalSyncStatus.synced);
  });

  test('در خطای شبکه دفتر محلی pending می‌شود و موفقیت سرور جعل نمی‌شود',
      () async {
    final local = FakeLocalRecordStore();
    final remote = _OfficeRepository(office, error: _networkError);
    final repository = ServerFirstOfficeRepository(remote, local: local);

    await expectLater(repository.createOffice(office), throwsA(_networkError));

    expect(local.records.values.single.status, LocalSyncStatus.pendingSync);
    expect((await repository.listOffices()).single.name, office.name);
  });

  test('خطای اعتبارسنجی باعث ذخیره آفلاین نمی‌شود', () async {
    final local = FakeLocalRecordStore();
    const validation = ApiException(
      kind: ApiFailureKind.validation,
      message: 'invalid',
    );
    final repository = ServerFirstOfficeRepository(
      _OfficeRepository(office, error: validation),
      local: local,
    );

    await expectLater(repository.createOffice(office), throwsA(validation));
    expect(local.records, isEmpty);
  });
}

const _networkError = ApiException(
  kind: ApiFailureKind.network,
  message: 'offline',
);

class _OfficeRepository implements OfficeRepository {
  _OfficeRepository(this.office, {this.error});
  final Office office;
  final ApiException? error;
  int createCalls = 0;

  Never _throw() => throw error!;

  @override
  Future<Office> createOffice(Office value) async {
    createCalls++;
    if (error != null) _throw();
    return office;
  }

  @override
  Future<Office> updateOffice(String id, Office value) => createOffice(value);

  @override
  Future<List<Office>> listOffices() async {
    if (error != null) _throw();
    return [office];
  }

  @override
  Future<Office?> getDefaultOffice() async {
    if (error != null) _throw();
    return office;
  }
}
