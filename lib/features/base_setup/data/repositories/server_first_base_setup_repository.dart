import '../../../../core/offline/local_database_store.dart';
import '../../../../core/offline/local_record.dart';
import '../../../../core/offline/offline_failure.dart';
import '../../domain/entities/accounting_setup.dart';
import '../../domain/repositories/base_setup_repository.dart';

class ServerFirstBaseSetupRepository implements BaseSetupRepository {
  ServerFirstBaseSetupRepository(
    this._remote, {
    LocalRecordStore? local,
  }) : _local = local ?? LocalDatabaseStore.instance;

  final BaseSetupRepository _remote;
  final LocalRecordStore _local;

  @override
  Future<CompanyAccountingSettings> getSettings(String company) => _read(
        id: _settingsId(company),
        remote: () => _remote.getSettings(company),
        decode: _settingsFromPayload,
        encode: _settingsPayload,
        entityType: 'company_accounting_settings',
      );

  @override
  Future<CompanyAccountingSettings> saveSettings(
    String company,
    CompanyAccountingSettings settings,
  ) =>
      _write(
        id: _settingsId(company),
        remote: () => _remote.saveSettings(company, settings),
        draft: settings,
        encode: _settingsPayload,
        entityType: 'company_accounting_settings',
      );

  @override
  Future<AccountCodeSettings> getAccountCodeSettings(String company) => _read(
        id: _codeId(company),
        remote: () => _remote.getAccountCodeSettings(company),
        decode: _codeFromPayload,
        encode: _codePayload,
        entityType: 'account_code_settings',
      );

  @override
  Future<AccountCodeSettings> saveAccountCodeSettings(
    String company,
    AccountCodeSettings settings,
  ) =>
      _write(
        id: _codeId(company),
        remote: () => _remote.saveAccountCodeSettings(company, settings),
        draft: settings,
        encode: _codePayload,
        entityType: 'account_code_settings',
      );

  @override
  Future<List<FiscalYearInfo>> getFiscalYears(String company) async {
    try {
      final remote = await _remote.getFiscalYears(company);
      for (final item in remote) {
        await _saveFiscalYear(company, item, LocalSyncStatus.synced);
      }
      final local = await _localFiscalYears(company);
      final merged = <String, FiscalYearInfo>{
        for (final item in remote) item.id: item
      };
      for (final item in local) {
        merged.putIfAbsent(item.id, () => item);
      }
      return merged.values.toList(growable: false);
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      return _localFiscalYears(company);
    }
  }

  @override
  Future<FiscalYearInfo> createFiscalYear(
    String company,
    int year,
    int month,
    int day,
  ) async {
    final draft = FiscalYearInfo(
      id: '$company-$year',
      year: year.toString(),
      startDate:
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      endDate: '',
    );
    try {
      final saved = await _remote.createFiscalYear(company, year, month, day);
      await _saveFiscalYear(company, saved, LocalSyncStatus.synced);
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _saveFiscalYear(company, draft, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  Future<T> _read<T>({
    required String id,
    required String entityType,
    required Future<T> Function() remote,
    required T Function(Map<String, dynamic>) decode,
    required Map<String, dynamic> Function(T) encode,
  }) async {
    try {
      final value = await remote();
      final existing = await _local.get(id);
      if (existing != null &&
          const {LocalSyncStatus.localOnly, LocalSyncStatus.pendingSync}
              .contains(existing.status)) {
        return decode(existing.payload);
      }
      await _local.save(
        id: id,
        entityType: entityType,
        payload: encode(value),
        status: LocalSyncStatus.synced,
      );
      return value;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final cached = await _local.get(id);
      if (cached == null) rethrow;
      return decode(cached.payload);
    }
  }

  Future<T> _write<T>({
    required String id,
    required String entityType,
    required Future<T> Function() remote,
    required T draft,
    required Map<String, dynamic> Function(T) encode,
  }) async {
    try {
      final saved = await remote();
      await _local.save(
        id: id,
        entityType: entityType,
        payload: encode(saved),
        status: LocalSyncStatus.synced,
      );
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _local.save(
        id: id,
        entityType: entityType,
        payload: encode(draft),
        status: LocalSyncStatus.pendingSync,
      );
      rethrow;
    }
  }

  Future<void> _saveFiscalYear(
    String company,
    FiscalYearInfo item,
    LocalSyncStatus status,
  ) async {
    final id = _fiscalId(company, item.id);
    final existing = await _local.get(id);
    if (status == LocalSyncStatus.synced &&
        existing != null &&
        const {LocalSyncStatus.localOnly, LocalSyncStatus.pendingSync}
            .contains(existing.status)) {
      return;
    }
    await _local.save(
      id: id,
      entityType: 'fiscal_year:$company',
      payload: {
        'id': item.id,
        'year': item.year,
        'start_date': item.startDate,
        'end_date': item.endDate,
        'disabled': item.disabled,
      },
      status: status,
    );
  }

  Future<List<FiscalYearInfo>> _localFiscalYears(String company) async =>
      (await _local.list(entityType: 'fiscal_year:$company'))
          .map((record) => FiscalYearInfo(
                id: record.payload['id']?.toString() ?? '',
                year: record.payload['year']?.toString() ?? '',
                startDate: record.payload['start_date']?.toString() ?? '',
                endDate: record.payload['end_date']?.toString() ?? '',
                disabled: record.payload['disabled'] == true,
              ))
          .toList(growable: false);

  String _settingsId(String company) =>
      'company-settings:${Uri.encodeComponent(company)}';
  String _codeId(String company) =>
      'account-code:${Uri.encodeComponent(company)}';
  String _fiscalId(String company, String id) =>
      'fiscal-year:${Uri.encodeComponent(company)}:${Uri.encodeComponent(id)}';

  Map<String, dynamic> _settingsPayload(CompanyAccountingSettings value) => {
        'money_unit': value.moneyUnit.name,
        'start_day': value.startDay,
        'start_month': value.startMonth,
        'fiscal_year': value.fiscalYear,
        'chart_template': value.chartTemplate.name,
        'auto_detail_codes': value.autoGenerateDetailCodes,
      };

  CompanyAccountingSettings _settingsFromPayload(Map<String, dynamic> value) =>
      CompanyAccountingSettings(
        moneyUnit: MoneyUnit.values.byName(value['money_unit'] as String),
        startDay: (value['start_day'] as num).toInt(),
        startMonth: (value['start_month'] as num).toInt(),
        fiscalYear: (value['fiscal_year'] as num).toInt(),
        chartTemplate:
            ChartTemplate.values.byName(value['chart_template'] as String),
        autoGenerateDetailCodes: value['auto_detail_codes'] == true,
      );

  Map<String, dynamic> _codePayload(AccountCodeSettings value) => {
        'auto_generate': value.autoGenerate,
        'group_digits': value.groupDigits,
        'general_digits': value.generalDigits,
        'ledger_digits': value.ledgerDigits,
      };

  AccountCodeSettings _codeFromPayload(Map<String, dynamic> value) =>
      AccountCodeSettings(
        autoGenerate: value['auto_generate'] == true,
        groupDigits: (value['group_digits'] as num).toInt(),
        generalDigits: (value['general_digits'] as num).toInt(),
        ledgerDigits: (value['ledger_digits'] as num).toInt(),
      );
}
