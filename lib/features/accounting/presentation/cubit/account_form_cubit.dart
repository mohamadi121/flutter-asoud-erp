import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

part 'account_form_state.dart';

class AccountFormCubit extends Cubit<AccountFormState> {
  AccountFormCubit({AccountNode? account, ChartOfAccountsRepository? repository})
      : _repository = repository,
        super(AccountFormState(
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

  final ChartOfAccountsRepository? _repository;

  void setTitle(String value) => emit(state.copyWith(title: value));
  void setCode(String value) => emit(state.copyWith(code: value));
  void setLevel(AccountLevel value) {
    emit(state.copyWith(level: value, clearParent: true, code: ''));
    _refreshSuggestedCode();
  }
  void setParent(String? value) {
    emit(state.copyWith(parentId: value, clearParent: value == null, code: ''));
    _refreshSuggestedCode();
  }
  void setNature(AccountNature value) => emit(state.copyWith(nature: value));
  void setActive(bool value) => emit(state.copyWith(isActive: value));
  void setAutoCode(bool value) {
    emit(state.copyWith(autoCode: value, code: value ? '' : state.code));
    if (value) _refreshSuggestedCode();
  }

  Future<void> _refreshSuggestedCode() async {
    if (!state.autoCode || _repository == null) return;
    if (state.requiresParent && (state.parentId?.isEmpty ?? true)) return;
    try {
      final code = await _repository.previewNextCode(
        state.level,
        parentId: state.parentId,
      );
      if (!isClosed && state.autoCode) emit(state.copyWith(code: code));
    } catch (_) {
      // Preview is informative; the backend performs the final validation on save.
    }
  }

  Future<void> submit() async {
    if (!state.isValid) {
      emit(state.copyWith(status: AccountFormStatus.invalid));
      return;
    }
    if (_repository == null) {
      emit(state.copyWith(status: AccountFormStatus.success, savedAccount: state.toEntity()));
      return;
    }
    emit(state.copyWith(status: AccountFormStatus.saving));
    try {
      final entity = state.toEntity();
      final saved = state.mode == AccountFormMode.create
          ? await _repository.createAccount(entity)
          : await _repository.updateAccount(entity);
      emit(state.copyWith(status: AccountFormStatus.success, savedAccount: saved));
    } catch (error) {
      emit(state.copyWith(status: AccountFormStatus.failure, message: error.toString()));
    }
  }
}
