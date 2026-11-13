import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/cubit/offices_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

final _office = Office(
  name: 'دفتر نمونه',
  type: OfficeType.personal,
  fiscalYearStart: DateTime(2026),
);

class _OfficeRepository implements OfficeRepository {
  _OfficeRepository({this.error});
  final Object? error;

  @override
  Future<Office> createOffice(Office office) async => office;
  @override
  Future<Office> updateOffice(String id, Office office) async => office;
  @override
  Future<List<Office>> listOffices() async => [_office];
  @override
  Future<Office?> getDefaultOffice() async => _office;
  @override
  Future<Office> setDefaultOffice(Office office) async {
    if (error != null) throw error!;
    return office;
  }
}

void main() {
  group('OfficesCubit.selectDefault', () {
    blocTest<OfficesCubit, OfficesState>(
      'در خطای ممنوعیت دلیل واقعی را نشان می‌دهد نه جملهٔ عمومی',
      build: () => OfficesCubit(
        repository: _OfficeRepository(
          error: const ApiException(
            kind: ApiFailureKind.forbidden,
            message: 'Not permitted',
            statusCode: 403,
          ),
        ),
      ),
      act: (cubit) => cubit.selectDefault(_office),
      verify: (cubit) {
        expect(cubit.state.changingDefault, isFalse);
        expect(cubit.state.message, forbiddenFailureMessage);
        expect(cubit.state.message, isNot('تغییر دفتر فعال انجام نشد.'));
      },
    );

    blocTest<OfficesCubit, OfficesState>(
      'در خطای اعتبارسنجی دلیل واقعی را نشان می‌دهد نه جملهٔ عمومی',
      build: () => OfficesCubit(
        repository: _OfficeRepository(
          error: const ApiException(
            kind: ApiFailureKind.validation,
            message: 'ASOUD setup does not exist for this company',
            statusCode: 417,
          ),
        ),
      ),
      act: (cubit) => cubit.selectDefault(_office),
      verify: (cubit) {
        expect(cubit.state.changingDefault, isFalse);
        expect(cubit.state.message,
            failureMessage(const ApiException(
                kind: ApiFailureKind.validation,
                message: 'ASOUD setup does not exist for this company')));
        expect(cubit.state.message, isNot('تغییر دفتر فعال انجام نشد.'));
      },
    );

    blocTest<OfficesCubit, OfficesState>(
      'در موفقیت دفتر فعال را به‌روز می‌کند و پیام موفقیت می‌دهد',
      build: () => OfficesCubit(repository: _OfficeRepository()),
      act: (cubit) => cubit.selectDefault(_office),
      verify: (cubit) {
        expect(cubit.state.changingDefault, isFalse);
        expect(cubit.state.defaultOffice, _office);
        expect(cubit.state.message, 'دفتر فعال با موفقیت تغییر کرد.');
      },
    );

    blocTest<OfficesCubit, OfficesState>(
      'در خطای شبکهٔ قابل‌تلاش‌شدن حالت آفلاین را نگه می‌دارد',
      build: () => OfficesCubit(
        repository: _OfficeRepository(
          error: const ApiException(
            kind: ApiFailureKind.network,
            message: 'offline',
          ),
        ),
      ),
      act: (cubit) => cubit.selectDefault(_office),
      verify: (cubit) {
        expect(cubit.state.changingDefault, isFalse);
        expect(cubit.state.offlinePreview, isTrue);
        expect(cubit.state.message,
            'دفتر فعال روی گوشی تغییر کرد و پس از اتصال همگام می‌شود.');
      },
    );
  });
}
