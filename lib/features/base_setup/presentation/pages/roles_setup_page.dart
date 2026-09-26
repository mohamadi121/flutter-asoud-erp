import 'package:flutter/material.dart';
import '../../../roles/presentation/roles_page.dart';

/// Preserve existing setup routes while using the real role manager.
class RolesSetupPage extends StatelessWidget {
  const RolesSetupPage(
      {this.officeName, this.offlinePreview = false, super.key});

  final String? officeName;
  final bool offlinePreview;

  @override
  Widget build(BuildContext context) => const RolesPage();
}
