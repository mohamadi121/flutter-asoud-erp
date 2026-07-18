import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/detail_group.dart';
import '../../domain/repositories/detail_group_repository.dart';
import '../cubit/detail_groups_cubit.dart';

class DetailGroupsPage extends StatelessWidget {
  const DetailGroupsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            DetailGroupsCubit(context.read<DetailGroupRepository>())..load(),
        child: const _DetailGroupsView(),
      );
}

class _DetailGroupsView extends StatelessWidget {
  const _DetailGroupsView();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'گروه تفصیلی شناور',
          subtitle: 'کدهای شناور مستقل از یک حساب معین هستند',
        ),
        body: SafeArea(
          child: BlocBuilder<DetailGroupsCubit, DetailGroupsState>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('گروه‌های اصلی',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 10),
                const _HelpCard(),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: state.status == DetailGroupsStatus.loading
                        ? null
                        : () => _showAddDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('افزودن گروه'),
                  ),
                ),
                TextButton(
                  onPressed: state.status == DetailGroupsStatus.loading
                      ? null
                      : context.read<DetailGroupsCubit>().seedDefaults,
                  child: const Text('ایجاد گروه‌های پیشنهادی استاندارد'),
                ),
                const SizedBox(height: 12),
                if (state.status == DetailGroupsStatus.loading)
                  const LinearProgressIndicator(),
                if (state.status == DetailGroupsStatus.failure)
                  _ErrorCard(
                    message: state.message ?? 'دریافت اطلاعات ممکن نشد.',
                    onRetry: context.read<DetailGroupsCubit>().load,
                  ),
                if (state.status == DetailGroupsStatus.empty)
                  const _EmptyCard(),
                if (state.groups.isNotEmpty) _GroupsGrid(groups: state.groups),
                const SizedBox(height: 10),
                const _FooterHelp(),
              ],
            ),
          ),
        ),
      );

  Future<void> _showAddDialog(BuildContext context) async {
    final title = TextEditingController();
    final code = TextEditingController();
    final cubit = context.read<DetailGroupsCubit>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن گروه تفصیلی'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'عنوان گروه'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'کد گروه'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () async {
              final saved = await cubit.addGroup(code.text, title.text);
              if (saved && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    title.dispose();
    code.dispose();
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تفصیلی شناور چیست؟',
                  style: TextStyle(
                      color: AsoudColors.primary, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text(
                'یک کد تفصیلی می‌تواند به چند حساب معین متصل شود؛ مانند مشتری، بانک، پروژه یا مرکز هزینه.',
                style: TextStyle(fontSize: 9, color: AsoudColors.muted),
              ),
            ]),
      );
}

class _GroupsGrid extends StatelessWidget {
  const _GroupsGrid({required this.groups});
  final List<DetailGroup> groups;
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: groups.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 58,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final item = groups[index];
          final colors = [
            AsoudColors.primary,
            AsoudColors.success,
            AsoudColors.warning,
            AsoudColors.purple,
            AsoudColors.cyan,
            AsoudColors.danger,
          ];
          final color = colors[index % colors.length];
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(children: [
                const Icon(Icons.more_vert_rounded,
                    size: 17, color: AsoudColors.muted),
                Expanded(
                  child: Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(item.code,
                      style: TextStyle(fontSize: 8, color: color)),
                ),
              ]),
            ),
          );
        },
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading:
              const Icon(Icons.cloud_off_rounded, color: AsoudColors.warning),
          title: Text(message, style: const TextStyle(fontSize: 10)),
          trailing:
              TextButton(onPressed: onRetry, child: const Text('تلاش مجدد')),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'هنوز گروهی در ERPNext تعریف نشده است. برای ایجاد مجموعه استاندارد از دکمه بالا استفاده کنید.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AsoudColors.muted),
          ),
        ),
      );
}

class _FooterHelp extends StatelessWidget {
  const _FooterHelp();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'در مراحل بعد می‌توانید اعضای هر گروه تفصیلی را تعریف و به حساب‌های معین مجاز متصل کنید.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, color: AsoudColors.primary),
        ),
      );
}
