import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../data/repositories/frappe_parties_repository.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/parties_repository.dart';
import '../cubit/parties_cubit.dart';
import 'party_form_page.dart';

class PartiesPage extends StatelessWidget {
  const PartiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FrappePartiesRepository(FrappeClient());
    return BlocProvider(
      create: (_) => PartiesCubit(repository)..load(),
      child: _PartiesView(repository: repository),
    );
  }
}

class _PartiesView extends StatelessWidget {
  const _PartiesView({required this.repository});
  final PartiesRepository repository;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PartiesCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('اشخاص و طرف‌حساب‌ها')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.of(context).push<PartyProfile>(
            MaterialPageRoute(builder: (_) => PartyFormPage(repository: repository)),
          );
          if (saved != null && context.mounted) context.read<PartiesCubit>().load();
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('شخص جدید'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'نام، شناسه ملی یا موبایل'),
            onSubmitted: (value) => context.read<PartiesCubit>().load(search: value),
          ),
          const SizedBox(height: 14),
          if (state.status == PartiesStatus.loading)
            const Center(child: CircularProgressIndicator())
          else if (state.status == PartiesStatus.failure)
            Center(child: Text(state.message ?? 'دریافت اشخاص انجام نشد.'))
          else if (state.items.isEmpty)
            const Center(child: Text('هنوز شخصی ثبت نشده است.'))
          else
            ...state.items.map(
              (party) => Card(
                elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(party.type == PartyType.individual ? Icons.person_rounded : Icons.apartment_rounded),
                  ),
                  title: Text(party.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(party.roles.map(_roleTitle).join('، ')),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final saved = await Navigator.of(context).push<PartyProfile>(
                      MaterialPageRoute(builder: (_) => PartyFormPage(repository: repository, party: party)),
                    );
                    if (saved != null && context.mounted) context.read<PartiesCubit>().load();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _roleTitle(PartyRole role) => switch (role) {
        PartyRole.customer => 'مشتری',
        PartyRole.supplier => 'تأمین‌کننده',
        PartyRole.employee => 'پرسنل',
        PartyRole.shareholder => 'سهام‌دار',
        PartyRole.other => 'سایر',
      };
}
