import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/asoud_theme.dart';
import '../features/office_setup/presentation/pages/office_type_page.dart';

class AsoudErpApp extends StatelessWidget {
  const AsoudErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AsoudTheme.light,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: OfficeTypePage(),
      ),
    );
  }
}

