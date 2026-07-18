part of 'account_form_cubit.dart';

enum AccountFormMode { create, edit }

enum AccountFormStatus { editing, invalid, saving, success, failure }

class AccountFormState extends Equatable {
  const AccountFormState({
    required this.mode,
    this.originalId,
    this.code = '',
    this.title = '',
    this.level = AccountLevel.ledger,
    this.parentId,
    this.nature = AccountNature.debit,
    this.isActive = true,
    this.autoCode = true,
    this.status = AccountFormStatus.editing,
    this.message,
    this.savedAccount,
  });

  final AccountFormMode mode;
  final String? originalId;
  final String code;
  final String title;
  final AccountLevel level;
  final String? parentId;
  final AccountNature nature;
  final bool isActive;
  final bool autoCode;
  final AccountFormStatus status;
  final String? message;
  final AccountNode? savedAccount;

  bool get requiresParent => level != AccountLevel.group;
  bool get isValid =>
      title.trim().length >= 3 &&
      (autoCode || code.trim().isNotEmpty) &&
      (!requiresParent || (parentId?.isNotEmpty ?? false));

  AccountNode toEntity() => AccountNode(
        id: originalId ?? '',
        code: autoCode ? '' : code.trim(),
        title: title.trim(),
        level: level,
        parentId: parentId,
        nature: nature,
        isActive: isActive,
      );

  AccountFormState copyWith({
    String? code,
    String? title,
    AccountLevel? level,
    String? parentId,
    bool clearParent = false,
    AccountNature? nature,
    bool? isActive,
    bool? autoCode,
    AccountFormStatus? status,
    String? message,
    bool clearMessage = false,
    AccountNode? savedAccount,
  }) =>
      AccountFormState(
        mode: mode,
        originalId: originalId,
        code: code ?? this.code,
        title: title ?? this.title,
        level: level ?? this.level,
        parentId: clearParent ? null : parentId ?? this.parentId,
        nature: nature ?? this.nature,
        isActive: isActive ?? this.isActive,
        autoCode: autoCode ?? this.autoCode,
        status: status ?? AccountFormStatus.editing,
        message: clearMessage ? null : message ?? this.message,
        savedAccount: savedAccount ?? this.savedAccount,
      );

  @override
  List<Object?> get props => [
        mode,
        originalId,
        code,
        title,
        level,
        parentId,
        nature,
        isActive,
        autoCode,
        status,
        message,
        savedAccount,
      ];
}
