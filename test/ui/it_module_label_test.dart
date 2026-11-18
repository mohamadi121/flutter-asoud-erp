import 'dart:io';

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/module_vocabulary.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends Fake implements WorkflowRepository {
  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(
        companies: ['دفتر اول'],
        modules: [
          WorkflowModuleOption(key: 'Purchase', doctypes: [
            WorkflowDoctypeOption(name: 'Material Request', available: true),
          ]),
          WorkflowModuleOption(key: 'IT', doctypes: [
            WorkflowDoctypeOption(name: 'ASOUD Workflow Request', available: true),
          ]),
        ],
      );
  @override
  Future<WorkflowDefinition> createDraft(
      {required String title,
      required String moduleKey,
      required String targetDoctype,
      required String creationMode,
      String? description,
      String? company,
      String? iconKey,
      String? colorHex}) async =>
      throw UnimplementedError();
}

void main() {
  test('the IT module key maps to فناوری اطلاعات', () {
    expect(moduleLabel('IT'), 'فناوری اطلاعات');
    expect(moduleLabel('IT'), isNot('IT و تجهیزات'));
  });

  test('no source file still shows the old IT و تجهیزات label', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.readAsStringSync().contains('IT و تجهیزات')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'the old IT module label must not appear anywhere in lib/');
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('the module picker shows فناوری اطلاعات, never IT و تجهیزات ($width)',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(RepositoryProvider<WorkflowRepository>.value(
        value: _Repository(),
        child: MaterialApp(
            theme: AsoudTheme.light,
            builder: (_, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
            home: const WorkflowFormPage()),
      ));
      await tester.pumpAndSettle();
      // Open the module picker.
      await tester.tap(find.byKey(const ValueKey('workflow-module')));
      await tester.pumpAndSettle();
      // The IT module is labelled «فناوری اطلاعات» and the old label is gone.
      expect(find.text('فناوری اطلاعات'), findsOneWidget);
      expect(find.text('IT و تجهیزات'), findsNothing);
      // Selecting it keeps the technical key 'IT' but shows the Persian title.
      await tester.tap(find.byKey(const ValueKey('option-IT')));
      await tester.pumpAndSettle();
      expect(find.text('IT و تجهیزات'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
