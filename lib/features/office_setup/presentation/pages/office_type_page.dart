import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/entities/office.dart';
import 'office_form_page.dart';

/// Kept as the existing route entry-point; type selection now lives in the form.
class OfficeTypePage extends StatelessWidget {
  const OfficeTypePage({
    this.allowOfflinePreview = AppConfig.offlineDemoMode,
    super.key,
  });
  final bool allowOfflinePreview;
  @override
  Widget build(BuildContext context) => OfficeFormPage(
        officeType: OfficeType.personal,
        allowOfflinePreview: allowOfflinePreview,
      );
}
