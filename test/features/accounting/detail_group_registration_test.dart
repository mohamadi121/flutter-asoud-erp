import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/cubit/detail_groups_cubit.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/detail_groups_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements DetailGroupRepository {}

void main() {
  late _Repository repository;
  setUp(() {
    repository = _Repository();
    when(() => repository.getGroups()).thenAnswer((_) async => []);
    when(() => repository.saveGroup(code: any(named: 'code'), title: any(named: 'title')))
        .thenAnswer((invocation) async => DetailGroup(
          id: 'saved', code: invocation.namedArguments[#code] as String,
          title: invocation.namedArguments[#title] as String,
        ));
  });

  test('Persian Arabic and ASCII digits preserve leading zeros', () async {
    final cubit = DetailGroupsCubit(repository);
    for (final code in ['۰۱۲۳', '٠١٢٣', '0123']) {
      expect(await cubit.saveGroup(code, 'گروه'), isTrue);
    }
    verify(() => repository.saveGroup(code: '0123', title: 'گروه')).called(3);
    expect(await cubit.saveGroup('12x3', 'گروه'), isFalse);
    expect(await cubit.saveGroup('12', 'گروه'), isFalse);
    await cubit.close();
  });

  testWidgets('focused dialog can save reopen validate and cancel safely', (tester) async {
    await tester.pumpWidget(RepositoryProvider<DetailGroupRepository>.value(
      value: repository,
      child: const MaterialApp(home: DetailGroupsPage()),
    ));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('افزودن گروه'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'گروه');
      await tester.enterText(find.byType(TextField).last, '۰۱۲۳');
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('افزودن گروه'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '۱۲');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('عنوان و کد ۳ تا ۱۲ رقمی گروه را بررسی کنید.'), findsWidgets);
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
