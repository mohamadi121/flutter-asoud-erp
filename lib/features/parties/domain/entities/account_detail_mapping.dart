import 'package:equatable/equatable.dart';

class AccountDetailMapping extends Equatable {
  const AccountDetailMapping({required this.accountId, required this.groupCode});
  final String accountId;
  final String groupCode;

  @override
  List<Object?> get props => [accountId, groupCode];
}
