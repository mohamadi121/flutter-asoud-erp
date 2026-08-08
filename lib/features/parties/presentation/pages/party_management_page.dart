import 'package:flutter/material.dart';

import '../../domain/entities/party_profile.dart';
import 'party_form_page.dart';

/// The management entry is intentionally the complete person form. The role
/// cards at the top decide which ERPNext parties are created by the backend.
class PartyManagementPage extends StatelessWidget {
  const PartyManagementPage({this.company, super.key});

  final String? company;

  @override
  Widget build(BuildContext context) => PartyFormPage(
        company: company,
        initialRole: PartyRole.customer,
        initialKind: PartyKind.individual,
        pageTitle: 'مدیریت اشخاص',
      );
}
