import 'package:equatable/equatable.dart';

enum PartyType { individual, organization }

enum PartyRole { customer, supplier, employee, shareholder, other }

class PartyProfile extends Equatable {
  const PartyProfile({
    required this.id,
    required this.type,
    required this.displayName,
    this.nationalId = '',
    this.mobile = '',
    this.email = '',
    this.roles = const {},
  });

  final String id;
  final PartyType type;
  final String displayName;
  final String nationalId;
  final String mobile;
  final String email;
  final Set<PartyRole> roles;

  @override
  List<Object?> get props => [id, type, displayName, nationalId, mobile, email, roles];
}
