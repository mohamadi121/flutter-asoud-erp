import 'package:equatable/equatable.dart';

class AuthenticatedUser extends Equatable {
  const AuthenticatedUser({
    required this.id,
    required this.fullName,
    required this.roles,
    this.employeeId,
    this.employeeName,
    this.company,
  });

  final String id;
  final String fullName;
  final Set<String> roles;
  final String? employeeId;
  final String? employeeName;
  final String? company;

  bool can(String role) => roles.contains(role);

  @override
  List<Object?> get props =>
      [id, fullName, roles, employeeId, employeeName, company];
}
