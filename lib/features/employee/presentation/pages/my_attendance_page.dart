import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/self_service_repository.dart';

const attendanceStatusLabels = {
  'Present': 'حاضر',
  'Absent': 'غایب',
  'On Leave': 'مرخصی',
  'Half Day': 'نیم‌روز',
  'Work From Home': 'دورکاری',
};

String _iso(DateTime value) => value.toIso8601String().substring(0, 10);

/// «حضور و غیاب»: check in/out now, this month's attendance and recent logs.
class MyAttendancePage extends StatefulWidget {
  const MyAttendancePage({required this.repository, this.today, super.key});
  final SelfServiceRepository repository;
  final DateTime? today;

  @override
  State<MyAttendancePage> createState() => _MyAttendancePageState();
}

class _MyAttendancePageState extends State<MyAttendancePage> {
  late Future<
          ({List<Map<String, dynamic>> days, List<Map<String, dynamic>> logs})>
      future = _load();
  bool saving = false;

  DateTime get _today => widget.today ?? DateTime.now();

  Future<({List<Map<String, dynamic>> days, List<Map<String, dynamic>> logs})>
      _load() async {
    final today = _today;
    final first = DateTime(today.year, today.month);
    final days = await widget.repository.attendance(_iso(first), _iso(today));
    final logs = await widget.repository.checkins();
    return (days: days, logs: logs);
  }

  Future<void> _checkin(String logType) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.repository.checkin(logType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(logType == 'IN' ? 'ورود ثبت شد.' : 'خروج ثبت شد.')));
      setState(() {
        future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.message
              : 'ثبت انجام نشد؛ اتصال را بررسی کنید.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const AsoudHeader(title: 'حضور و غیاب'),
          body: FutureBuilder(
            future: future,
            builder: (context, snapshot) {
              final logs = snapshot.data?.logs ?? const [];
              final last = logs.isEmpty ? null : logs.first;
              return ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(formatJalaliLong(_today),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                              last == null
                                  ? 'امروز ورودی ثبت نشده است.'
                                  : 'آخرین ثبت: ${last['log_type'] == 'OUT' ? 'خروج' : 'ورود'} · '
                                      '${formatJalaliDateTimeIso('${last['time']}')}',
                              style: const TextStyle(
                                  fontSize: 12, color: AsoudColors.muted)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: saving ? null : () => _checkin('IN'),
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('ثبت ورود'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    saving ? null : () => _checkin('OUT'),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('ثبت خروج'),
                              ),
                            ),
                          ]),
                        ]),
                  ),
                ),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  TextButton(
                      onPressed: () => setState(() {
                            future = _load();
                          }),
                      child: Text(snapshot.error is ApiException
                          ? '${(snapshot.error as ApiException).message} · تلاش دوباره'
                          : 'دریافت حضور ممکن نشد؛ تلاش دوباره'))
                else if (!snapshot.hasData)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  const AsoudSectionTitle(title: 'حضور این ماه'),
                  if (snapshot.data!.days.isEmpty)
                    const Text('هنوز حضوری برای این ماه ثبت نشده است.',
                        style: TextStyle(color: AsoudColors.muted)),
                  for (final day in snapshot.data!.days)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatJalaliIso('${day['attendance_date']}')),
                      trailing: Text(
                          attendanceStatusLabels['${day['status']}'] ??
                              '${day['status']}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 12),
                  const AsoudSectionTitle(title: 'ثبت‌های اخیر'),
                  for (final log in logs.take(20))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          log['log_type'] == 'OUT'
                              ? Icons.logout_rounded
                              : Icons.login_rounded,
                          color: AsoudColors.primary),
                      title: Text(log['log_type'] == 'OUT' ? 'خروج' : 'ورود'),
                      trailing: Text(formatJalaliDateTimeIso('${log['time']}')),
                    ),
                ],
              ]);
            },
          ),
        ),
      );
}
