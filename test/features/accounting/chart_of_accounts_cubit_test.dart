import 'package:asoud_erp/features/accounting/presentation/cubit/chart_of_accounts_cubit.dart';
import 'package:bloc_test/bloc_test.dart';

void main() {
  blocTest<ChartOfAccountsCubit, ChartOfAccountsState>(
    'بدون اتصال repository داده ساختگی تولید نمی‌کند',
    build: ChartOfAccountsCubit.new,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      assert(cubit.state.status == ChartStatus.success);
      assert(cubit.state.accounts.isEmpty);
    },
  );
}
