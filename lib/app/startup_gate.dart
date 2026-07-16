import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/base_setup/domain/entities/setup_status.dart';
import '../features/base_setup/domain/repositories/setup_repository.dart';
import '../features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import '../features/base_setup/presentation/pages/roles_setup_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/office_setup/presentation/pages/office_type_page.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<SetupStatus> _status;

  @override
  void initState() {
    super.initState();
    _status = context.read<SetupRepository>().getStatus();
  }

  void _retry() => setState(() => _status = context.read<SetupRepository>().getStatus());

  @override
  Widget build(BuildContext context) => FutureBuilder<SetupStatus>(
        future: _status,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48),
                      const SizedBox(height: 12),
                      const Text('دریافت وضعیت راه‌اندازی از سرور انجام نشد.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره')),
                    ],
                  ),
                ),
              ),
            );
          }
          final status = snapshot.data ?? const SetupStatus();
          return switch (status.nextStep) {
            SetupStep.office => const OfficeTypePage(),
            SetupStep.accounting => const BaseAccountingSetupPage(),
            SetupStep.roles => const RolesSetupPage(),
            SetupStep.complete => const DashboardPage(),
          };
        },
      );
