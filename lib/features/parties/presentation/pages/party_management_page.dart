import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';
import '../cubit/parties_cubit.dart';
import 'party_form_page.dart';
import 'party_details_page.dart';

class PartyManagementPage extends StatelessWidget {
  const PartyManagementPage(
      {this.company,
      this.initialRole,
      this.createWhenEmpty = false,
      super.key});
  final bool createWhenEmpty;
  final String? company;
  final PartyRole? initialRole;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            PartiesCubit(context.read<PartyRepository>(), company: company)
              ..load(role: initialRole),
        child: _PartyManagementView(
            company: company,
            initialRole: initialRole,
            createWhenEmpty: createWhenEmpty),
      );
}

class _PartyManagementView extends StatefulWidget {
  const _PartyManagementView(
      {required this.company,
      required this.initialRole,
      required this.createWhenEmpty});
  final bool createWhenEmpty;
  final String? company;
  final PartyRole? initialRole;
  @override
  State<_PartyManagementView> createState() => _PartyManagementViewState();
}

class _PartyManagementViewState extends State<_PartyManagementView> {
  PartyRole? role;
  String query = '';
  bool? disabled;
  bool initialLoadHandled = false;

  Future<void> _details(PartyProfile profile) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => PartyDetailsPage(profile: profile)));
    if (mounted) await context.read<PartiesCubit>().load(role: role);
  }

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
            title: 'اشخاص و شرکت‌ها',
            subtitle: 'مشاهده، ایجاد و ویرایش اطلاعات اشخاص و پرسنل'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _open,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('شخص جدید'),
        ),
        body: SafeArea(
            child: BlocConsumer<PartiesCubit, PartiesState>(
          listener: (context, state) {
            if (initialLoadHandled ||
                ![
                  PartiesStatus.success,
                  PartiesStatus.empty,
                  PartiesStatus.failure
                ].contains(state.status)) {
              return;
            }
            initialLoadHandled = true;
            if (widget.createWhenEmpty &&
                state.status == PartiesStatus.empty &&
                role == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _open();
              });
            }
          },
          builder: (context, state) => RefreshIndicator(
            onRefresh: () => context.read<PartiesCubit>().load(role: role),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
              children: [
                TextField(
                  decoration: const InputDecoration(
                      hintText: 'جست‌وجوی نام، کد یا شماره تماس',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _filter('همه', null),
                  _filter('مشتریان', PartyRole.customer),
                  _filter('تأمین‌کنندگان', PartyRole.supplier),
                  _filter('پرسنل', PartyRole.employee),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 6, children: [
                  for (final entry in <bool?, String>{
                    null: 'همه وضعیت‌ها',
                    false: 'فعال',
                    true: 'غیرفعال'
                  }.entries)
                    ChoiceChip(
                        label: Text(entry.value),
                        selected: disabled == entry.key,
                        onSelected: (_) =>
                            setState(() => disabled = entry.key)),
                ]),
                if (state.status == PartiesStatus.loading)
                  const LinearProgressIndicator(),
                if (state.status == PartiesStatus.offlineSaved)
                  const _OfflineNotice(),
                if (state.status == PartiesStatus.failure) ...[
                  Text(state.message ?? 'دریافت اطلاعات انجام نشد.'),
                  TextButton(
                      onPressed: () =>
                          context.read<PartiesCubit>().load(role: role),
                      child: const Text('تلاش دوباره')),
                ],
                if (state.items.where(_matches).isEmpty &&
                    [PartiesStatus.success, PartiesStatus.empty]
                        .contains(state.status))
                  const _EmptyParties(),
                ...state.items.where(_matches).map((item) =>
                    _PartyCard(profile: item, onTap: () => _details(item))),
              ],
            ),
          ),
        )),
      );

  bool _matches(PartyProfile item) =>
      (disabled == null || item.disabled == disabled) &&
      [
        item.displayName,
        item.mobile ?? '',
        item.nationalId ?? '',
        ...item.floatingDetails.map((d) => d.code)
      ].any((value) => value.toLowerCase().contains(query));

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
          trailing: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(profile.disabled ? 'غیرفعال' : 'فعال',
                style: TextStyle(
                    color: profile.disabled
                        ? AsoudColors.muted
                        : AsoudColors.success)),
            const Icon(Icons.chevron_left),
          ]),
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
