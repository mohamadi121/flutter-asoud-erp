part of 'personnel_page.dart';

/// Hook slot for Capability (A): Contracts & Promotion.
///
/// Implemented by worker (A) in this file.
class PersonnelContractsSlot extends StatelessWidget {
  const PersonnelContractsSlot({
    required this.file,
    required this.profileId,
    required this.canEdit,
    this.repository,
    this.onRefresh,
    super.key,
  });

  final PersonnelFile? file;
  final String profileId;
  final bool canEdit;
  final PersonnelFileRepository? repository;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    // Slot reserved for contracts list, chips and addition form.
    return const SizedBox.shrink();
  }
}

class PersonnelPromotionSlot extends StatelessWidget {
  const PersonnelPromotionSlot({
    required this.profileId,
    required this.canEdit,
    required this.personnel,
    this.repository,
    this.onPromoted,
    super.key,
  });

  final String profileId;
  final bool canEdit;
  final PersonnelRepository personnel;
  final PersonnelFileRepository? repository;
  final VoidCallback? onPromoted;

  @override
  Widget build(BuildContext context) {
    // Slot reserved for promotion / change-of-role action and form.
    return const SizedBox.shrink();
  }
}
