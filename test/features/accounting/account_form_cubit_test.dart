import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/presentation/cubit/account_form_cubit.dart';
import 'package:bloc_test/bloc_test.dart';

void main() {
  blocTest<AccountFormCubit, AccountFormState>(
    'حساب معین بدون والد نامعتبر است',
    build: AccountFormCubit.new,
    act: (cubit) => cubit
      ..setTitle('بانک‌ها')
      ..submit(),
    verify: (cubit) {
      assert(cubit.state.status == AccountFormStatus.invalid);
    },
  );

  blocTest<AccountFormCubit, AccountFormState>(
    'فرم معتبر بدون repository موفقیت ساختگی صادر نمی‌کند',
    build: AccountFormCubit.new,
    act: (cubit) => cubit
      ..setLevel(AccountLevel.detail)
      ..setParent('1101')
      ..setTitle('بانک ملت')
      ..submit(),
    verify: (cubit) {
      assert(cubit.state.status == AccountFormStatus.failure);
      assert(cubit.state.toEntity().level == AccountLevel.detail);
    },
  );
}
