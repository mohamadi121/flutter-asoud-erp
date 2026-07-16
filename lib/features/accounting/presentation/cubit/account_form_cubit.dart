import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/account_node.dart';

part 'account_form_state.dart';

class AccountFormCubit extends Cubit<AccountFormState> {
  AccountFormCubit({AccountNode? account})
      : super(AccountFormState(
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

  void setTitle(String value) => emit(state.copyWith(title: value));
  void setCode(String value) => emit(state.copyWith(code: value));
  void setLevel(AccountLevel value) => emit(state.copyWith(level: value, parentId: null));
  void setParent(String? value) => emit(state.copyWith(parentId: value, clearParent: value == null));
  void setNature(AccountNature value) => emit(state.copyWith(nature: value));
  void setActive(bool value) => emit(state.copyWith(isActive: value));
  void setAutoCode(bool value) => emit(state.copyWith(autoCode: value));

  void submit() {
    if (!state.isValid) {
      emit(state.copyWith(status: AccountFormStatus.invalid));
      return;
    }
    emit(state.copyWith(status: AccountFormStatus.success));
  }
}

