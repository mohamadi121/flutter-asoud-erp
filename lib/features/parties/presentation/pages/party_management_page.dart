import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';
import '../cubit/parties_cubit.dart';
import 'party_form_page.dart';

class PartyManagementPage extends StatelessWidget {
  const PartyManagementPage({this.company, this.initialRole, super.key});
  final String? company;
  final PartyRole? initialRole;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            PartiesCubit(context.read<PartyRepository>(), company: company)
              ..load(role: initialRole),
        child: _PartyManagementView(company: company, initialRole: initialRole),
      );
}

class _PartyManagementView extends StatefulWidget {
  const _PartyManagementView(
      {required this.company, required this.initialRole});
  final String? company;
  final PartyRole? initialRole;
  @override
  State<_PartyManagementView> createState() => _PartyManagementViewState();
}

class _PartyManagementViewState extends State<_PartyManagementView> {
  PartyRole? role;
  @override
  void initState() {
    super.initState();
    role = widget.initialRole;
  }

  Future<void> _open([PartyProfile? profile]) async {
    final selectedRole =
        profile?.roles.firstOrNull ?? role ?? PartyRole.customer;
    final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => PartyFormPage(
            company: widget.company,
            profile: profile,
            initialRole: selectedRole,
            initialKind: profile?.kind ?? PartyKind.individual,
            pageTitle: profile == null ? 'ایجاد شخص' : 'ویرایش اطلاعات شخص',
          ),
        ));
    if (changed == true && mounted) {
      await context.read<PartiesCubit>().load(role: role);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'مدیریت اشخاص',
            subtitle: 'مشاهده، ایجاد و ویرایش اطلاعات اشخاص و پرسنل'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _open,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('شخص جدید'),
        ),
        body: SafeArea(
            child: BlocBuilder<PartiesCubit, PartiesState>(
          builder: (context, state) => RefreshIndicator(
            onRefresh: () => context.read<PartiesCubit>().load(role: role),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
              children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _filter('همه', null),
                  _filter('مشتریان', PartyRole.customer),
                  _filter('تأمین‌کنندگان', PartyRole.supplier),
                  _filter('پرسنل', PartyRole.employee),
                ]),
                const SizedBox(height: 12),
                if (state.status == PartiesStatus.loading)
                  const LinearProgressIndicator(),
                if (state.status == PartiesStatus.offlineSaved)
                  const _OfflineNotice(),
                if (state.items.isEmpty &&
                    state.status != PartiesStatus.loading)
                  const _EmptyParties(),
                ...state.items.where((item) => !item.disabled).map((item) =>
                    _PartyCard(profile: item, onTap: () => _open(item))),
              ],
            ),
          ),
        )),
      );

  Widget _filter(String label, PartyRole? value) => ChoiceChip(
        label: Text(label),
        selected: role == value,
        onSelected: (_) {
          setState(() => role = value);
          context.read<PartiesCubit>().load(role: value);
        },
      );
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.profile, required this.onTap});
  final PartyProfile profile;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          onTap: onTap,
          leading: AsoudIconBox(
            icon: profile.roles.contains(PartyRole.employee)
                ? Icons.badge_outlined
                : profile.kind == PartyKind.organization
                    ? Icons.apartment_rounded
                    : Icons.person_outline_rounded,
            color: profile.roles.contains(PartyRole.employee)
                ? AsoudColors.warning
                : AsoudColors.primary,
          ),
          title: Text(profile.displayName,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text([
            if (profile.roles.isNotEmpty)
              profile.roles.map(_roleTitle).join('، '),
            if (profile.mobile?.isNotEmpty == true) profile.mobile!,
          ].join(' • ')),
          trailing: const Icon(Icons.edit_outlined),
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

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text('اطلاعات روی گوشی ذخیره شده و در انتظار همگام‌سازی است.',
            style: TextStyle(fontSize: 9, color: AsoudColors.warning)),
      );
}

class _EmptyParties extends StatelessWidget {
  const _EmptyParties();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Column(children: [
          AsoudIconBox(
              icon: Icons.people_outline_rounded,
              color: AsoudColors.muted,
              size: 56),
          SizedBox(height: 12),
          Text('هنوز شخصی در این بخش ثبت نشده است.',
              style: TextStyle(color: AsoudColors.muted)),
        ]),
      );
}
