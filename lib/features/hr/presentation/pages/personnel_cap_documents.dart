part of 'personnel_page.dart';

/// Hook slot for Capability (B): Documents with expiry & Direct manager & Service length.
///
/// Implemented by worker (B) in this file.
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

  @override
  Widget build(BuildContext context) {
    // Slot reserved for direct manager card and service length badge.
    return const SizedBox.shrink();
  }
}

class PersonnelDocumentsSlot extends StatelessWidget {
  const PersonnelDocumentsSlot({
    required this.file,
    required this.personnel,
    super.key,
  });

  final PersonnelFile? file;
  final PersonnelRepository personnel;

  @override
  Widget build(BuildContext context) {
    // Slot reserved for documents list with category filters and expiry statuses.
    return const SizedBox.shrink();
  }
}
