import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_form_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Workflows extends Fake implements WorkflowRepository {}

class _SettingsClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'admin@asoud-demo.local',
        fullName: 'مدیر سیستم',
        roles: ['System Manager', 'Accounts Manager', 'HR Manager', 'Employee'],
      );
}

void main() {
  testWidgets('settings workflow action reaches the workflow list and create form',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
        value: _SettingsClient(),
        child: RepositoryProvider<WorkflowRepository>.value(
            value: _Workflows(),
            child: MaterialApp(
                theme: AsoudTheme.light,
                home: const Directionality(
                    textDirection: TextDirection.rtl,
                    child: DashboardPage(
                        officeName: 'دفتر نمونه', offlinePreview: true))))));
    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();
    expect(find.text('اشخاص و شرکت‌ها'), findsNothing);
    final action = find.text('گردش کار');
    for (var i = 0; i < 12 && action.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pumpAndSettle();
    }
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowListPage), findsOneWidget);
    await tester.tap(find.text('ایجاد گردش‌کار جدید'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowFormPage), findsOneWidget);
  });
}