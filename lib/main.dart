import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/request_templates/request_templates.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerRequestTemplates();
  runApp(const AsoudErpApp());
}
