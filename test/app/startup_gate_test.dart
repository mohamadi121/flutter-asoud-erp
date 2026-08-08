import 'package:asoud_erp/app/startup_gate.dart';
import 'package:asoud_erp/features/base_setup/domain/entities/accounting_setup.dart';
import 'package:asoud_erp/features/base_setup/domain/entities/setup_status.dart';
import 'package:asoud_erp/features/base_setup/domain/repositories/setup_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineSetupRepository implements SetupRepository {
  @override
  Future<SetupStatus> getStatus({String? company}) =>
      Future<SetupStatus>.error(Exception('offline'));

  @override
  Future<SetupStatus> saveAccounting(
          String company, AccountingSetup setup) async =>
      throw UnimplementedError();

  @override
  Future<SetupStatus> saveEnabledRoles(
          String company, Set<String> roles) async =>
      throw UnimplementedError();
}

void main() {
  testWidgets('نبود سرور مانع ورود به داشبورد آزمایشی نمی‌شود', (tester) async {
    await tester.pumpWidget(
      RepositoryProvider<SetupRepository>.value(
        value: _OfflineSetupRepository(),
        child: const MaterialApp(home: StartupGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('آسود ERP'), findsOneWidget);
    expect(find.textContaining('حالت پیش‌نمایش آفلاین'), findsOneWidget);
    expect(find.text('گردش‌کار'), findsOneWidget);
  });
}
