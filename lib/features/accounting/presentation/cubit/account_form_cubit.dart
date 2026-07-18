import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

part 'account_form_state.dart';

class AccountFormCubit extends Cubit<AccountFormState> {
  AccountFormCubit({
    AccountNode? account,
    this.company,
    this.repository,
  }) : super(AccountFormState(
          mode: account == null ? AccountFormMode.create : AccountFormMode.edit,
          originalId: account?.id,
          code: account?.code ?? '',
          title: account?.title ?? '',
          level: account?.level ?? AccountLevel.ledger,
          parentId: account?.parentId,
          nature: account?.nature ?? AccountNature.debit,
          isActive: account?.isActive ?? true,
          autoCode: account == null,
        ));

  final String? company;
  final ChartOfAccountsRepository? repository;

  void setTitle(String value) => emit(state.copyWith(title: value));
  void setCode(String value) => emit(state.copyWith(code: value));
  void setLevel(AccountLevel value) =>
      emit(state.copyWith(level: value, parentId: null));
  void setParent(String? value) =>
      emit(state.copyWith(parentId: value, clearParent: value == null));
  void setNature(AccountNature value) => emit(state.copyWith(nature: value));
  void setActive(bool value) => emit(state.copyWith(isActive: value));
  void setAutoCode(bool value) => emit(state.copyWith(autoCode: value));

  Future<void> submit() async {
    if (!state.isValid) {
      emit(state.copyWith(status: AccountFormStatus.invalid));
      return;
    }
    if (repository == null || company == null || company!.trim().isEmpty) {
      emit(state.copyWith(
        status: AccountFormStatus.failure,
        message: 'برای ذخیره حساب، دفتر فعال و اتصال ERPNext لازم است.',
      ));
      return;
    }
    emit(state.copyWith(status: AccountFormStatus.saving, clearMessage: true));
    try {
      final saved = state.mode == AccountFormMode.create
          ? await repository!.createAccount(
              company!,
              state.toEntity(),
              autoCode: state.autoCode,
            )
          : await repository!.updateAccount(company!, state.toEntity());
      emit(state.copyWith(
        status: AccountFormStatus.success,
        savedAccount: saved,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: AccountFormStatus.failure,
        message: 'ذخیره حساب در ERPNext انجام نشد.',
      ));
    }
  }
}
