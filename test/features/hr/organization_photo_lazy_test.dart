import 'dart:typed_data';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:asoud_erp/features/hr/domain/organization_chart.dart';
import 'package:asoud_erp/features/hr/presentation/pages/organization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements OrganizationRepository {}

Finder get visualReport => find.textContaining('گزارش تصویری');

void main() {
  setUpAll(() {
    registerFallbackValue(const OrganizationSnapshot([], 0, false));
  });

  Future<_Repository> open(WidgetTester tester,
      Future<Uint8List?> Function(String employee) photo) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    final rows = [
      for (var i = 0; i < 12; i++)
        OrgPosition(
            code: 'P$i', title: 'جایگاه $i', occupants: ['EMP-$i'])
    ];
    when(() => repository.authenticationChanges)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.dispose()).thenAnswer((_) async {});
    when(() => repository.load(any()))
        .thenAnswer((_) async => OrganizationSnapshot(rows, 1, false));
    when(() => repository.units(any()))
        .thenAnswer((_) async => {'units': [], 'can_manage': false});
    when(() => repository.employees(any())).thenAnswer((_) async => [
          for (var i = 0; i < 12; i++)
            OrganizationEmployee('EMP-$i', 'کارمند $i')
        ]);
    when(() => repository.employeePhoto(any(), any())).thenAnswer(
        (i) => photo(i.positionalArguments[1] as String));
    await tester.pumpWidget(MaterialApp(
        home: OrganizationPage(company: 'شرکت', repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشاهده و تکمیل ساختار سازمانی'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('off-screen position cards do not request their photo',
      (tester) async {
    final repository = await open(tester, (_) async => null);
    await tester.tap(visualReport.first);
    await tester.pumpAndSettle();

    final requested = verify(() => repository.employeePhoto(any(), captureAny()))
        .captured
        .cast<String>();
    expect(requested, contains('EMP-0'));
    expect(requested.length, lessThan(12));
    expect(requested.toSet().length, requested.length);
  });

  testWidgets('a failing photo request leaves the initials avatar, no banner',
      (tester) async {
    await open(
        tester,
        (_) => Future<Uint8List?>.error(const ApiException(
            kind: ApiFailureKind.network, message: 'offline')));
    await tester.tap(visualReport.first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person_outline), findsWidgets);
    expect(find.text('جایگاه 0'), findsOneWidget);
    expect(find.textContaining('ارتباط با سرور'), findsNothing);
  });
}
