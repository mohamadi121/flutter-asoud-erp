import 'package:asoud_erp/features/base_setup/domain/entities/accounting_setup.dart';
import 'package:asoud_erp/features/base_setup/domain/entities/setup_status.dart';
import 'package:asoud_erp/features/base_setup/domain/repositories/setup_repository.dart';
import 'package:asoud_erp/features/base_setup/presentation/bloc/base_setup_cubit.dart';
import 'package:bloc_test/bloc_test.dart';

class FakeSetupRepository implements SetupRepository {
  FakeSetupRepository({this.error});
  final Object? error;

  @override
  Future<SetupStatus> getStatus({String? company}) async => const SetupStatus();

  @override
  Future<SetupStatus> saveAccounting(String company, AccountingSetup setup) async {
    if (error != null) throw error!;
    return SetupStatus(company: company, officeSaved: true, accountingSaved: true);
  }

  @override
  Future<SetupStatus> saveEnabledRoles(String company, Set<String> roles) async => const SetupStatus();
}

void main() {
  blocTest<BaseSetupCubit, BaseSetupState>(
    'واحد نمایش تومان قابل انتخاب است',
    build: () => BaseSetupCubit(FakeSetupRepository(), 'ASOUD'),
    act: (cubit) => cubit.setMoneyUnit(MoneyUnit.toman),
    expect: () => const [BaseSetupState(moneyUnit: MoneyUnit.toman)],
  );

  blocTest<BaseSetupCubit, BaseSetupState>(
    'ذخیره موفق از loading عبور می‌کند',
    build: () => BaseSetupCubit(FakeSetupRepository(), 'ASOUD'),
    act: (cubit) => cubit.submit(),
    expect: () => const [
      BaseSetupState(status: BaseSetupStatus.saving),
      BaseSetupState(status: BaseSetupStatus.success),
    ],
  );
}
