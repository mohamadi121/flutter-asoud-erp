import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/new_request_catalog.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/new_request_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final vazirmatn = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([vazirmatn.load(), icons.load()]);
  });

  testWidgets('new request sheet 360x800 golden', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final types = [
      for (final item in purchaseRequestBank)
        {
          'workflow_title': item.title,
          'short_title': item.description,
          'icon_key': 'purchase',
        },
    ];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: Center(
                  child: FilledButton(
                      onPressed: () => showNewRequestSheet(context,
                          loadTypes: () async => types),
                      child: const Text('باز کردن'))))),
    ));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-request-module-خرید')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/new_request_sheet_360x800.png'));
  });
}
