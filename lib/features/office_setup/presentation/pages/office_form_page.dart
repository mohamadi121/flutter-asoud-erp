import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../domain/entities/office.dart';
import '../bloc/office_form_bloc.dart';
import '../../../base_setup/presentation/pages/base_accounting_setup_page.dart';

class OfficeFormPage extends StatelessWidget {
  const OfficeFormPage({required this.officeType, super.key});
  final OfficeType officeType;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OfficeFormBloc(officeType: officeType),
      child: const _OfficeFormView(),
    );
  }
}

class _OfficeFormView extends StatelessWidget {
  const _OfficeFormView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<OfficeFormBloc, OfficeFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == OfficeFormStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دفتر با موفقیت ایجاد شد.'), backgroundColor: AsoudColors.success));
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const BaseAccountingSetupPage(),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('اطلاعات دفتر')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              BlocBuilder<OfficeFormBloc, OfficeFormState>(builder: (context, state) => Text(state.officeType == OfficeType.legal ? 'دفتر حقوقی' : 'دفتر حقیقی', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700))),
              const SizedBox(height: 22),
              TextField(textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'نام دفتر *'), onChanged: (value) => context.read<OfficeFormBloc>().add(OfficeNameChanged(value))),
              const SizedBox(height: 14),
              BlocBuilder<OfficeFormBloc, OfficeFormState>(builder: (context, state) {
                if (state.officeType != OfficeType.legal) return const SizedBox.shrink();
                return Column(children: [
                  TextField(keyboardType: TextInputType.number, maxLength: 11, decoration: const InputDecoration(labelText: 'شناسه ملی *'), onChanged: (value) => context.read<OfficeFormBloc>().add(NationalIdChanged(value))),
                  const SizedBox(height: 14),
                  TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'کد اقتصادی'), onChanged: (value) => context.read<OfficeFormBloc>().add(EconomicCodeChanged(value))),
                ]);
              }),
              const SizedBox(height: 8),
              BlocBuilder<OfficeFormBloc, OfficeFormState>(builder: (context, state) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تولید خودکار کد تفصیلی'),
                subtitle: const Text('برای حساب‌های جدید، کد تفصیلی به‌صورت خودکار ساخته شود.'),
                value: state.generateDetailCode,
                onChanged: (value) => context.read<OfficeFormBloc>().add(GenerateDetailCodeChanged(value)),
              )),
              const SizedBox(height: 24),
              BlocBuilder<OfficeFormBloc, OfficeFormState>(builder: (context, state) => FilledButton(
                onPressed: () => context.read<OfficeFormBloc>().add(const OfficeFormSubmitted()),
                child: const Text('ایجاد دفتر'),
              )),
              BlocBuilder<OfficeFormBloc, OfficeFormState>(builder: (context, state) {
                if (state.status != OfficeFormStatus.invalid) return const SizedBox.shrink();
                return const Padding(padding: EdgeInsets.only(top: 12), child: Text('لطفاً فیلدهای الزامی را کامل و صحیح وارد کنید.', style: TextStyle(color: Colors.red)));
              }),
            ],
          ),
        ),
      ),
    );
  }
}
