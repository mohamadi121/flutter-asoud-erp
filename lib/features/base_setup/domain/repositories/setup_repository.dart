import '../entities/accounting_setup.dart';
import '../entities/setup_status.dart';

abstract interface class SetupRepository {
  Future<SetupStatus> getStatus({String? company});
  Future<SetupStatus> saveAccounting(String company, AccountingSetup setup);
  Future<SetupStatus> saveEnabledRoles(String company, Set<String> roles);
}
