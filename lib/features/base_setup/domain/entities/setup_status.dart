import 'package:equatable/equatable.dart';

enum SetupStep { office, accounting, roles, complete }

class SetupStatus extends Equatable {
  const SetupStatus({
    this.company,
    this.officeSaved = false,
    this.accountingSaved = false,
    this.rolesSaved = false,
    this.enabledRoles = const [],
  });

  factory SetupStatus.fromJson(Map<String, dynamic> json) => SetupStatus(
        company: json['company']?.toString(),
        officeSaved: json['office_saved'] == true,
        accountingSaved: json['accounting_saved'] == true,
        rolesSaved: json['roles_saved'] == true,
        enabledRoles: ((json['enabled_roles'] as List?) ?? const []).map((value) => value.toString()).toList(),
      );

  final String? company;
  final bool officeSaved;
  final bool accountingSaved;
  final bool rolesSaved;
  final List<String> enabledRoles;

  bool get complete => officeSaved && accountingSaved && rolesSaved;
  SetupStep get nextStep {
    if (!officeSaved) return SetupStep.office;
    if (!accountingSaved) return SetupStep.accounting;
    if (!rolesSaved) return SetupStep.roles;
    return SetupStep.complete;
  }

  @override
  List<Object?> get props => [company, officeSaved, accountingSaved, rolesSaved, enabledRoles];
}
