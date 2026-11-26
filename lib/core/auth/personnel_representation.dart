import 'package:flutter/widgets.dart';

class PersonnelRepresentationLauncher {
  const PersonnelRepresentationLauncher(this.open);
  final Future<void> Function(BuildContext context, String company, String employee, String reason) open;
}
