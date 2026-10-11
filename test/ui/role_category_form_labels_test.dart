import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
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

    // Bug #27 then #31: the two category fields carry visible labels; they are
    // now the title/bold floating labels of the shared AppTextField.
    expect(find.text('نام دسته *'), findsOneWidget);
    expect(find.text('کد دسته *'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(2));

    expect(tester.takeException(), isNull);
  });
}