import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/asoud_bottom_bar.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/cubit/offices_cubit.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/offices_page.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_office_repository.dart';

class FakeWorkflowRepository implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _items = [
  AsoudBottomBarItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'خانه',
  ),
  AsoudBottomBarItem(icon: Icons.hub_outlined, label: 'گردش‌کار'),
  AsoudBottomBarItem(icon: Icons.assignment_ind_outlined, label: 'کارتابل'),
  AsoudBottomBarItem(icon: Icons.bar_chart_rounded, label: 'گزارش‌ها'),
  AsoudBottomBarItem(icon: Icons.settings_outlined, label: 'تنظیمات'),
];

Widget _app({required List<AsoudBottomBarItem> items, required int index}) =>
    MaterialApp(
      theme: AsoudTheme.light,
      home: Scaffold(
        body: const SizedBox(),
        bottomNavigationBar: AsoudBottomBar(
            items: items, selectedIndex: index, onSelected: (_) {}),
      ),
    );

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('نوار پایین در عرض $width بدون overflow رندر می‌شود',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(items: _items, index: 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final bar = tester.getSize(find.byType(AsoudBottomBar));
      expect(bar.height, greaterThanOrEqualTo(64));
      for (final item in _items) {
        expect(find.text(item.label), findsOneWidget);
      }
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
    });

    testWidgets(
        'هر آیتم نوار در عرض $width حداقل 48×48 قابل لمس است و کار می‌کند',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final tapped = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: AsoudBottomBar(
              items: _items,
              selectedIndex: 0,
              onSelected: tapped.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < _items.length; i++) {
        final target = find.byKey(ValueKey('asoud-bar-item-$i'));
        expect(target, findsOneWidget);
        final size = tester.getSize(target);
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }

      await tester.tap(find.text('کارتابل'));
      await tester.pump();
      expect(tapped, [2]);
    });
  }

  testWidgets('آیتم برگزیده نشانگر غیررنگی (نوار بالایی) دارد', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(items: _items, index: 1));
    await tester.pumpAndSettle();

    final indicator = find.byKey(const ValueKey('asoud-bar-indicator'));
    expect(indicator, findsOneWidget);
    expect(tester.getSize(indicator).height, 3);
    final selected =
        tester.getRect(find.byKey(const ValueKey('asoud-bar-item-1')));
    final center = tester.getCenter(indicator);
    expect(center.dx, inInclusiveRange(selected.left, selected.right));
    expect(tester.widget<Icon>(find.byIcon(Icons.hub_outlined)), isNotNull);
  });

  testWidgets('ترتیب آیتم‌ها راست‌به‌چپ است و خانه یکم است', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(items: _items, index: 0));
    await tester.pumpAndSettle();

    final first = tester.getCenter(find.text('خانه'));
    final last = tester.getCenter(find.text('تنظیمات'));
    expect(first.dx, greaterThan(last.dx));
  });

  testWidgets('offices page از AsoudBottomBar با چهار مقصد استفاده می‌کند',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepositoryProvider<OfficeRepository>.value(
        value: FakeOfficeRepository(),
        child: MaterialApp(
          locale: const Locale('fa'),
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: OfficesPage(
              initialState: OfficesState(status: OfficesStatus.empty),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = find.byType(AsoudBottomBar);
    expect(bar, findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('منوها'), findsOneWidget);
    expect(find.text('دفترها'), findsOneWidget);
    expect(find.text('گزارش‌ها'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workflow bar از AsoudBottomBar با پنج مقصد استفاده می‌کند',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepositoryProvider<WorkflowRepository>.value(
        value: FakeWorkflowRepository(),
        child: const MaterialApp(home: WorkflowListPage()),
      ),
    );
    await tester.pumpAndSettle();

    final bar = find.byType(AsoudBottomBar);
    expect(bar, findsOneWidget);
    expect(find.text('داشبورد'), findsOneWidget);
    expect(find.text('اعلان‌ها'), findsOneWidget);
    expect(find.text('گردش‌کار'), findsOneWidget);
    expect(find.text('گزارش‌ها'), findsOneWidget);
    expect(find.text('بیشتر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
