import 'package:equatable/equatable.dart';

class DetailGroup extends Equatable {
  const DetailGroup({
    required this.id,
    required this.code,
    required this.title,
    this.disabled = false,
    this.partyRole,
    this.parentGroup,
    this.iconKey,
    this.colorHex,
  });

  final String id;
  final String code;
  final String title;
  final bool disabled;
  final String? partyRole;
  final String? parentGroup, iconKey, colorHex;

  @override
  List<Object?> get props => [
        id,
        code,
        title,
        disabled,
        partyRole,
        parentGroup,
        iconKey,
        colorHex,
      ];
}
