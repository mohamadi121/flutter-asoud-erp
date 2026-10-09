import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/employee/data/self_service_repository.dart';
import 'package:asoud_erp/features/employee/presentation/pages/employee_home_page.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/features/request_templates/request_templates.dart';
import 'package:asoud_erp/features/workflows/data/request_demo_source.dart';
import 'package:asoud_erp/features/workflows/presentation/request_screen_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

class _Files extends Fake implements PersonnelFileRepository {
  @override
  Future<EmployeeHome> myHome() async => EmployeeHome.fromJson({
        'profile_id': 'PARTY-1',
        'employee': 'HR-EMP-00042',
        'name': 'امیر موفق',
        'designation': 'کارشناس فروش',
        'department_name': 'فروش',
        'company': 'Tabaan',
        'date': '2026-09-25',
        'counts': {
          'open_requests': 0,
          'open_tasks': 0,
          'unread_notifications': 0,
          'pending_leave_applications': 0,
          'leave_remaining': 8,
        },
        'announcements': [],
      });

  @override
  Future<List<Announcement>> announcements() async => [];
}

class _SelfService extends Fake implements SelfServiceRepository {}

Future<void> _openHome(WidgetTester tester, FrappeApiClient client) async {
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(wrapPage(
      Scaffold(
          body: EmployeeHomePage(
              company: 'Tabaan', files: _Files(), selfService: _SelfService())),
      client: client));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RequestScreenRegistry.clear();
    RequestDemoRegistry.clear();
    registerRequestTemplates();
  });
  tearDown(() {
    RequestScreenRegistry.clear();
    RequestDemoRegistry.clear();
  });

  testWidgets('the home shows the three request quick actions', (tester) async {
    await _openHome(tester, previewClient());
    for (final label in ['مرخصی', 'درخواست خرید', 'تأمین کالا / خدمات']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  // The pages build their own repository from the signed-in client (its
  // durable store is the device database, absent in widget tests), so only
  // the page and its title are checked here; the rows are covered by the
  // list and preview tests with an injected repository.
  for (final entry in <String, (String, Type)>{
    'مرخصی': ('درخواست‌های مرخصی', LeaveRequestsListPage),
    'درخواست خرید': ('درخواست‌های خرید', PurchaseRequestsListPage),
    'تأمین کالا / خدمات': (
      'درخواست‌های تأمین کالا / خدمات',
      SupplyRequestsListPage
    ),
  }.entries) {
    testWidgets('«${entry.key}» opens ${entry.value.$1}', (tester) async {
      await _openHome(tester, previewClient());
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.byType(entry.value.$2), findsOneWidget);
      expect(find.text(entry.value.$1), findsOneWidget);
    });
  }
}
