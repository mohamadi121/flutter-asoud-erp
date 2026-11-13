/// Optional capability for task repositories that can send the approval
/// stage's supplementary form values (contract C6) as a separate
/// `supplementary_values` argument, kept apart from the decision `response`.
abstract interface class WorkflowTaskSupplementaryRepository {
  Future<void> completeTaskWithSupplementary({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
    required Map<String, dynamic> supplementaryValues,
  });

  Future<void> saveDraftWithSupplementary(
    String task,
    Map<String, dynamic> values, {
    required Map<String, dynamic> supplementaryValues,
  });
}
