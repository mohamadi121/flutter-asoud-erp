import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/floating_detail.dart';
import '../../domain/repositories/parties_repository.dart';
import '../cubit/floating_detail_form_cubit.dart';

class FloatingDetailFormPage extends StatelessWidget {
  const FloatingDetailFormPage({required this.repository, super.key});
  final PartiesRepository repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => FloatingDetailFormCubit(repository)..initialize(),
        child: const _FloatingDetailFormView(),
      );
}

class _FloatingDetailFormView extends StatelessWidget {
  const _FloatingDetailFormView();

  @override
  Widget build(BuildContext context) => BlocConsumer<FloatingDetailFormCubit, FloatingDetailFormState>(
        listener: (context, state) {
          if (state.status == DetailFormStatus.success) Navigator.of(context).pop<FloatingDetail>(state.saved);
        },
        builder: (context, state) {
          final cubit = context.read<FloatingDetailFormCubit>();
          return Scaffold(
            appBar: AppBar(title: const Text('ایجاد تفصیلی شناور')),
            body: state.status == DetailFormStatus.loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: state.groupCode,
                        decoration: const InputDecoration(labelText: 'گروه تفصیلی *'),
                        items: state.groups
                            .map((group) => DropdownMenuItem(value: group.code, child: Text('${group.code} — ${group.title}')))
                            .toList(),
                        onChanged: cubit.setGroup,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: state.type,
                        decoration: const InputDecoration(labelText: 'نوع تفصیلی *'),
                        items: const [
                          DropdownMenuItem(value: 'Customer', child: Text('مشتری')),
                          DropdownMenuItem(value: 'Supplier', child: Text('تأمین‌کننده')),
                          DropdownMenuItem(value: 'Employee', child: Text('پرسنل')),
                          DropdownMenuItem(value: 'Bank', child: Text('بانک')),
                          DropdownMenuItem(value: 'Cash', child: Text('صندوق')),
                          DropdownMenuItem(value: 'Cost Center', child: Text('مرکز هزینه')),
                          DropdownMenuItem(value: 'Project', child: Text('پروژه')),
                          DropdownMenuItem(value: 'Other', child: Text('سایر')),
                        ],
                        onChanged: (value) { if (value != null) cubit.setType(value); },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(decoration: const InputDecoration(labelText: 'عنوان *'), onChanged: cubit.setTitle),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تولید خودکار کد تفصیلی'),
                        value: state.autoCode,
                        onChanged: cubit.setAutoCode,
                      ),
                      if (!state.autoCode)
                        TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'کد تفصیلی *'),
                          onChanged: cubit.setManualCode,
                        ),
                      if (state.status == DetailFormStatus.invalid)
                        const Text('فیلدهای الزامی را کامل کنید.', style: TextStyle(color: Colors.red)),
                      if (state.status == DetailFormStatus.failure)
                        Text(state.message ?? 'ذخیره انجام نشد.', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: state.status == DetailFormStatus.saving ? null : cubit.submit,
                        child: state.status == DetailFormStatus.saving
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('ایجاد تفصیلی'),
                      ),
                    ],
                  ),
          );
        },
      );
}
