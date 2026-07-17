import 'package:flutter/material.dart';

import '../../domain/entities/office.dart';
import 'office_form_page.dart';

/// Kept as the existing route entry-point; type selection now lives in the form.
class OfficeTypePage extends StatelessWidget {
  const OfficeTypePage({super.key});
  @override
  Widget build(BuildContext context) =>
      const OfficeFormPage(officeType: OfficeType.personal);
}
