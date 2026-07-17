part of 'chart_of_accounts_cubit.dart';

enum ChartStatus { initial, loading, success, failure }

class ChartOfAccountsState extends Equatable {
  const ChartOfAccountsState(
      {this.status = ChartStatus.initial,
      this.accounts = const [],
      this.message});
  final ChartStatus status;
  final List<AccountNode> accounts;
  final String? message;
  @override
  List<Object?> get props => [status, accounts, message];
}
