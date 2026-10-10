import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            body: SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.all(16), child: child))),
      ),
    ));
  }

  group('AppTextField', () {
    for (final width in [320.0, 390.0]) {
      testWidgets(
          'shows a floating label with the required mark and a separate hint '
          '(${width.toInt()}px)', (tester) async {
        await pumpAt(
          tester,
          width,
          AppTextField(label: 'نام', required: true, hint: 'مثال: حسابدار'),
        );
        expect(find.text('نام *'), findsOneWidget);
        expect(find.text('مثال: حسابدار'), findsOneWidget);
        final hintWidget = tester.widget<Text>(find.text('مثال: حسابدار'));
        expect(hintWidget.data, isNot(contains('*')));
        expect(tester.takeException(), isNull);
      });

      testWidgets('helper and error text are 12sp (${width.toInt()}px)',
          (tester) async {
        await pumpAt(
            tester, width, AppTextField(label: 'راهنما', helperText: 'راهنما'));
        final helper = tester.widget<Text>(find.text('راهنما').last);
        expect(helper.style?.fontSize, 12);

        await pumpAt(
            tester, width, AppTextField(label: 'خطا', errorText: 'خطا'));
        final error = tester.widget<Text>(find.text('خطا').last);
        expect(error.style?.fontSize, 12);
      });

      testWidgets('the field is at least 48dp tall (${width.toInt()}px)',
          (tester) async {
        await pumpAt(tester, width, AppTextField(label: 'نام'));
        expect(tester.getSize(find.byType(AppTextField)).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });

      testWidgets('ltr renders emails and urls left-to-right '
          '(${width.toInt()}px)', (tester) async {
        await pumpAt(tester, width, AppTextField(label: 'ایمیل', ltr: true));
        expect(
            tester
                .widget<TextField>(find.byType(TextField).first)
                .textDirection,
            TextDirection.ltr);
      });
    }

    testWidgets('a validator error appears after Form.validate()', (tester) async {
      final formKey = GlobalKey<FormState>();
      await pumpAt(
        tester,
        390,
        Form(
          key: formKey,
          child: Column(children: [
            AppTextField(
                label: 'نام',
                required: true,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'نام الزامی است.' : null),
            FilledButton(
                onPressed: () => formKey.currentState!.validate(),
                child: const Text('ثبت')),
          ]),
        ),
      );
      await tester.tap(find.text('ثبت'));
      await tester.pumpAndSettle();
      expect(find.text('نام الزامی است.'), findsOneWidget);
    });
  });

  group('AppSelectField', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('shows the value with a trailing ⌄ arrow (${width.toInt()}px)',
          (tester) async {
        await pumpAt(
            tester,
            width,
            AppSelectField(
                label: 'استان', value: 'تهران', displayValue: 'تهران'));
        expect(find.text('تهران'), findsOneWidget);
        expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      });

      testWidgets('the required mark is not doubled (${width.toInt()}px)',
          (tester) async {
        await pumpAt(tester, width,
            AppSelectField(label: 'نوع مرخصی *', required: true));
        expect(find.text('نوع مرخصی *'), findsOneWidget);
        expect(find.text('نوع مرخصی * *'), findsNothing);
      });

      testWidgets('shows the external error and stays 48dp tall '
          '(${width.toInt()}px)', (tester) async {
        await pumpAt(
            tester,
            width,
            AppSelectField(
                label: 'استان', errorText: 'انتخاب استان الزامی است.'));
        expect(find.text('انتخاب استان الزامی است.'), findsOneWidget);
        expect(
            tester.getSize(find.byType(AppSelectField)).height,
            greaterThanOrEqualTo(48));
      });
    }

    testWidgets('tapping runs the passed picker and commits its answer',
        (tester) async {
      final picked = <String>[];
      String selected = '';
      await pumpAt(
        tester,
        390,
        StatefulBuilder(
          builder: (context, setState) => AppSelectField(
            label: 'استان',
            value: selected,
            onPick: () => showAppOptionSheet(context,
                title: 'استان', options: const [AppOption('تهران', 'تهران')]),
            onChanged: (v) {
              picked.add(v);
              setState(() => selected = v);
            },
          ),
        ),
      );
      expect(find.text('استان *'), findsNothing);
      await tester.tap(find.byType(AppSelectField));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('تهران'), findsWidgets);
      await tester.tap(find.text('تهران').last);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(picked, ['تهران']);
      expect(find.text('تهران'), findsOneWidget);
    });

    testWidgets('a validator error appears after Form.validate()', (tester) async {
      final formKey = GlobalKey<FormState>();
      await pumpAt(
        tester,
        390,
        Form(
          key: formKey,
          child: Column(children: [
            AppSelectField(
                label: 'استان',
                required: true,
                validator: (v) =>
                    (v ?? '').isEmpty ? 'دسته را انتخاب کنید.' : null),
            FilledButton(
                onPressed: () => formKey.currentState!.validate(),
                child: const Text('ثبت')),
          ]),
        ),
      );
      await tester.tap(find.text('ثبت'));
      await tester.pumpAndSettle();
      expect(find.text('دسته را انتخاب کنید.'), findsOneWidget);
    });
  });

  group('AppSwitchTile', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('writes the state «خاموش»/«روشن» next to the switch '
          '(${width.toInt()}px)', (tester) async {
        await pumpAt(tester, width,
            AppSwitchTile(title: 'فعال', value: false, onChanged: (_) {}));
        expect(find.text('خاموش'), findsOneWidget);
        await tester.tap(find.byType(AppSwitchTile));
        await pumpAt(
            tester, width, AppSwitchTile(title: 'فعال', value: true, onChanged: (_) {}));
        expect(find.text('روشن'), findsOneWidget);
      });

      testWidgets('the row is at least 48dp tall (${width.toInt()}px)',
          (tester) async {
        await pumpAt(tester, width,
            AppSwitchTile(title: 'فعال', value: false, onChanged: (_) {}));
        expect(
            tester.getSize(find.byType(AppSwitchTile)).height,
            greaterThanOrEqualTo(48));
      });

      testWidgets('a disabled tile has no switch handler (${width.toInt()}px)',
          (tester) async {
        await pumpAt(tester, width,
            AppSwitchTile(title: 'فعال', value: true, enabled: false));
        expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      });
    }

    testWidgets('tapping flips the value and the visible state word',
        (tester) async {
      bool on = false;
      final changes = <bool>[];
      final widget = StatefulBuilder(
          builder: (context, setState) => AppSwitchTile(
                title: 'فعال',
                value: on,
                onChanged: (v) => setState(() {
                  changes.add(v);
                  on = v;
                }),
              ));
      await pumpAt(tester, 390, widget);
      expect(find.text('خاموش'), findsOneWidget);
      await tester.tap(find.byType(AppSwitchTile));
      await tester.pumpAndSettle();
      expect(changes, [true]);
      expect(find.text('روشن'), findsOneWidget);
      expect(tester.getSize(find.byType(Switch)).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('a colored dot/state word is not the only signal: text exists',
        (tester) async {
      await pumpAt(
          tester, 390, AppSwitchTile(title: 'فعال', value: false, onChanged: (_) {}));
      final stateText = tester.widget<Text>(
          find.byKey(const ValueKey('app-switch-state')));
      expect(stateText.data, 'خاموش');
      expect(stateText.style?.color, AsoudColors.muted);
    });
  });
}