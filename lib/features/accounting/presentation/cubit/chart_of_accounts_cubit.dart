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
    emit(ChartOfAccountsState(
        status: ChartStatus.loading, accounts: state.accounts));
    try {
      final accounts = await repository!.getAccounts(company!);
      emit(ChartOfAccountsState(
          status: ChartStatus.success, accounts: _buildTree(accounts)));
    } catch (error) {
      emit(ChartOfAccountsState(
          status: ChartStatus.failure,
          message: 'دریافت سرفصل‌ها از ASOUD ERP ممکن نشد.'));
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
              accountType: item.accountType,
              detailGroupIds: item.detailGroupIds,
              children: childrenOf(item.id),
            ))
        .toList(growable: false)
      ..sort((a, b) => compareAccountCodes(a.code, b.code));
    return childrenOf(null);
  }
}

int compareAccountCodes(String first, String second) {
  String normalize(String value) => value.trim().split('').map((char) {
        final persian = '۰۱۲۳۴۵۶۷۸۹'.indexOf(char);
        final arabic = '٠١٢٣٤٥٦٧٨٩'.indexOf(char);
        return persian >= 0
            ? '$persian'
            : arabic >= 0
                ? '$arabic'
                : char;
      }).join();
  final a = normalize(first), b = normalize(second);
  final an = BigInt.tryParse(a), bn = BigInt.tryParse(b);
  if (an != null && bn != null) {
    final comparison = an.compareTo(bn);
    if (comparison != 0) return comparison;
  }
  return a.compareTo(b);
}
