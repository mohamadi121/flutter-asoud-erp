// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/hr_models.dart';
import '../../domain/hr_repository.dart';
import '../cubit/hr_cubit.dart';

class HrHomePage extends StatelessWidget {
  const HrHomePage({required this.company, super.key});
  final String company;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            HrCubit(context.read<HrRepository>(), company)..loadDashboard(),
        child: _HrHome(company: company),
      );
}

class _HrHome extends StatelessWidget {
  const _HrHome({required this.company});
  final String company;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'منابع انسانی',
            subtitle: 'پروفایل، تیم، گزارش کار و مکاتبات'),
        body: SafeArea(child: BlocBuilder<HrCubit, HrState>(
          builder: (context, state) {
            if (state.status == HrStatus.loading && state.dashboard == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.dashboard == null) {
              return _Error(onRetry: context.read<HrCubit>().loadDashboard);
            }
            final data = state.dashboard!;
            return RefreshIndicator(
              onRefresh: context.read<HrCubit>().loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ProfileCard(employee: data.employee),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.55,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      _Metric(
                          'گزارش امروز',
                          data.todayReportStatus ?? 'ثبت نشده',
                          Icons.today_outlined,
                          AsoudColors.primary),
                      _Metric('کارتابل من', '${data.pendingTasks} مورد',
                          Icons.assignment_ind_outlined, AsoudColors.warning),
                      _Metric(
                          'مکاتبات جدید',
                          '${data.unreadCommunications} مورد',
                          Icons.mail_outline,
                          AsoudColors.purple),
                      _Metric('اعلان‌ها', '${data.unreadNotifications} مورد',
                          Icons.notifications_none, AsoudColors.success),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AsoudSectionTitle(title: 'خدمات منابع انسانی'),
                  _Action(
                      'پروفایل من',
                      'اطلاعات کاری و مدیر مستقیم',
                      Icons.account_circle_outlined,
                      AsoudColors.primary,
                      () => _push(
                          context, HrProfilePage(employee: data.employee))),
                  _Action(
                      'تیم و ساختار سازمانی',
                      'همکاران، واحدها و مسیر سازمانی',
                      Icons.account_tree_outlined,
                      AsoudColors.cyan,
                      () => _push(context, HrTeamPage(company: company))),
                  _Action(
                      'گزارش کار روزانه',
                      'فعالیت‌ها، پیش‌نویس و بازخورد',
                      Icons.fact_check_outlined,
                      AsoudColors.success,
                      () => _push(context, WorkReportsPage(company: company))),
                  _Action(
                      'مکاتبات داخلی',
                      'نامه، درخواست و اقدام سازمانی',
                      Icons.mark_email_unread_outlined,
                      AsoudColors.purple,
                      () => _push(
                          context, HrCommunicationsPage(company: company))),
                  _Action(
                      'اعلان‌های منابع انسانی',
                      'رویدادها و مهلت‌های مهم',
                      Icons.notifications_active_outlined,
                      AsoudColors.warning,
                      () => _push(
                          context, HrNotificationsPage(company: company))),
                ],
              ),
            );
          },
        )),
      );
  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
}

class HrProfilePage extends StatelessWidget {
  const HrProfilePage({required this.employee, super.key});
  final HrEmployee employee;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'پروفایل من', subtitle: 'اطلاعات پرسنلی و سازمانی'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _ProfileCard(employee: employee),
          const SizedBox(height: 12),
          for (final row in [
            ('کد پرسنلی', employee.id),
            ('شرکت', employee.company),
            ('واحد', employee.department),
            ('سمت', employee.designation),
            ('مدیر مستقیم', employee.manager),
            ('تلفن', employee.phone),
            ('ایمیل', employee.email),
            ('وضعیت همکاری', employee.status)
          ])
            Card(
                child: ListTile(
                    title: Text(row.$1),
                    trailing: Text(row.$2.isEmpty ? 'ثبت نشده' : row.$2))),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('درخواست اصلاح در کارتابل ثبت خواهد شد.')),
            ),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('درخواست اصلاح اطلاعات'),
          ),
        ]),
      );
}

class HrTeamPage extends StatelessWidget {
  const HrTeamPage({required this.company, super.key});
  final String company;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            HrCubit(context.read<HrRepository>(), company)..loadTeam(),
        child: Scaffold(
          appBar: const AsoudHeader(
              title: 'تیم من', subtitle: 'پرسنل و ساختار سازمانی'),
          body: BlocBuilder<HrCubit, HrState>(builder: (context, state) {
            if (state.status == HrStatus.loading)
              return const Center(child: CircularProgressIndicator());
            return ListView(padding: const EdgeInsets.all(16), children: [
              const TextField(
                  decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'جست‌وجوی همکار یا واحد...')),
              const SizedBox(height: 10),
              if (state.team.isEmpty)
                const _Empty('پرسنلی برای نمایش وجود ندارد'),
              ...state.team.map((person) => Card(
                      child: ListTile(
                    leading: const AsoudIconBox(
                        icon: Icons.person_outline, color: AsoudColors.primary),
                    title: Text(person.name),
                    subtitle:
                        Text('${person.designation} • ${person.department}'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => HrProfilePage(employee: person))),
                  ))),
            ]);
          }),
        ),
      );
}

class WorkReportsPage extends StatelessWidget {
  const WorkReportsPage({required this.company, super.key});
  final String company;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            HrCubit(context.read<HrRepository>(), company)..loadReports(),
        child: Builder(
            builder: (context) => Scaffold(
                  appBar: const AsoudHeader(
                      title: 'گزارش کار روزانه',
                      subtitle: 'ثبت فعالیت و بازخورد مدیر'),
                  floatingActionButton: FloatingActionButton.extended(
                      onPressed: () => _add(context),
                      icon: const Icon(Icons.add),
                      label: const Text('گزارش امروز')),
                  body: BlocBuilder<HrCubit, HrState>(
                      builder: (context, state) => ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                            children: state.reports.isEmpty
                                ? const [_Empty('هنوز گزارش کاری ثبت نشده است')]
                                : state.reports
                                    .map((report) => Card(
                                        child: ListTile(
                                            leading: const AsoudIconBox(
                                                icon: Icons.fact_check_outlined,
                                                color: AsoudColors.success),
                                            title: Text(
                                                '${report.date.year}/${report.date.month}/${report.date.day}'),
                                            subtitle: Text(
                                                '${report.totalMinutes} دقیقه • ${report.status}'))))
                                    .toList(),
                          )),
                )),
      );
  Future<void> _add(BuildContext context) async {
    final title = TextEditingController();
    final duration = TextEditingController();
    final result = await showModalBottomSheet<WorkActivity>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('افزودن فعالیت',
              style: TextStyle(fontWeight: FontWeight.w900)),
          TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'عنوان فعالیت *')),
          const SizedBox(height: 8),
          TextField(
              controller: duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مدت به دقیقه')),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => title.text.trim().isEmpty
                    ? null
                    : Navigator.pop(
                        context,
                        WorkActivity(
                            title: title.text.trim(),
                            durationMinutes: int.tryParse(duration.text) ?? 0)),
                child: const Text('ذخیره پیش‌نویس'),
              )),
        ]),
      ),
    );
    if (result != null && context.mounted) {
      await context
          .read<HrCubit>()
          .saveReport(WorkReport(date: DateTime.now(), activities: [result]));
    }
  }
}

class HrCommunicationsPage extends StatelessWidget {
  const HrCommunicationsPage({required this.company, super.key});
  final String company;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => HrCubit(context.read<HrRepository>(), company)
          ..loadCommunications(),
        child: Builder(
            builder: (context) => Scaffold(
                  appBar: const AsoudHeader(
                      title: 'مکاتبات داخلی',
                      subtitle: 'دریافتی، ارسالی و اقدام‌ها'),
                  floatingActionButton: FloatingActionButton.extended(
                      onPressed: () => _compose(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('مکاتبه جدید')),
                  body: BlocBuilder<HrCubit, HrState>(
                      builder: (context, state) => ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                            children: state.communications.isEmpty
                                ? const [
                                    _Empty('مکاتبه‌ای برای نمایش وجود ندارد')
                                  ]
                                : state.communications
                                    .map((item) => Card(
                                        child: ListTile(
                                            leading: AsoudIconBox(
                                                icon: item.confidential
                                                    ? Icons.lock_outline
                                                    : Icons.mail_outline,
                                                color: AsoudColors.purple),
                                            title: Text(item.subject),
                                            subtitle: Text(
                                                '${item.sender} • ${item.priority}'))))
                                    .toList(),
                          )),
                )),
      );
  Future<void> _compose(BuildContext context) async {
    final recipient = TextEditingController(),
        subject = TextEditingController(),
        body = TextEditingController();
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('ایجاد مکاتبه',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              TextField(
                  controller: recipient,
                  decoration: const InputDecoration(labelText: 'گیرنده *')),
              TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'موضوع *')),
              TextField(
                  controller: body,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'متن *')),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () async {
                        if (recipient.text.trim().isEmpty ||
                            subject.text.trim().isEmpty ||
                            body.text.trim().isEmpty) return;
                        await context.read<HrCubit>().sendCommunication(
                            HrCommunication(
                                subject: subject.text.trim(),
                                content: body.text.trim(),
                                recipients: [recipient.text.trim()]));
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('ارسال مکاتبه'))),
            ])));
  }
}

class HrNotificationsPage extends StatelessWidget {
  const HrNotificationsPage({required this.company, super.key});
  final String company;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            HrCubit(context.read<HrRepository>(), company)..loadNotifications(),
        child: Scaffold(
            appBar: const AsoudHeader(
                title: 'اعلان‌ها', subtitle: 'رویدادهای منابع انسانی'),
            body: BlocBuilder<HrCubit, HrState>(
                builder: (context, state) => ListView(
                    padding: const EdgeInsets.all(16),
                    children: state.notifications.isEmpty
                        ? const [_Empty('اعلان جدیدی وجود ندارد')]
                        : state.notifications
                            .map((item) => Card(
                                child: ListTile(
                                    leading: const AsoudIconBox(
                                        icon:
                                            Icons.notifications_active_outlined,
                                        color: AsoudColors.warning),
                                    title:
                                        Text(item['subject']?.toString() ?? ''),
                                    subtitle: Text(
                                        item['creation']?.toString() ?? ''))))
                            .toList()))),
      );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.employee});
  final HrEmployee employee;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF3F7FF),
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const CircleAvatar(radius: 27, child: Icon(Icons.person)),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(employee.name,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('${employee.designation} • ${employee.department}',
              style: const TextStyle(fontSize: 9, color: AsoudColors.muted)),
          Text(employee.company,
              style: const TextStyle(fontSize: 9, color: AsoudColors.primary))
        ]))
      ]));
}

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value, this.icon, this.color);
  final String title, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        AsoudIconBox(icon: icon, color: color, size: 34),
        const SizedBox(width: 7),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Text(title,
                  style:
                      const TextStyle(fontSize: 8, color: AsoudColors.muted)),
              Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800))
            ]))
      ]));
}

class _Action extends StatelessWidget {
  const _Action(this.title, this.subtitle, this.icon, this.color, this.onTap);
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          onTap: onTap,
          leading: AsoudIconBox(icon: icon, color: color),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 9)),
          trailing: const Icon(Icons.chevron_left)));
}

class _Empty extends StatelessWidget {
  const _Empty(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        const AsoudIconBox(
            icon: Icons.inbox_outlined, color: AsoudColors.muted, size: 50),
        const SizedBox(height: 9),
        Text(title, style: const TextStyle(color: AsoudColors.muted))
      ]));
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child:
          OutlinedButton(onPressed: onRetry, child: const Text('تلاش دوباره')));
}
