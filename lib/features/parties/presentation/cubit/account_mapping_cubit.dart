import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../accounting/domain/entities/account_node.dart';
import '../../../accounting/domain/repositories/chart_of_accounts_repository.dart';
import '../../domain/entities/account_detail_mapping.dart';
import '../../domain/entities/detail_group.dart';
import '../../domain/repositories/parties_repository.dart';

enum AccountMappingStatus { loading, editing, saving, success, failure, invalid }

class AccountMappingState extends Equatable {
  const AccountMappingState({
    this.status = AccountMappingStatus.loading,
    this.accounts = const [],
    this.groups = const [],
    this.mappings = const [],
    this.accountId,
    this.groupCode,
    this.message,
  });

  final AccountMappingStatus status;
  final List<AccountNode> accounts;
  final List<DetailGroup> groups;
  final List<AccountDetailMapping> mappings;
  final String? accountId;
  final String? groupCode;
  final String? message;

  AccountMappingState copyWith({
    AccountMappingStatus? status,
    List<AccountNode>? accounts,
    List<DetailGroup>? groups,
    List<AccountDetailMapping>? mappings,
    String? accountId,
    String? groupCode,
    String? message,
  }) =>
      AccountMappingState(
        status: status ?? AccountMappingStatus.editing,
        accounts: accounts ?? this.accounts,
        groups: groups ?? this.groups,
        mappings: mappings ?? this.mappings,
        accountId: accountId ?? this.accountId,
        groupCode: groupCode ?? this.groupCode,
        message: message,
      );

  @override
  List<Object?> get props => [status, accounts, groups, mappings, accountId, groupCode, message];
}

class AccountMappingCubit extends Cubit<AccountMappingState> {
  AccountMappingCubit(this._partiesRepository, this._accountsRepository, this._company)
      : super(const AccountMappingState());

  final PartiesRepository _partiesRepository;
  final ChartOfAccountsRepository _accountsRepository;
  final String _company;

  Future<void> load() async {
    emit(const AccountMappingState());
    try {
      final results = await Future.wait([
        _accountsRepository.getAccounts(),
        _partiesRepository.getDetailGroups(),
        _partiesRepository.getAccountMappings(_company),
      ]);
      final allAccounts = _flatten(results[0] as List<AccountNode>)
          .where((account) => account.level == AccountLevel.ledger)
          .toList();
      emit(
        state.copyWith(
          accounts: allAccounts,
          groups: results[1] as List<DetailGroup>,
          mappings: results[2] as List<AccountDetailMapping>,
        ),
      );
    } catch (error) {
      emit(state.copyWith(status: AccountMappingStatus.failure, message: error.toString()));
    }
  }

  void setAccount(String? value) => emit(state.copyWith(accountId: value));
  void setGroup(String? value) => emit(state.copyWith(groupCode: value));

  Future<void> submit() async {
    if (state.accountId == null || state.groupCode == null) {
      emit(state.copyWith(status: AccountMappingStatus.invalid));
      return;
    }
    emit(state.copyWith(status: AccountMappingStatus.saving));
    try {
      await _partiesRepository.saveAccountMapping(
        _company,
        AccountDetailMapping(accountId: state.accountId!, groupCode: state.groupCode!),
      );
      await load();
    } catch (error) {
      emit(state.copyWith(status: AccountMappingStatus.failure, message: error.toString()));
    }
  }

  Iterable<AccountNode> _flatten(List<AccountNode> nodes) sync* {
    for (final node in nodes) {
      yield node;
      yield* _flatten(node.children);
    }
  }
}
