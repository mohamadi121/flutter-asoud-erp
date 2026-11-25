part of 'personnel_page.dart';

class PersonnelActivityFeedSlot extends StatelessWidget {
  const PersonnelActivityFeedSlot({
    required this.records,
    required this.onRecord,
    super.key,
  });

  final List<Map> records;
  final ValueChanged<Map> onRecord;

  @override
  Widget build(BuildContext context) {
    // Only include authorized events that have an actual detail route.
    final recent = records.where((row) =>
        const {'document', 'history', 'evaluation'}.contains(row['kind']) &&
        '${row['name'] ?? ''}'.isNotEmpty &&
        '${row['title'] ?? ''}'.trim().isNotEmpty &&
        DateTime.tryParse('${row['record_date'] ?? ''}') != null).toList()
      ..sort((a, b) => '${b['record_date']}'.compareTo('${a['record_date']}'));
    final shown = recent.take(3);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.history_rounded, color: _blue, size: 17),
            const SizedBox(width: 6),
            const Expanded(child: Text('آخرین فعالیت‌های مهم',
                style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800))),
            if (shown.isNotEmpty)
              Text('${toPersianDigits(shown.length)} مورد اخیر',
                  style: const TextStyle(color: AsoudColors.muted, fontSize: 10)),
          ]),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('فعالیتی ثبت نشده است', style: TextStyle(fontSize: 11)),
            ),
          for (final record in shown)
            _ActivityRow(record: record, onTap: () => onRecord(record)),
        ]),
      ),
    );
  }
}

class _CapActivity extends StatelessWidget {
  const _CapActivity({required this.activity});
  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final color = capEventColor(activity.kind);
    final caption = [
      if (activity.details.isNotEmpty) capDetails(activity.details),
      if (activity.by.isNotEmpty) 'توسط ${activity.by}',
    ].join(' · ');

    return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(capEventIcon(activity.kind, activity.title),
                      size: 18, color: color)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(activity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    if (caption.isNotEmpty)
                      Text(caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                  ])),
              const SizedBox(width: 6),
              capValueText(formatJalaliDateTimeIso(activity.date),
                  maxLines: 1,
                  style:
                      const TextStyle(fontSize: 10, color: AsoudColors.muted)),
            ])));
  }
}

class _ActivityFeedPage extends StatelessWidget {
  const _ActivityFeedPage({required this.file});
  final PersonnelFile file;

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, 'آخرین فعالیت‌ها'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (file.activity.isEmpty) const Text('هنوز فعالیتی ثبت نشده است.'),
            for (final activity in file.activity)
              _CapActivity(activity: activity),
          ])));
}
