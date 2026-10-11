import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final profile = PartyProfile(
    id: 'PRT-01',
    displayName: 'علی کریمی',
    kind: PartyKind.individual,
    roles: const {PartyRole.employee},
    jobTitle: 'کارشناس فروش',
    department: 'فروش',
    employeeRoles: const {'مدیر فروش'},
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('shared personnel section uses plain text at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: PartyDetailsPage(profile: profile),
      ));
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(ExpansionTile, 'اطلاعات پرسنلی مشترک');
      await tester.scrollUntilVisible(tile, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(
          find.descendant(
              of: tile, matching: find.byType(SelectableText)),
          findsNothing);
      final jobTitle = find.descendant(
          of: tile, matching: find.text('کارشناس فروش'));
      expect(jobTitle, findsOneWidget);
      expect(tester.getSize(jobTitle).height, lessThan(120));
      expect(tester.takeException(), isNull);
    });
  }
}