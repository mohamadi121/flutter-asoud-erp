import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/document_templates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {
  final methods = <String>[];
  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    methods.add(method);
    return const [];
  }
}

void main() {
  testWidgets('home quick action «ایجاد سند» opens the document templates',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _Client();
    await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
        value: client,
        child: MaterialApp(
            theme: AsoudTheme.light,
            home: const Directionality(
                textDirection: TextDirection.rtl,
                child: DashboardPage(officeName: 'شرکت نمونه')))));
    await tester.pumpAndSettle();
    expect(find.text('منابع انسانی'), findsNothing);
    final action = find.text('ایجاد سند');
    // The quick actions grid does not scroll itself; scroll the page.
    await tester.dragUntilVisible(
        action, find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(DocumentTemplatesPage), findsOneWidget);
    expect(client.methods,
        ['asoud_erp.api.v1.document_templates.list_document_templates']);
    expect(find.text('هنوز الگویی ساخته نشده است.'), findsOneWidget);
  });
}
