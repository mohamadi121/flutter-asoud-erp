import 'dart:math' as math;

import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _WorkflowRepository implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  }) async =>
      const [
        WorkflowDefinition(
          id: 'WF-0001',
          code: 'WF-0001',
          title: 'فرایند خرید کالا',
          targetDoctype: 'Material Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 4,
          modified: null,
          iconKey: 'purchase',
        ),
      ];
}

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) => 0.2126 * _channel(c.r) +
    0.7152 * _channel(c.g) +
    0.0722 * _channel(c.b);

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('status colours reach WCAG AA contrast on their surfaces', () {
    expect(contrastRatio(AsoudColors.success, AsoudColors.successSurface),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(AsoudColors.warning, AsoudColors.warningSurface),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(AsoudColors.danger, AsoudColors.surface),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(AsoudColors.muted, AsoudColors.surface),
        greaterThanOrEqualTo(4.5));
  });

  test('theme gives the FAB and outline buttons accessible colours', () {
    final theme = AsoudTheme.light;
    expect(theme.floatingActionButtonTheme.backgroundColor, AsoudColors.primary);
    expect(theme.floatingActionButtonTheme.foregroundColor, Colors.white);
    expect(
        theme.outlinedButtonTheme.style?.foregroundColor?.resolve(<WidgetState>{}),
        AsoudColors.primary);
  });

  testWidgets('active workflow chip uses the accessible success colours',
      (tester) async {
    await tester.pumpWidget(
      RepositoryProvider<WorkflowRepository>.value(
        value: _WorkflowRepository(),
        child: MaterialApp(
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: WorkflowListPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badgeText =
        find.descendant(of: find.byType(Card), matching: find.text('فعال'));
    expect(badgeText, findsOneWidget);
    expect(tester.widget<Text>(badgeText).style?.color, AsoudColors.success);
    expect(
        find.ancestor(
            of: badgeText,
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    AsoudColors.successSurface)),
        findsOneWidget);
  });
}