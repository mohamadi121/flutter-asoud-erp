import 'dart:async';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:asoud_erp/features/parties/presentation/cubit/parties_cubit.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_details_page.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements PartyRepository {}

const person = PartyProfile(
    id: 'p1',
    company: 'office',
    kind: PartyKind.individual,
    displayName: 'حسن',
    roles: {PartyRole.employee},
    mobile: '09120000000',
    nationalId: '1234567890');
const supplier = PartyProfile(
    id: 'p2',
    company: 'office',
    kind: PartyKind.organization,
    displayName: 'شرکت دوم',
    roles: {PartyRole.supplier},
    disabled: true);

Widget app(PartyRepository repository, Widget page) =>
    RepositoryProvider<PartyRepository>.value(
      value: repository,
      child: MaterialApp(
          home: Directionality(textDirection: TextDirection.rtl, child: page)),
    );

void main() {
  testWidgets(
      'all persons include inactive; search opens read-only accordion details',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    when(() => repository.list(company: 'office'))
        .thenAnswer((_) async => [person, supplier]);
    await tester.pumpWidget(
        app(repository, const PartyManagementPage(company: 'office')));
    await tester.pumpAndSettle();
    expect(find.text('حسن'), findsOneWidget);
    expect(find.text('شرکت دوم'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'حسن');
    await tester.pumpAndSettle();
    expect(find.text('شرکت دوم'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'حسن'));
    await tester.pumpAndSettle();
    expect(find.byType(PartyDetailsPage), findsOneWidget);
    expect(find.text('1234567890'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed first load never opens creation form or claims empty',
      (tester) async {
    final repository = _Repository();
    when(() => repository.list(company: 'office'))
        .thenThrow(StateError('offline'));
    await tester.pumpWidget(app(repository,
        const PartyManagementPage(company: 'office', createWhenEmpty: true)));
    await tester.pumpAndSettle();
    expect(find.text('تلاش دوباره'), findsOneWidget);
    expect(find.text('هنوز شخصی در این بخش ثبت نشده است.'), findsNothing);
    expect(find.text('ایجاد شخص'), findsNothing);
  });

  test('late filter response cannot replace current role', () async {
    final repository = _Repository();
    final old = Completer<List<PartyProfile>>();
    when(() => repository.list(company: 'office'))
        .thenAnswer((_) => old.future);
    when(() => repository.list(company: 'office', role: PartyRole.employee))
        .thenAnswer((_) async => [person]);
    final cubit = PartiesCubit(repository, company: 'office');
    final pending = cubit.load();
    await cubit.load(role: PartyRole.employee);
    old.complete([supplier]);
    await pending;
    expect(cubit.state.items, [person]);
    await cubit.close();
  });

  test('closing during load does not emit after disposal', () async {
    final repository = _Repository();
    final response = Completer<List<PartyProfile>>();
    when(() => repository.list(company: 'office'))
        .thenAnswer((_) => response.future);
    final cubit = PartiesCubit(repository, company: 'office');
    final pending = cubit.load();
    await cubit.close();
    response.complete([person]);
    await pending;
  });
}
