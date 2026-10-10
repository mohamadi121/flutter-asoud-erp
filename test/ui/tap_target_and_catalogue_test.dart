import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/request_types/domain/request_type_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'plain icon buttons and popup menus keep the 48x48 tap target, '
      'chips are at least 40 high', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  key: const Key('plain-icon'),
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert_rounded)),
              IconButton(
                  key: const Key('list-icon'),
                  onPressed: () {},
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20)),
              ChoiceChip(
                  key: const Key('filter-chip'),
                  label: const Text('فعال'),
                  selected: false,
                  onSelected: (_) {}),
              PopupMenuButton<String>(
                key: const Key('menu-button'),
                onSelected: (_) {},
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'x', child: Text('ویرایش')),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final iconSize = tester.getSize(find.byKey(const Key('plain-icon')));
    expect(iconSize.width, greaterThanOrEqualTo(48));
    expect(iconSize.height, greaterThanOrEqualTo(48));
    final listIconSize = tester.getSize(find.byKey(const Key('list-icon')));
    expect(listIconSize.width, greaterThanOrEqualTo(48));
    expect(listIconSize.height, greaterThanOrEqualTo(48));

    final chipSize = tester.getSize(find.byKey(const Key('filter-chip')));
    expect(chipSize.height, greaterThanOrEqualTo(40));

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();
    final menu = find.text('ویرایش');
    expect(menu, findsOneWidget);
    final buttonRect = tester.getRect(find.byKey(const Key('menu-button')));
    final menuRect = tester.getRect(menu);
    expect(menuRect.left, lessThan(buttonRect.right),
        reason: 'menu must open anchored under the ⋮ button');
  });

  test('request icon catalogue uses the accessible named colours', () {
    final leave = requestIconFor('leave');
    expect(leave.color, AsoudColors.danger);
    expect(leave.hex, '#B3261E');
    final loan = requestIconFor('loan');
    expect(loan.color, AsoudColors.success);
    expect(loan.hex, '#0B6B3A');
    final other = requestIconFor(null);
    expect(other.color, AsoudColors.muted);
    expect(other.hex, '#5B6478');
  });
}