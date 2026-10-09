part of 'personnel_page.dart';

/// Hook slot for Capability (C): Latest activities feed.
///
/// Implemented by worker (C) in this file.
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
    // Slot reserved for recent activity feed and full view navigation.
    // Falls back to existing records rendering until worker (C) ports the feed.
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
