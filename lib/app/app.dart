import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/network/frappe_client.dart';
import '../core/theme/asoud_theme.dart';
import '../features/office_setup/data/repositories/frappe_office_repository.dart';
import '../features/office_setup/data/repositories/server_first_office_repository.dart';
import '../features/office_setup/domain/repositories/office_repository.dart';
import '../features/accounting/data/repositories/frappe_chart_of_accounts_repository.dart';
import '../features/accounting/data/repositories/server_first_chart_of_accounts_repository.dart';
import '../features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import '../features/accounting/data/repositories/frappe_detail_group_repository.dart';
import '../features/accounting/data/repositories/server_first_detail_group_repository.dart';
import '../features/accounting/domain/repositories/detail_group_repository.dart';
import '../features/base_setup/data/repositories/frappe_base_setup_repository.dart';
import '../features/base_setup/data/repositories/server_first_base_setup_repository.dart';
import '../features/base_setup/domain/repositories/base_setup_repository.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/data/repositories/frappe_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/parties/data/repositories/frappe_party_repository.dart';
import '../features/parties/data/repositories/server_first_party_repository.dart';
import '../features/parties/domain/repositories/party_repository.dart';
import '../features/workflows/data/repositories/frappe_workflow_repository.dart';
import '../features/workflows/data/repositories/preview_fallback_workflow_repository.dart';
import '../features/workflows/domain/repositories/workflow_repository.dart';
import '../features/workflows/data/repositories/frappe_workflow_task_repository.dart';
import '../features/workflows/data/repositories/preview_workflow_task_repository.dart';
import '../features/workflows/domain/repositories/workflow_task_repository.dart';
import '../features/workflows/data/repositories/frappe_workflow_notification_repository.dart';
import '../features/workflows/data/repositories/preview_workflow_notification_repository.dart';
import '../features/workflows/domain/repositories/workflow_notification_repository.dart';
import '../features/purchase/data/frappe_purchase_request_repository.dart';
import '../features/purchase/domain/purchase_request_repository.dart';

class AsoudErpApp extends StatelessWidget {
  const AsoudErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = FrappeClient();
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: client),
        RepositoryProvider<AuthRepository>.value(
          value: FrappeAuthRepository(client),
        ),
        RepositoryProvider<OfficeRepository>.value(
          value: ServerFirstOfficeRepository(FrappeOfficeRepository(client)),
        ),
        RepositoryProvider<ChartOfAccountsRepository>.value(
          value: ServerFirstChartOfAccountsRepository(
            FrappeChartOfAccountsRepository(client),
          ),
        ),
        RepositoryProvider<DetailGroupRepository>.value(
          value: ServerFirstDetailGroupRepository(
            FrappeDetailGroupRepository(client),
          ),
        ),
        RepositoryProvider<BaseSetupRepository>.value(
          value: ServerFirstBaseSetupRepository(
            FrappeBaseSetupRepository(client),
          ),
        ),
        RepositoryProvider<PartyRepository>.value(
          value: ServerFirstPartyRepository(FrappePartyRepository(client)),
        ),
        RepositoryProvider<WorkflowRepository>.value(
          value: PreviewFallbackWorkflowRepository(
            FrappeWorkflowRepository(client),
          ),
        ),
        RepositoryProvider<WorkflowTaskRepository>.value(
          value: PreviewWorkflowTaskRepository(
            FrappeWorkflowTaskRepository(client),
          ),
        ),
        RepositoryProvider<WorkflowNotificationRepository>.value(
          value: PreviewWorkflowNotificationRepository(
            FrappeWorkflowNotificationRepository(client),
          ),
        ),
        RepositoryProvider<PurchaseRequestRepository>.value(
          value: FrappePurchaseRequestRepository(client),
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
          child: SplashPage(),
        ),
      ),
    );
  }
}
