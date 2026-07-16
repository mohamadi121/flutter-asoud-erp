import 'package:equatable/equatable.dart';

enum AccountLevel { group, general, ledger, detail }

enum AccountNature { debit, credit, both }

class AccountNode extends Equatable {
  const AccountNode({
    required this.id,
    required this.code,
    required this.title,
    required this.level,
    this.parentId,
    this.isActive = true,
    this.nature = AccountNature.debit,
    this.children = const [],
  });

  final String id;
  final String code;
  final String title;
  final AccountLevel level;
  final String? parentId;
  final bool isActive;
  final AccountNature nature;
  final List<AccountNode> children;

  @override
  List<Object?> get props => [id, code, title, level, parentId, isActive, nature, children];
}
