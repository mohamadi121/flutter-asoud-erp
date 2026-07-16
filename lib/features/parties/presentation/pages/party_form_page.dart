import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/parties_repository.dart';
import '../cubit/party_form_cubit.dart';

class PartyFormPage extends StatelessWidget {
  const PartyFormPage({required this.repository, this.party, super.key});
  final PartiesRepository repository;
  final PartyProfile? party;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PartyFormCubit(repository, party: party),
        child: const _PartyFormView(),
      );
}

class _PartyFormView extends StatelessWidget {
  const _PartyFormView();

  @override
  Widget build(BuildContext context) => BlocConsumer<PartyFormCubit, PartyFormState>(
        listener: (context, state) {
          if (state.status == PartyFormStatus.success) Navigator.of(context).pop<PartyProfile>(state.saved);
        },
        builder: (context, state) {
          final cubit = context.read<PartyFormCubit>();
          return Scaffold(
            appBar: AppBar(title: Text(state.id.isEmpty ? 'ایجاد شخص' : 'ویرایش شخص')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SegmentedButton<PartyType>(
                  segments: const [
                    ButtonSegment(value: PartyType.individual, label: Text('حقیقی'), icon: Icon(Icons.person_rounded)),
                    ButtonSegment(value: PartyType.organization, label: Text('حقوقی'), icon: Icon(Icons.apartment_rounded)),
                  ],
                  selected: {state.type},
                  onSelectionChanged: (value) => cubit.setType(value.first),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  initialValue: state.displayName,
                  decoration: InputDecoration(labelText: state.type == PartyType.individual ? 'نام و نام خانوادگی *' : 'نام شرکت/مؤسسه *'),
                  onChanged: cubit.setName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: state.nationalId,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: state.type == PartyType.individual ? 'کد ملی' : 'شناسه ملی'),
                  onChanged: cubit.setNationalId,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: state.mobile,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'شماره همراه'),
                  onChanged: cubit.setMobile,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: state.email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'ایمیل'),
                  onChanged: cubit.setEmail,
                ),
                const SizedBox(height: 20),
                const Text('نقش‌ها *', style: TextStyle(fontWeight: FontWeight.w800)),
                const Text('هر شخص می‌تواند هم‌زمان چند نقش داشته باشد.'),
                ...PartyRole.values.map(
                  (role) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_roleTitle(role)),
                    value: state.roles.contains(role),
                    onChanged: (value) => cubit.toggleRole(role, value ?? false),
                  ),
                ),
                if (state.roles.contains(PartyRole.employee))
                  const Card(
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('پروفایل پرسنلی ثبت می‌شود؛ ساخت Employee پس از تکمیل شرکت، تاریخ استخدام و اطلاعات منابع انسانی انجام خواهد شد.'),
                    ),
                  ),
                if (state.status == PartyFormStatus.invalid)
                  const Text('نام و حداقل یک نقش الزامی است.', style: TextStyle(color: Colors.red)),
                if (state.status == PartyFormStatus.failure)
                  Text(state.message ?? 'ذخیره انجام نشد.', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: state.status == PartyFormStatus.saving ? null : cubit.submit,
                  child: state.status == PartyFormStatus.saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('ذخیره شخص'),
                ),
              ],
            ),
          );
        },
      );

  String _roleTitle(PartyRole role) => switch (role) {
        PartyRole.customer => 'مشتری',
        PartyRole.supplier => 'تأمین‌کننده',
        PartyRole.employee => 'پرسنل',
        PartyRole.shareholder => 'سهام‌دار',
        PartyRole.other => 'سایر',
      };
}
