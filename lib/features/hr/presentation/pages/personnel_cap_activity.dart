part of 'personnel_page.dart';

/// Capability (C): Latest activities feed.
class PersonnelActivityFeedSlot extends StatelessWidget {
  const PersonnelActivityFeedSlot({
    required this.file,
    required this.records,
    required this.onRecord,
    required this.onRecords,
    super.key,
  });

  final PersonnelFile? file;
  final List<Map> records;
  final ValueChanged<Map> onRecord;
  final ValueChanged<String> onRecords;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
              child: Text('آخرین فعالیت‌ها',
                  style: TextStyle(
                      color: _ink, fontSize: 14, fontWeight: FontWeight.w900))),
          TextButton(
              onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _ActivityFeedPage(file: file!))),
              child: const Text('مشاهده همه', style: TextStyle(fontSize: 10)))
        ]),
        if (file!.activity.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('هنوز فعالیتی ثبت نشده است.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8193BA))))
        else
          for (final activity in file!.activity.take(5))
            _CapActivity(activity: activity),
      ]);
    }

    // Fallback to legacy records if no file object exists
    final recent = [...records]
      ..sort((a, b) => '${b['record_date']}'.compareTo('${a['record_date']}'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(
            child: Text('آخرین فعالیت‌ها',
                style: TextStyle(
                    color: _ink, fontSize: 14, fontWeight: FontWeight.w900))),
        TextButton(
            onPressed: () => onRecords('all'),
            child: const Text('مشاهده همه', style: TextStyle(fontSize: 10)))
      ]),
      if (recent.isEmpty)
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text('هنوز فعالیتی ثبت نشده است.',
                style: TextStyle(fontSize: 11, color: Color(0xFF8193BA)))),
      for (final record in recent.take(4))
        _ActivityRow(record: record, onTap: () => onRecord(record)),
    ]);
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
