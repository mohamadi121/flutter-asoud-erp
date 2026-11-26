import 'dart:async';

import 'package:flutter/material.dart';

import '../features/calendar/calendar_device_notifications.dart';
import '../features/workflows/data/workflow_card_repository.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/network/frappe_client.dart';
import '../core/auth/personnel_representation.dart';
import '../core/theme/asoud_colors.dart';
import '../features/auth/presentation/pages/post_login_page.dart';
import '../core/config/app_config.dart';
import '../core/network/session_vault.dart';
import '../core/offline/local_database_store.dart';
import '../core/offline/local_record.dart';
import '../features/hr/data/personnel_repository.dart';
import '../core/offline/offline_sync_lifecycle.dart';
import '../core/offline/offline_sync_service.dart';
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
import '../features/auth/data/account_repository.dart';
import '../features/auth/data/saved_credentials_store.dart';
import '../features/auth/data/repositories/frappe_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/parties/data/repositories/frappe_party_repository.dart';
import '../features/parties/data/repositories/server_first_party_repository.dart';
import '../features/parties/domain/repositories/party_repository.dart';
import '../features/workflows/data/generic_request_repository.dart';
import '../features/workflows/data/receipt_confirmation_repository.dart';
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
import '../features/employee/data/preview_hr_repository.dart';
import '../features/hr/data/frappe_hr_repository.dart';
import '../features/hr/data/server_first_hr_repository.dart';
import '../features/hr/domain/hr_repository.dart';

class AsoudErpApp extends StatefulWidget {
  const AsoudErpApp({super.key}) : representation = null, personnelName = null, onExitRepresentation = null, representationNavigator = null;
  const AsoudErpApp._representation(this.representation, this.personnelName,
      this.onExitRepresentation, this.representationNavigator);
  final FrappeClient? representation;
  final String? personnelName;
  final VoidCallback? onExitRepresentation;
  final GlobalKey<NavigatorState>? representationNavigator;

  @override
  State<AsoudErpApp> createState() => _AsoudErpAppState();
}

class _AsoudErpAppState extends State<AsoudErpApp> {
  late final FrappeClient client = widget.representation ?? FrappeClient(
      sessionVault: const SecureSessionVault(),
      serverAddressStore: const SecureServerAddressStore());
  late final OfflineSyncService syncService = OfflineSyncService(client,
      local: localStoreFor(client),
      afterSync: widget.representation == null ? _syncPersonnel : null,
      syncRequests: widget.representation == null ? _syncRequests : null);

  StreamSubscription<bool>? _calendarSession;
  Timer? _representationExpiry;
  bool _representationOpen = false, _exiting = false;
  @override
  void initState() {
    super.initState();
    if (widget.representation != null) {
      _calendarSession = client.authenticationChanges.listen((signedIn) {
        if (!signedIn && !_exiting && mounted) unawaited(_exitRepresentation());
      });
      final expires = client.representationExpiration;
      if (expires != null) {
        _representationExpiry = Timer(expires.difference(DateTime.now()), _exitRepresentation);
      }
      return;
    }
    _calendarSession = client.authenticationChanges.listen((signedIn) {
      if (!signedIn) {
        unawaited(CalendarDeviceNotifications.instance.clear().catchError((Object _) {
          // No notification delivery failure may prevent session revocation.
        }));
      }
    });
  }

  @override
  void dispose() {
    unawaited(_calendarSession?.cancel());
    _representationExpiry?.cancel();
    super.dispose();
  }

  bool get _localPreview =>
      widget.representation == null && AppConfig.offlineDemoMode && !client.isAuthenticated;

  Future<void> _exitRepresentation() async {
    if (_exiting) return;
    setState(() => _exiting = true);
    try {
      if (client.isAuthenticated) {
        await client.logout().timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // The short-lived credential is discarded and never written to disk.
    } finally {
      await client.close();
      if (mounted) widget.onExitRepresentation?.call();
    }
  }

  Future<void> _represent(BuildContext context, String company, String employee, String reason) async {
    if (_representationOpen || widget.representation != null) return;
    setState(() => _representationOpen = true);
    try {
      final target = await client.representPersonnel(company: company, employee: employee, reason: reason);
      if (!context.mounted) {
        try { await target.client.logout(); } finally { await target.client.close(); }
        return;
      }
      final navigator = Navigator.of(context);
      final nested = GlobalKey<NavigatorState>();
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) nested.currentState?.maybePop();
          },
          child: AsoudErpApp._representation(
            target.client, target.personnelName, () => navigator.pop(), nested)),
      ));
    } finally {
      if (mounted) setState(() => _representationOpen = false);
    }
  }

  Future<void> _syncPersonnel() async {
    if (!client.isAuthenticated) return;
    final owner = (await client.getCurrentUser()).userId;
    final pending = await LocalDatabaseStore.instance.list(
        entityType: 'personnel_outbox',
        statuses: {LocalSyncStatus.pendingSync});
    final companies = pending
        .where((r) =>
            r.payload['owner'] == owner &&
            r.payload['server'] == client.serverIdentity)
        .map((r) => r.payload['company'])
        .whereType<String>()
        .toSet();
    for (final company in companies) {
      final repository = PersonnelRepository(client);
      try {
        await repository.synchronize(company);
      } finally {
        repository.dispose();
      }
    }
  }

  /// Sends the offline requests of one company through their own repository so
  /// the shared queue resends them with the same idempotency keys the creation
  /// path uses, never staging a second write for the same request.
  Future<void> _syncRequests(String company, {required bool retry}) async {
    if (!client.isAuthenticated) return;
    final repository = GenericRequestRepository(client, company);
    try {
      await repository.sync(retry: retry);
    } finally {
      repository.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = MultiRepositoryProvider(
        providers: [
          if (widget.representation == null)
            RepositoryProvider.value(value: PersonnelRepresentationLauncher(_represent)),
          RepositoryProvider<FrappeApiClient>.value(value: client),
          RepositoryProvider<OfflineSyncService>.value(value: syncService),
          RepositoryProvider<AuthRepository>.value(
            value: FrappeAuthRepository(client),
          ),
          RepositoryProvider<AccountRepository>.value(
            value: FrappeAccountRepository(client),
          ),
          RepositoryProvider<SavedCredentialsStore>.value(
            value: SavedCredentialsStore(),
          ),
          RepositoryProvider<OfficeRepository>.value(
            value: ServerFirstOfficeRepository(FrappeOfficeRepository(client), local: localStoreFor(client),
                  cacheIdentity: () => [client.serverIdentity, client.localStorageUserId ?? ''],
                localPreview: () => _localPreview),
          ),
          RepositoryProvider<ChartOfAccountsRepository>.value(
            value: ServerFirstChartOfAccountsRepository(
              FrappeChartOfAccountsRepository(client),
              local: localStoreFor(client),
            ),
          ),
          RepositoryProvider<DetailGroupRepository>.value(
            value: ServerFirstDetailGroupRepository(
              FrappeDetailGroupRepository(client),
              local: localStoreFor(client),
              localPreview: () => _localPreview,
            ),
          ),
          RepositoryProvider<BaseSetupRepository>.value(
            value: ServerFirstBaseSetupRepository(
              FrappeBaseSetupRepository(client),
              local: localStoreFor(client),
            ),
          ),
          RepositoryProvider<PartyRepository>.value(
            value: ServerFirstPartyRepository(FrappePartyRepository(client),
                local: localStoreFor(client),
                localPreview: () => _localPreview),
          ),
          RepositoryProvider<WorkflowRepository>.value(
            value: PreviewFallbackWorkflowRepository(
              FrappeWorkflowRepository(client),
            ),
          ),
          RepositoryProvider<WorkflowCardRepository>.value(value: WorkflowCardRepository(client)),
          RepositoryProvider<WorkflowTaskRepository>.value(
            value: PreviewWorkflowTaskRepository(
              FrappeWorkflowTaskRepository(client),
            ),
          ),
          RepositoryProvider<ReceiptConfirmationRepository>.value(
            value: FrappeReceiptConfirmationRepository(client),
          ),
          RepositoryProvider<WorkflowNotificationRepository>.value(
            value: PreviewWorkflowNotificationRepository(
              FrappeWorkflowNotificationRepository(client),
            ),
          ),
          RepositoryProvider<PurchaseRequestRepository>.value(
            value: FrappePurchaseRequestRepository(client),
          ),
          RepositoryProvider<HrRepository>.value(
            value: PreviewHrRepository(
              ServerFirstHrRepository(FrappeHrRepository(client), local: localStoreFor(client)),
              isPreview: () => _localPreview,
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: widget.representationNavigator,
          debugShowCheckedModeBanner: false,
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AsoudTheme.light,
          builder: widget.representation == null ? null : (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: Column(children: [
              Material(color: const Color(0xFFE8F0FE), child: SafeArea(bottom: false,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Expanded(child: Text('نمایندگی: ${widget.personnelName}', maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AsoudColors.text, fontSize: 12))),
                    TextButton(onPressed: _exiting ? null : _exitRepresentation,
                      child: const Text('خروج و بازگشت به مدیر')),
                  ])))),
              Expanded(child: _exiting ? const Material(
                child: Center(child: CircularProgressIndicator())) : child!),
            ])),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: widget.representation == null ? const SplashPage() : PostLoginPage(officeToResume: client.lastEnteredOffice),
          ),
        ),
      );
    if (widget.representation != null) return providers;
    return OfflineSyncLifecycle(service: syncService, enabled: !_representationOpen, child: providers);
  }
}
