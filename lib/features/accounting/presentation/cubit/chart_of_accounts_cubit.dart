import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

part 'chart_of_accounts_state.dart';

class ChartOfAccountsCubit extends Cubit<ChartOfAccountsState> {
  ChartOfAccountsCubit([this._repository]) : super(const ChartOfAccountsState());

  final ChartOfAccountsRepository? _repository;

  Future<void> load() async {
    if (_repository == null) {
      emit(const ChartOfAccountsState(status: ChartStatus.success, accounts: _sampleAccounts));
      return;
    }
    emit(const ChartOfAccountsState(status: ChartStatus.loading));
    try {
      final accounts = await _repository.getAccounts();
      emit(ChartOfAccountsState(status: ChartStatus.success, accounts: accounts));
    } catch (error) {
      emit(ChartOfAccountsState(status: ChartStatus.failure, message: error.toString()));
    }
  }
}

const _sampleAccounts = [
  AccountNode(id: '1', code: '1', title: 'دارایی‌ها', level: AccountLevel.group, children: [
    AccountNode(id: '11', code: '11', title: 'دارایی‌های جاری', level: AccountLevel.general, parentId: '1', children: [
      AccountNode(id: '1101', code: '1101', title: 'موجودی نقد و بانک', level: AccountLevel.ledger, parentId: '11'),
      AccountNode(id: '1102', code: '1102', title: 'حساب‌ها و اسناد دریافتنی', level: AccountLevel.ledger, parentId: '11'),
    ]),
  ]),
  AccountNode(id: '2', code: '2', title: 'بدهی‌ها', level: AccountLevel.group, children: [
    AccountNode(id: '21', code: '21', title: 'بدهی‌های جاری', level: AccountLevel.general, parentId: '2'),
  ]),
  AccountNode(id: '3', code: '3', title: 'حقوق مالکانه', level: AccountLevel.group),
  AccountNode(id: '4', code: '4', title: 'درآمدها', level: AccountLevel.group),
  AccountNode(id: '5', code: '5', title: 'هزینه‌ها', level: AccountLevel.group),
];
