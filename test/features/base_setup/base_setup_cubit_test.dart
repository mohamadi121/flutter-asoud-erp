import 'package:asoud_erp/features/base_setup/domain/entities/accounting_setup.dart';
import 'package:asoud_erp/features/base_setup/presentation/bloc/base_setup_cubit.dart';
import 'package:bloc_test/bloc_test.dart';

void main() {
  blocTest<BaseSetupCubit, BaseSetupState>(
    'واحد نمایش تومان قابل انتخاب است',
    build: BaseSetupCubit.new,
    act: (cubit) => cubit.setMoneyUnit(MoneyUnit.toman),
    expect: () => const [BaseSetupState(moneyUnit: MoneyUnit.toman)],
  );
}
