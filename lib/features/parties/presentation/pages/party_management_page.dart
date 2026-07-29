import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';
import '../cubit/parties_cubit.dart';
import 'party_detail_page.dart';
import 'party_form_page.dart';

class PartyManagementPage extends StatelessWidget {
  const PartyManagementPage({this.company, super.key});
  final String? company;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            PartiesCubit(context.read<PartyRepository>(), company: company)
              ..load(),
        child: _PartyManagementView(company: company),
      );
}

class _PartyManagementView extends StatefulWidget {
  const _PartyManagementView({required this.company});
  final String? company;
  @override
  State<_PartyManagementView> createState() => _PartyManagementViewState();
}

class _PartyManagementViewState extends State<_PartyManagementView> {
  PartyRole? filter;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'مدیریت اشخاص', subtitle: 'مشتریان، تأمین‌کنندگان و پرسنل'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(context, PartyRole.supplier),
          icon: const Icon(Icons.add_rounded),
          label: const Text('شخص جدید'),
        ),
        body: SafeArea(
          child: BlocBuilder<PartiesCubit, PartiesState>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
              children: [
                TextField(
                  onChanged: (value) => context
                      .read<PartiesCubit>()
                      .load(role: filter, search: value.trim()),
                  decoration: const InputDecoration(
                    hintText: 'جست‌وجوی نام، کد ملی یا موبایل',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                AsoudSegmentedControl<PartyRole?>(
                  value: filter,
                  options: const [
                    AsoudSegmentedOption(value: null, label: 'همه'),
                    AsoudSegmentedOption(
                        value: PartyRole.supplier,
                        label: 'تأمین‌کننده',
                        icon: Icons.inventory_2_outlined),
                    AsoudSegmentedOption(
                        value: PartyRole.employee,
                        label: 'پرسنل',
                        icon: Icons.badge_outlined),
                  ],
                  onChanged: (value) {
                    setState(() => filter = value);
                    context.read<PartiesCubit>().load(role: value);
                  },
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _CreateCard(
                      title: 'ایجاد تأمین‌کننده',
                      icon: Icons.inventory_2_outlined,
                      color: AsoudColors.success,
                      onTap: () => _openForm(context, PartyRole.supplier),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CreateCard(
                      title: 'ایجاد پرسنل',
                      icon: Icons.badge_outlined,
                      color: AsoudColors.primary,
                      onTap: () => _openForm(context, PartyRole.employee),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                if (state.status == PartiesStatus.loading ||
                    state.status == PartiesStatus.saving)
                  const LinearProgressIndicator(),
                if (state.status == PartiesStatus.failure)
                  _MessageCard(message: state.message ?? 'خطای ناشناخته'),
                if (state.status == PartiesStatus.empty)
                  const _MessageCard(
                      message: 'هنوز شخصی برای نمایش ثبت نشده است.'),
                for (final item in state.items)
                  Card(
                    child: ListTile(
                      leading: AsoudIconBox(
                        icon: item.roles.contains(PartyRole.employee)
                            ? Icons.badge_outlined
                            : Icons.inventory_2_outlined,
                        color: item.roles.contains(PartyRole.employee)
                            ? AsoudColors.primary
                            : AsoudColors.success,
                      ),
                      title: Text(item.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(item.mobile?.isNotEmpty == true
                          ? item.mobile!
                          : 'اطلاعات تماس ثبت نشده'),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PartyDetailPage(profile: item),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Future<void> _openForm(BuildContext context, PartyRole role) async {
    final saved =
        await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => PartyFormPage(company: widget.company, initialRole: role),
    ));
    if (saved == true && context.mounted) {
      context.read<PartiesCubit>().load(role: filter);
    }
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              AsoudIconBox(icon: icon, color: color),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AsoudColors.muted)),
        ),
      );
}
