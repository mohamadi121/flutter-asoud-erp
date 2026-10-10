import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/roles/data/role_repository.dart';
import 'package:asoud_erp/features/roles/presentation/role_cubit.dart';
import 'package:asoud_erp/features/roles/presentation/roles_page.dart';

import '../helpers/fake_role_client.dart';

void main() {
  testWidgets(
      'Role category create form shows two visible bold labels above the inputs at 320 px RTL',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = RoleRepository(FakeRoleClient());
    final cubit = RoleCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: BlocProvider<RoleCubit>.value(
            value: cubit,
            child: const Scaffold(body: RoleCategoryFormView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleLabel = find.byWidgetPredicate(
      (w) => w is Text && w.data == 'نام دسته *' && w.style?.fontWeight == FontWeight.w700,
    );
    expect(titleLabel, findsOneWidget);

    final codeLabel = find.byWidgetPredicate(
      (w) => w is Text && w.data == 'کد دسته *' && w.style?.fontWeight == FontWeight.w700,
    );
    expect(codeLabel, findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}