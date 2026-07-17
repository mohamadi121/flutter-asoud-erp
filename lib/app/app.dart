import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/network/frappe_client.dart';
import '../core/theme/asoud_theme.dart';
import '../features/office_setup/data/repositories/frappe_office_repository.dart';
import '../features/office_setup/domain/repositories/office_repository.dart';
import '../features/office_setup/presentation/pages/office_type_page.dart';

class AsoudErpApp extends StatelessWidget {
  const AsoudErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FrappeOfficeRepository(FrappeClient());
    return RepositoryProvider<OfficeRepository>.value(
      value: repository,
      child: MaterialApp(
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
      ),
    );
  }
}
