import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/workflow_automation_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/document_templates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  testWidgets('preview templates page renders the three demos at 390',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: DocumentTemplatesPage(
          company: 'شرکت نمونه آسود',
          repository: WorkflowAutomationRepository(client),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('سند هزینه خرید'), findsOneWidget);
    expect(find.text('پرداخت به تأمین‌کننده'), findsOneWidget);
    expect(find.text('سند هزینه عمومی'), findsOneWidget);
    expect(find.text('هنوز الگویی ساخته نشده است.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
