import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/network/session_vault.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_failure.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/domain/repositories/auth_repository.dart';
import 'package:asoud_erp/features/auth/presentation/pages/login_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/sync_queue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_local_record_store.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockAddressStore extends Mock implements ServerAddressStore {}

void main() {
  group('T3 regressions', () {
    test(
        'persianSyncErrorMessage maps failure kinds to Persian sentences without raw Dart text',
        () {
      const validationError = 'ApiException(ApiFailureKind.validation, 417)';
      final validationMsg = persianSyncErrorMessage(validationError);
      expect(validationMsg, 'اطلاعات ارسال‌شده معتبر نیست و باید اصلاح شود.');
      expect(validationMsg, isNot(contains('ApiException')));
      expect(validationMsg, isNot(contains('417')));

      const forbiddenError = 'ApiException(ApiFailureKind.forbidden, 403)';
      final forbiddenMsg = persianSyncErrorMessage(forbiddenError);
      expect(forbiddenMsg, 'دسترسی لازم برای انجام این عملیات وجود ندارد.');
      expect(forbiddenMsg, isNot(contains('ApiException')));
      expect(forbiddenMsg, isNot(contains('403')));

      const networkError = 'ApiException(ApiFailureKind.network, null)';
      final networkMsg = persianSyncErrorMessage(networkError);
      expect(
          networkMsg, 'ارتباط با سرور برقرار نشد؛ اتصال شبکه را بررسی کنید.');
      expect(networkMsg, isNot(contains('ApiException')));

      const serverError = 'ApiException(ApiFailureKind.server, 500)';
      final serverMsg = persianSyncErrorMessage(serverError);
      expect(serverMsg,
          'سرور در حال حاضر قادر به پاسخ‌گویی نیست؛ لطفاً بعداً تلاش کنید.');
      expect(serverMsg, isNot(contains('ApiException')));
      expect(serverMsg, isNot(contains('500')));
    });

    testWidgets(
        'Sync queue item displays Persian sentence for raw ApiException validation 417',
        (tester) async {
      final record = LocalRecord(
        id: 'MUT-1',
        entityType: 'workflow_request',
        payload: const {
          'operation': 'create',
          'request_type': 'مرخصی',
        },
        status: LocalSyncStatus.syncFailed,
        attempts: 2,
        createdAt: DateTime(2026, 10, 9, 12, 0),
        updatedAt: DateTime(2026, 10, 9, 12, 0),
        lastError: 'ApiException(ApiFailureKind.validation, 417)',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: SyncQueueItemCard(
                row: record,
                enabled: true,
                onRetry: () {},
                onDiscard: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ApiException'), findsNothing);
      expect(find.textContaining('417'), findsNothing);
      expect(
        find.text('ناموفق: اطلاعات ارسال‌شده معتبر نیست و باید اصلاح شود.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'LoginPage retains last server address and keeps credentials empty',
        (tester) async {
      const liveServer = 'http://91.108.140.180:8080';
      final store = _MockAddressStore();
      when(() => store.read()).thenAnswer((_) async => liveServer);

      final client = FrappeClient(
        baseUrl: liveServer,
        serverAddressStore: store,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: RepositoryProvider<FrappeApiClient>.value(
            value: client,
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: LoginPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Server URL field must be the live server, not localhost:8000
      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].controller?.text, liveServer);
      expect(fields[1].controller?.text, isEmpty);
      expect(fields[2].controller?.text, isEmpty);
    });

    testWidgets('Logout keeps last server address when navigating to LoginPage',
        (tester) async {
      const liveServer = 'http://91.108.140.180:8080';
      final client = FrappeClient(baseUrl: liveServer);
      final authRepo = _MockAuthRepo();
      when(() => authRepo.signOut()).thenAnswer((_) async {});

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<FrappeApiClient>.value(value: client),
            RepositoryProvider<AuthRepository>.value(value: authRepo),
          ],
          child: MaterialApp(
            theme: AsoudTheme.light,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: SettingsDashboardContent(
                company: 'شرکت نمونه آسود',
                offlinePreview: false,
                offlineStore: FakeLocalRecordStore(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to logout button
      await tester.dragUntilVisible(
        find.text('خروج از حساب'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('خروج از حساب'));
      await tester.pumpAndSettle();

      // Confirm dialog
      final confirmButton = find.text('خروج');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Now on LoginPage: verify server address is liveServer, not localhost:8000
      final fieldsAfterLogout =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fieldsAfterLogout[0].controller?.text, liveServer);
      expect(fieldsAfterLogout[1].controller?.text, isEmpty);
      expect(fieldsAfterLogout[2].controller?.text, isEmpty);
    });
  });
}
