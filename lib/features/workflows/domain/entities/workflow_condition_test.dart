/// One row of a server-side condition dry run.
class WorkflowConditionTestRow {
  const WorkflowConditionTestRow({required this.id, this.result, this.error});
  final String id;
  final bool? result;
  final String? error;
}

/// The outcome of a server-side condition dry run.
class WorkflowConditionTestResult {
  const WorkflowConditionTestResult({required this.result, required this.rows});
  final bool? result;
  final List<WorkflowConditionTestRow> rows;
}

/// Thrown when the active repository cannot run a server-side condition test
/// (older server, or offline preview without a signed-in backend). The form
/// falls back to the local structural check for this case only.
class ConditionTestUnsupportedException implements Exception {
  const ConditionTestUnsupportedException();
}

/// A repository that can evaluate a condition stage server-side against sample
/// values. Implemented by the signed-in repository; the offline preview
/// delegates to it or reports the feature as unsupported.
abstract interface class WorkflowConditionTestRepository {
  Future<WorkflowConditionTestResult> testWorkflowCondition({
    required String definition,
    required String stage,
    required Map<String, dynamic> config,
    required Map<String, dynamic> samples,
  });
}
