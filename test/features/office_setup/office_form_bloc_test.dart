import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/bloc/office_form_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeOfficeRepository implements OfficeRepository {
  FakeOfficeRepository({this.error});
  final Object? error;
  int calls = 0;

  @override
  Future<Office> createOffice(Office office) async {
    calls++;
    if (error != null) throw error!;
    return office;
  }

  @override
  Future<Office> updateOffice(String id, Office office) async => office;
}

void main() {
  group('OfficeFormBloc', () {
    blocTest<OfficeFormBloc, OfficeFormState>(
      'دفتر حقیقی فقط بعد از ذخیره موفق می‌شود',
      build: () => OfficeFormBloc(officeType: OfficeType.personal, repository: FakeOfficeRepository()),
      act: (bloc) => bloc
        ..add(const OfficeNameChanged('دفتر مرکزی'))
        ..add(const OfficeFormSubmitted()),
      expect: () => [
        const OfficeFormState(officeType: OfficeType.personal, name: 'دفتر مرکزی'),
        const OfficeFormState(officeType: OfficeType.personal, name: 'دفتر مرکزی', status: OfficeFormStatus.submitting),
        const OfficeFormState(officeType: OfficeType.personal, name: 'دفتر مرکزی', status: OfficeFormStatus.success),
      ],
    );

    blocTest<OfficeFormBloc, OfficeFormState>(
      'دفتر حقوقی بدون شناسه ملی به Repository ارسال نمی‌شود',
      build: () => OfficeFormBloc(officeType: OfficeType.legal, repository: FakeOfficeRepository()),
      act: (bloc) => bloc
        ..add(const OfficeNameChanged('شرکت آسود'))
        ..add(const OfficeFormSubmitted()),
      expect: () => [
        const OfficeFormState(officeType: OfficeType.legal, name: 'شرکت آسود'),
        const OfficeFormState(officeType: OfficeType.legal, name: 'شرکت آسود', status: OfficeFormStatus.invalid),
      ],
    );

    blocTest<OfficeFormBloc, OfficeFormState>(
      'خطای API به وضعیت failure تبدیل می‌شود',
      build: () => OfficeFormBloc(
        officeType: OfficeType.personal,
        repository: FakeOfficeRepository(error: Exception('network')),
      ),
      act: (bloc) => bloc
        ..add(const OfficeNameChanged('دفتر مرکزی'))
        ..add(const OfficeFormSubmitted()),
      expect: () => [
        const OfficeFormState(officeType: OfficeType.personal, name: 'دفتر مرکزی'),
        const OfficeFormState(officeType: OfficeType.personal, name: 'دفتر مرکزی', status: OfficeFormStatus.submitting),
        isA<OfficeFormState>().having((state) => state.status, 'status', OfficeFormStatus.failure),
      ],
    );
  });
}
