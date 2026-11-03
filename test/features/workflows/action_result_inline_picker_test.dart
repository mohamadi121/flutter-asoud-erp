import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/action_result_form_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {}

class _Forms extends FormRepository {
  _Forms() : super(_Client(), 'company');
  final calls = <String>[];
  bool disabled = false;

  @override
  Future<List<FormMap>> list(String kind, {bool manage = true}) async =>
      kind == 'Request'
          ? [
              {
                'name': 'existing',
                'title': 'گزارش نتیجه موجود',
                'status': 'Published',
                'active_revision': 'rev-1'
              },
              {
                'name': 'draft',
                'title': 'پیش‌نویس منتشرنشده',
                'status': 'Draft'
              }
            ]
          : [];

  @override
  Future<dynamic> call(String method, [FormMap data = const {}]) async {
    calls.add(method);
    expect(method, 'get_form');
    expect(data['revision_name'], 'rev-1');
    return {
      'name': 'existing',
      'revision': 'rev-1',
      'active_revision': 'rev-1',
      'disabled': disabled,
      'schema': {
        'title': 'گزارش نتیجه موجود',
        'kind': 'Request',
        'sections': []
      }
    };
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
        'inline result selector searches published forms without a new route at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final forms = _Forms();
      final busy = <bool>[];
      FormMap? selected;
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          builder: (_, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: Scaffold(
              body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ActionResultFormPicker(
                      repository: forms,
                      inline: true,
                      onBusyChanged: busy.add,
                      onSelected: (value) => selected = value)))));
      await tester.pumpAndSettle();
      final input = find.byType(TextField).first;
      await tester.tap(input);
      await tester.enterText(input, 'گزارش');
      await tester.pumpAndSettle();
      expect(find.text('پیش‌نویس منتشرنشده'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('گزارش نتیجه موجود').hitTestable());
      await tester.pumpAndSettle();
      expect(selected?['form'], 'existing');
      expect(selected?['revision'], 'rev-1');
      expect(forms.calls, ['get_form']);
      expect(busy, [true, false]);
      expect(find.byType(ActionResultFormPicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
