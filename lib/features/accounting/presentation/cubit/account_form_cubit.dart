import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/offline/offline_failure.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

part 'account_form_state.dart';

class AccountFormCubit extends Cubit<AccountFormState> {
  AccountFormCubit({
    AccountNode? account,
    AccountLevel? initialLevel,
    String? initialParentId,
    this.company,
    this.repository,
  }) : super(AccountFormState(
          mode: account == null ? AccountFormMode.create : AccountFormMode.edit,
          originalId: account?.id,
          code: account?.code ?? '',
          title: account?.title ?? '',
          level: account?.level ?? initialLevel ?? AccountLevel.group,
          parentId: account?.parentId ?? initialParentId,
          nature: account?.nature ?? AccountNature.debit,
          accountType: account?.accountType ?? '',
          isActive: account?.isActive ?? true,
          autoCode: account == null,
          detailGroupIds: account?.detailGroupIds ?? const [],
        ));

  final String? company;
  final ChartOfAccountsRepository? repository;

  void setTitle(String value) => emit(state.copyWith(title: value));
  void setCode(String value) => emit(state.copyWith(code: value));
  void setLevel(AccountLevel value) {
    if (state.mode == AccountFormMode.edit || value == state.level) return;
    emit(state.copyWith(level: value, clearParent: true, accountType: '',
        detailGroupIds: value == AccountLevel.detail ? const [] : state.detailGroupIds));
  }
  void setParent(String? value) =>
      emit(state.copyWith(parentId: value, clearParent: value == null));
  void setNature(AccountNature value) => emit(state.copyWith(nature: value));
  void setAccountType(String value) => emit(state.copyWith(accountType: value));
  void setActive(bool value) => emit(state.copyWith(isActive: value));
  void setAutoCode(bool value) => emit(state.copyWith(autoCode: value));
  void selectDetailGroup(String id, bool selected) {
    final ids = {...state.detailGroupIds};
    selected ? ids.add(id) : ids.remove(id);
    emit(state.copyWith(detailGroupIds: ids.toList()));
  }

  Future<void> submit() async {
    if (state.status == AccountFormStatus.saving) return;
    if (!state.isValid) {
      emit(state.copyWith(status: AccountFormStatus.invalid));
      return;
    }
    if (repository == null || company == null || company!.trim().isEmpty) {
      emit(state.copyWith(
        status: AccountFormStatus.failure,
        message:
            'برای ذخیره حساب، دفتر فعال یا حالت آفلاین ASOUD ERP لازم است.',
      ));
      return;
    }
    emit(state.copyWith(status: AccountFormStatus.saving, clearMessage: true));
    try {
      final accounts = await repository!.getAccounts(company!);
      final all = <AccountNode>[];
      void collect(List<AccountNode> nodes) {
        for (final node in nodes) {
          all.add(node);
          collect(node.children);
        }
      }
      collect(accounts);
      final hasChildren = all.any((a) => a.parentId == state.originalId &&
          state.originalId != null && a.level != AccountLevel.detail);
      final parent = all.where((a) => a.id == state.parentId).firstOrNull;
      if ((state.detailGroupIds.isNotEmpty && hasChildren) ||
          (state.level != AccountLevel.detail && parent?.isTerminal == true)) {
        emit(state.copyWith(status: AccountFormStatus.failure,
            message: 'حساب دارای زیرمجموعه نمی‌تواند نهایی شود؛ حساب نهایی نیز زیرمجموعه حساب نمی‌پذیرد.'));
        return;
      }
    } catch (_) {
      emit(state.copyWith(status: AccountFormStatus.failure,
          message: 'بررسی ساختار حساب ممکن نشد؛ اطلاعات ذخیره نشده است.'));
      return;
    }
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
    } catch (error) {
      if (isRetryableOfflineFailure(error)) {
        emit(state.copyWith(
          status: AccountFormStatus.offlineSaved,
          savedAccount: state.toEntity(),
          message:
              'اتصال برقرار نیست؛ حساب روی گوشی ذخیره شد و در انتظار همگام‌سازی است.',
        ));
        return;
      }
      emit(state.copyWith(
        status: AccountFormStatus.failure,
        message: 'ذخیره حساب در ASOUD ERP انجام نشد.',
      ));
    }
  }
}
