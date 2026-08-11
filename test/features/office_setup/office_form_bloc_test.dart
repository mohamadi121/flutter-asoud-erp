import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/presentation/bloc/office_form_bloc.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_office_repository.dart';

void main() {
  group('OfficeFormBloc', () {
    blocTest<OfficeFormBloc, OfficeFormState>(
      'تغییر نوع دفتر و مقدار فیلدها را نگه می‌دارد',
      build: () => OfficeFormBloc(
          officeType: OfficeType.personal, repository: FakeOfficeRepository()),
      act: (bloc) => bloc
        ..add(const OfficeFieldChanged('officeName', 'دفتر مرکزی'))
        ..add(const OfficeTypeChanged(OfficeType.legal)),
      verify: (bloc) {
        expect(bloc.state.officeType, OfficeType.legal);
        expect(bloc.state.officeName, 'دفتر مرکزی');
      },
    );

    blocTest<OfficeFormBloc, OfficeFormState>(
      'در حالت دمو خطای شبکه به offlinePreview می‌رود نه success',
      build: () => OfficeFormBloc(
        officeType: OfficeType.personal,
        repository: FakeOfficeRepository(
          error: const ApiException(
            kind: ApiFailureKind.network,
            message: 'خطای شبکه',
          ),
        ),
        allowOfflinePreview: true,
      ),
      act: (bloc) => bloc
        ..add(const OfficeFieldChanged('officeName', 'دفتر آفلاین'))
        ..add(const OfficeFieldChanged('ownerFullName', 'علی محمدی'))
        ..add(const OfficeFieldChanged('activityType', 'خدمات'))
        ..add(const OfficeFieldChanged('nationalId', '0012345678'))
        ..add(const OfficeFieldChanged('phone', '09121234567'))
        ..add(const OfficeFieldChanged('province', 'تهران'))
        ..add(const OfficeFieldChanged('city', 'تهران'))
        ..add(const OfficeFieldChanged('address', 'خیابان آزادی'))
        ..add(const OfficeFieldChanged('postalCode', '1234567890'))
        ..add(const OfficeFieldChanged('fiscalYear', '1405'))
        ..add(const OfficeFieldChanged('chartTemplate', 'الگوی خدماتی'))
        ..add(const OfficeFormSubmitted()),
      verify: (bloc) {
        expect(bloc.state.status, OfficeFormStatus.offlinePreview);
        expect(bloc.state.createdOffice?.name, 'دفتر آفلاین');
      },
    );

    blocTest<OfficeFormBloc, OfficeFormState>(
      'فقط نام دفتر فیلد اجباری است',
      build: () => OfficeFormBloc(
          officeType: OfficeType.legal, repository: FakeOfficeRepository()),
      act: (bloc) => bloc.add(const OfficeFormSubmitted()),
      verify: (bloc) {
        expect(bloc.state.status, OfficeFormStatus.invalid);
        expect(bloc.state.errors, contains('officeName'));
        expect(bloc.state.errors, isNot(contains('registrationNumber')));
        expect(bloc.state.errors, isNot(contains('nationalId')));
      },
    );

    blocTest<OfficeFormBloc, OfficeFormState>(
      'فرم معتبر فقط پس از پاسخ موفق repository موفق می‌شود',
      build: () => OfficeFormBloc(
          officeType: OfficeType.personal, repository: FakeOfficeRepository()),
      act: (bloc) => bloc
        ..add(const OfficeFieldChanged('officeName', 'دفتر مرکزی'))
        ..add(const OfficeFieldChanged('ownerFullName', 'علی محمدی'))
        ..add(const OfficeFieldChanged('activityType', 'خدمات'))
        ..add(const OfficeFieldChanged('nationalId', '0012345678'))
        ..add(const OfficeFieldChanged('phone', '09121234567'))
        ..add(const OfficeFieldChanged('province', 'تهران'))
        ..add(const OfficeFieldChanged('city', 'تهران'))
        ..add(const OfficeFieldChanged('address', 'خیابان آزادی'))
        ..add(const OfficeFieldChanged('postalCode', '1234567890'))
        ..add(const OfficeFieldChanged('fiscalYear', '1405'))
        ..add(const OfficeFieldChanged('chartTemplate', 'الگوی خدماتی'))
        ..add(const OfficeFormSubmitted()),
      verify: (bloc) {
        expect(bloc.state.errors, isEmpty);
        expect(bloc.state.status, OfficeFormStatus.success);
        expect(bloc.state.createdOffice?.name, 'دفتر مرکزی');
      },
    );
  });
}
