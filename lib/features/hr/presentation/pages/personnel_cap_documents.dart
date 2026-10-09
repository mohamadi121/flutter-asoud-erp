part of 'personnel_page.dart';

/// Capability (B): Documents with expiry & Direct manager & Service length.
class PersonnelManagerAndTenureSlot extends StatelessWidget {
  const PersonnelManagerAndTenureSlot({
    required this.file,
    required this.repository,
    this.fileRepository,
    super.key,
  });

  final PersonnelFile? file;
  final PersonnelRepository repository;
  final PersonnelFileRepository? fileRepository;

  void _openManager(BuildContext context, String managerId) {
    if (managerId.isEmpty) return;
    Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => PersonnelDetailPage(
                id: managerId,
                repository: repository,
                fileRepository: fileRepository)));
  }

  @override
  Widget build(BuildContext context) {
    if (file == null) return const SizedBox.shrink();
    final manager = file?.organization.reportsTo;
    final hasManagerId = manager != null && manager.employee.isNotEmpty;
    final managerName = capText(manager?.name);
    final serviceLength =
        file != null ? capText(serviceLengthLabel(file!)) : capEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
            child: _SummaryTile(
                title: 'مدیر مستقیم',
                value: managerName,
                icon: Icons.supervisor_account_outlined,
                color: const Color(0xFF087CFF),
                onTap: hasManagerId
                    ? () => _openManager(context, manager.employee)
                    : null)),
        const SizedBox(width: 10),
        Expanded(
            child: _SummaryTile(
                title: 'سابقه خدمت',
                value: serviceLength,
                icon: Icons.timelapse,
                color: const Color(0xFF04B985),
                onTap: null)),
      ]),
    );
  }
}

class PersonnelDocumentsSlot extends StatefulWidget {
  const PersonnelDocumentsSlot({
    required this.file,
    required this.personnel,
    super.key,
  });

  final PersonnelFile? file;
  final PersonnelRepository personnel;

  @override
  State<PersonnelDocumentsSlot> createState() => _PersonnelDocumentsSlotState();
}

class _PersonnelDocumentsSlotState extends State<PersonnelDocumentsSlot> {
  String selectedCategory = '';

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    if (file == null) return const SizedBox.shrink();

    final docs = file.documents
        .where((doc) =>
            selectedCategory.isEmpty ||
            doc.category.toLowerCase() == selectedCategory.toLowerCase())
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 4),
      const Text('مدارک پرونده',
          style: TextStyle(
              color: _ink, fontSize: 14, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final key in ['', ...personnelDocumentCategories])
              Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                      label: Text(
                          key.isEmpty ? 'همه' : documentCategoryLabel(key)),
                      selected: selectedCategory == key,
                      selectedColor: AsoudColors.primary.withValues(alpha: .15),
                      onSelected: (_) =>
                          setState(() => selectedCategory = key))),
          ])),
      const SizedBox(height: 12),
      if (docs.isEmpty)
        const Text('مدرکی ثبت نشده است.')
      else
        for (final document in docs)
          _CapDocumentRow(
              document: document,
              onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _CapDocumentPage(
                          file: file,
                          document: document,
                          personnel: widget.personnel)))),
    ]);
  }
}

class _CapDocumentRow extends StatelessWidget {
  const _CapDocumentRow({required this.document, required this.onTap});
  final PersonnelDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final docNumber = capText(document.documentNumber);
    return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.insert_drive_file_outlined,
                          color: AsoudColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(document.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            if (docNumber != capEmpty)
                              capValueText(docNumber,
                                  style: const TextStyle(fontSize: 11)),
                            Text('انقضا: ${capDate(document.expiryDate)}',
                                style: const TextStyle(fontSize: 11)),
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              CapChip(document.categoryLabel),
                              CapChip(document.statusLabel,
                                  color: documentStatusColor(document)),
                            ]),
                          ])),
                      const Icon(Icons.chevron_left, size: 20),
                    ]))));
  }
}

class _CapDocumentPage extends StatelessWidget {
  const _CapDocumentPage(
      {required this.file, required this.document, required this.personnel});
  final PersonnelFile file;
  final PersonnelDocument document;
  final PersonnelRepository personnel;

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, 'جزئیات مدرک'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            CapRows(values: {
              'نوع': document.categoryLabel,
              'شماره': capText(document.documentNumber),
              'تاریخ صدور': capDate(document.issueDate),
              'تاریخ انقضا': capDate(document.expiryDate),
              'وضعیت': document.statusLabel,
              'فایل': capText(document.filename),
            }),
            OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: const Text('مشاهده/دانلود فایل'),
                onPressed: () => savePersonnelFileAttachment(context, () async {
                      final result = await personnel.record(document.id);
                      return (
                        filename: '${result['filename'] ?? document.filename}',
                        contentBase64: '${result['file'] ?? ''}'
                      );
                    })),
          ])));
}
