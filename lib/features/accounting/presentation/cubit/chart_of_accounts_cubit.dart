import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

part 'chart_of_accounts_state.dart';

class ChartOfAccountsCubit extends Cubit<ChartOfAccountsState> {
  ChartOfAccountsCubit({this.repository, this.company})
      : super(const ChartOfAccountsState());

  final ChartOfAccountsRepository? repository;
  final String? company;

  Future<void> load() async {
    if (repository == null || company == null || company!.trim().isEmpty) {
      emit(const ChartOfAccountsState(
        status: ChartStatus.failure,
        message: 'برای دریافت سرفصل‌ها ابتدا یک دفتر فعال انتخاب کنید.',
      ));
      return;
    }
    emit(const ChartOfAccountsState(status: ChartStatus.loading));
    try {
      final accounts = await repository!.getAccounts(company!);
      emit(ChartOfAccountsState(
          status: ChartStatus.success, accounts: _buildTree(accounts)));
    } catch (error) {
      emit(ChartOfAccountsState(
          status: ChartStatus.failure,
          message: 'دریافت سرفصل‌ها از ERPNext ممکن نشد.'));
    }
  }

  List<AccountNode> _buildTree(List<AccountNode> accounts) {
    List<AccountNode> childrenOf(String? parent) => accounts
        .where((item) =>
            item.parentId == parent ||
            (parent == null &&
                (item.parentId == null ||
                    !accounts.any((other) => other.id == item.parentId))))
        .map((item) => AccountNode(
              id: item.id,
              code: item.code,
              title: item.title,
              level: item.level,
              parentId: item.parentId,
              isActive: item.isActive,
              nature: item.nature,
              children: childrenOf(item.id),
            ))
        .toList(growable: false);
    return childrenOf(null);
  }
}
