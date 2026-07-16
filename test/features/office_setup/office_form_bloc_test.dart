import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/presentation/bloc/office_form_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfficeFormBloc', () {
    blocTest<OfficeFormBloc, OfficeFormState>(
      'فرم حقیقی با نام معتبر موفق می‌شود',
      build: () => OfficeFormBloc(officeType: OfficeType.personal),
      act: (bloc) => bloc
        ..add(const OfficeNameChanged('دفتر مرکزی'))
        ..add(const OfficeFormSubmitted()),
      expect: () => [
        const OfficeFormState(officeType: OfficeType.personal, name: 'دفتر مرکزی'),
        const OfficeFormState(officeType: OfficeType.personal, name: 'دفتر مرکزی', status: OfficeFormStatus.success),
      ],
    );

    blocTest<OfficeFormBloc, OfficeFormState>(
      'دفتر حقوقی بدون شناسه ملی نامعتبر است',
      build: () => OfficeFormBloc(officeType: OfficeType.legal),
      act: (bloc) => bloc
        ..add(const OfficeNameChanged('شرکت آسود'))
        ..add(const OfficeFormSubmitted()),
      expect: () => [
        const OfficeFormState(officeType: OfficeType.legal, name: 'شرکت آسود'),
        const OfficeFormState(officeType: OfficeType.legal, name: 'شرکت آسود', status: OfficeFormStatus.invalid),
      ],
    );
  });
}

