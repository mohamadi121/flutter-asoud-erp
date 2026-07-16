import 'package:asoud_erp/features/base_setup/domain/entities/accounting_setup.dart';
import 'package:asoud_erp/features/base_setup/domain/entities/setup_status.dart';
import 'package:asoud_erp/features/base_setup/domain/repositories/setup_repository.dart';
import 'package:asoud_erp/features/base_setup/presentation/bloc/roles_setup_cubit.dart';
import 'package:bloc_test/bloc_test.dart';

class FakeRolesRepository implements SetupRepository {
  Set<String>? saved;
  @override
  Future<SetupStatus> getStatus({String? company}) async => const SetupStatus();
  @override
  Future<SetupStatus> saveAccounting(String company, AccountingSetup setup) async => const SetupStatus();
  @override
  Future<SetupStatus> saveEnabledRoles(String company, Set<String> roles) async {
    saved = roles;
    return SetupStatus(company: company, officeSaved: true, accountingSaved: true, rolesSaved: true);
  }
}

void main() {
  blocTest<RolesSetupCubit, RolesSetupState>(
    'System Manager قابل حذف نیست',
    build: () => RolesSetupCubit(FakeRolesRepository(), 'ASOUD'),
    act: (cubit) => cubit.toggle('System Manager', false),
    expect: () => const <RolesSetupState>[],
  );

  blocTest<RolesSetupCubit, RolesSetupState>(
    'نقش‌ها فقط بعد از پاسخ Repository موفق می‌شوند',
    build: () => RolesSetupCubit(FakeRolesRepository(), 'ASOUD'),
    act: (cubit) => cubit.submit(),
    expect: () => const [
      RolesSetupState(status: RolesSetupStatus.saving),
      RolesSetupState(status: RolesSetupStatus.success),
    ],
  );
}
