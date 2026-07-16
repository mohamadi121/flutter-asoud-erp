import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../domain/repositories/setup_repository.dart';
import '../bloc/roles_setup_cubit.dart';

class RolesSetupPage extends StatelessWidget {
  const RolesSetupPage({super.key});

  static const roles = [
    ('System Manager', 'مدیر سیستم', Icons.admin_panel_settings_rounded, Color(0xFF5C6BC0)),
    ('Accounts Manager', 'مدیر مالی', Icons.account_balance_rounded, Color(0xFFFFB547)),
    ('Accounts User', 'حسابدار', Icons.calculate_rounded, Color(0xFF26A69A)),
    ('Stock User', 'انباردار', Icons.inventory_2_rounded, Color(0xFFEF6C5B)),
    ('Sales User', 'کارشناس فروش', Icons.storefront_rounded, Color(0xFF42A5F5)),
  ];

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => RolesSetupCubit(context.read<SetupRepository>(), AppConfig.companyName),
        child: const _RolesSetupView(),
      );
}

class _RolesSetupView extends StatelessWidget {
  const _RolesSetupView();

  @override
  Widget build(BuildContext context) => BlocListener<RolesSetupCubit, RolesSetupState>(
        listener: (context, state) {
          if (state.status == RolesSetupStatus.success) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const DashboardPage()),
              (route) => false,
            );
          } else if (state.status == RolesSetupStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage ?? 'ذخیره نقش‌ها انجام نشد.')),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('نقش‌های اولیه')),
          body: SafeArea(
            child: BlocBuilder<RolesSetupCubit, RolesSetupState>(
              builder: (context, state) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('نقش‌های فعال این دفتر را انتخاب کنید', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('این گزینه‌ها نقش‌های کاری دفتر هستند و مجوز کاربران Frappe را تغییر نمی‌دهند.', style: TextStyle(color: AsoudColors.muted)),
                  const SizedBox(height: 20),
                  ...RolesSetupPage.roles.map((role) => Card(
                        elevation: 0,
                        color: Colors.white,
                        child: CheckboxListTile(
                          value: state.selected.contains(role.$1),
                          secondary: Icon(role.$3, color: role.$4),
                          title: Text(role.$2),
                          onChanged: role.$1 == 'System Manager' || state.status == RolesSetupStatus.saving
                              ? null
                              : (value) => context.read<RolesSetupCubit>().toggle(role.$1, value == true),
                        ),
                      )),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: state.status == RolesSetupStatus.saving ? null : context.read<RolesSetupCubit>().submit,
                    child: state.status == RolesSetupStatus.saving
                        ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('تکمیل تنظیمات پایه'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
