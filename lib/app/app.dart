import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/network/frappe_client.dart';
import '../core/theme/asoud_theme.dart';
import '../features/office_setup/data/repositories/frappe_office_repository.dart';
import '../features/office_setup/domain/repositories/office_repository.dart';
import '../features/office_setup/presentation/pages/office_type_page.dart';
import '../features/accounting/data/repositories/frappe_chart_of_accounts_repository.dart';
import '../features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import '../features/accounting/data/repositories/frappe_detail_group_repository.dart';
import '../features/accounting/domain/repositories/detail_group_repository.dart';
import '../features/base_setup/data/repositories/frappe_base_setup_repository.dart';
import '../features/base_setup/domain/repositories/base_setup_repository.dart';

class AsoudErpApp extends StatelessWidget {
  const AsoudErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = FrappeClient();
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<OfficeRepository>.value(
          value: FrappeOfficeRepository(client),
        ),
        RepositoryProvider<ChartOfAccountsRepository>.value(
          value: FrappeChartOfAccountsRepository(client),
        ),
        RepositoryProvider<DetailGroupRepository>.value(
          value: FrappeDetailGroupRepository(client),
        ),
        RepositoryProvider<BaseSetupRepository>.value(
          value: FrappeBaseSetupRepository(client),
        ),
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
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: OfficeTypePage(),
        ),
      ),
    );
  }
}
