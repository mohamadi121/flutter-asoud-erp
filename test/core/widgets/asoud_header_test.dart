import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/asoud_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page whose app bar is an [AsoudHeader]; pushed so the back button shows.
class _HeaderPage extends StatelessWidget {
  const _HeaderPage({this.subtitle, this.subtitleWidget});
  final String? subtitle;
  final Widget? subtitleWidget;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AsoudHeader(
            title: 'عنوان صفحه',
            subtitle: subtitle,
            subtitleWidget: subtitleWidget),
        body: const SizedBox.shrink(),
      );
}

Future<void> _open(WidgetTester tester, double width, _HeaderPage page) async {
  tester.view.physicalSize = Size(width, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => page)),
                child: const Text('open')),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('دکمهٔ بازگشت هدر ۴۸×۴۸ است', (tester) async {
    await _open(tester, 390, const _HeaderPage());
    // The tap target is the InkWell wrapping the icon, not the icon itself.
    final target = find.ancestor(
        of: find.byIcon(Icons.chevron_right_rounded),
        matching: find.byType(InkWell));
    expect(target, findsOneWidget);
    final size = tester.getSize(target);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('زیرعنوان هدر ۱۲ پیکسلی است (نه ۱۰)', (tester) async {
    await _open(tester, 390, const _HeaderPage(subtitle: 'زیرعنوان'));
    final subtitle = find.text('زیرعنوان');
    expect(subtitle, findsOneWidget);
    expect(tester.widget<Text>(subtitle).style?.fontSize, 12);
  });

  testWidgets('هدر با چیپ شناسهٔ LTR در عرض ۳۲۰ بدون سرریز', (tester) async {
    await _open(tester, 320,
        const _HeaderPage(subtitleWidget: AsoudIdChip('WFI-2026-00042')));
    expect(find.text('WFI-2026-00042'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AsoudIdChip متن را LTR و با رنگ ثانویه نشان می‌دهد',
      (tester) async {
    await _open(tester, 390,
        const _HeaderPage(subtitleWidget: AsoudIdChip('REQ-00008')));
    final chip = find.text('REQ-00008');
    expect(chip, findsOneWidget);
    final text = tester.widget<Text>(chip);
    expect(text.textDirection, TextDirection.ltr);
    expect(text.style?.fontSize, 11);
    expect(text.style?.color, AsoudColors.muted);
  });
}
