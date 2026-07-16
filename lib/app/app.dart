import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/asoud_theme.dart';
import '../core/network/frappe_client.dart';
import '../features/base_setup/data/repositories/frappe_setup_repository.dart';
import '../features/base_setup/domain/repositories/setup_repository.dart';
import '../features/office_setup/data/repositories/frappe_office_repository.dart';
import '../features/office_setup/domain/repositories/office_repository.dart';
import 'startup_gate.dart';

class AsoudErpApp extends StatelessWidget {
  const AsoudErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = FrappeClient();
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<OfficeRepository>(create: (_) => FrappeOfficeRepository(client)),
        RepositoryProvider<SetupRepository>(create: (_) => FrappeSetupRepository(client)),
      ],
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
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const StartupGate(),
      ),
    );
  }
}

