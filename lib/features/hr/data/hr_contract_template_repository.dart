import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';

abstract class HrContractTemplateRepository {
  Future<HrContractTemplate> getTemplate({
    required String company,
    String? id,
  });

  Future<HrContractTemplate> saveDraft({
    required String company,
    required HrContractTemplate template,
  });

  Future<HrContractTemplate> publishTemplate({
    required String company,
    required HrContractTemplate template,
  });

  Future<List<HrPayrollFieldOption>> getPayrollFields({
    required String company,
  });

  Future<Map<String, List<String>>> getAvailableCatalogFields({
    required String company,
  });
}

class FakeHrContractTemplateRepository implements HrContractTemplateRepository {
  FakeHrContractTemplateRepository({HrContractTemplate? initial})
      : _template = initial ?? HrContractTemplate.defaultTemplate();

  HrContractTemplate _template;

  HrContractTemplate get currentTemplate => _template;

  @override
  Future<HrContractTemplate> getTemplate({
    required String company,
    String? id,
  }) async {
    return _template;
  }

  @override
  Future<HrContractTemplate> saveDraft({
    required String company,
    required HrContractTemplate template,
  }) async {
    _template = template.copyWith(isPublished: false);
    return _template;
  }

  @override
  Future<HrContractTemplate> publishTemplate({
    required String company,
    required HrContractTemplate template,
  }) async {
    _template = template.copyWith(
      version: template.version + 1,
      isPublished: true,
    );
    return _template;
  }

  @override
  Future<List<HrPayrollFieldOption>> getPayrollFields({
    required String company,
  }) async {
    return defaultPayrollFields;
  }

  @override
  Future<Map<String, List<String>>> getAvailableCatalogFields({
    required String company,
  }) async {
    return defaultCatalogGroups;
  }
}

class ServerHrContractTemplateRepository implements HrContractTemplateRepository {
  ServerHrContractTemplateRepository(this.client);
  final FrappeApiClient client;

  @override
  Future<HrContractTemplate> getTemplate({
    required String company,
    String? id,
  }) async {
    try {
      final res = await client.callAsoudMethod(
        'asoud_erp.api.v1.employment_contracts.get_contract_template',
        data: {'company': company, if (id != null) 'template_id': id},
      );
      if (res is Map<String, dynamic>) {
        final data = res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
        return HrContractTemplate.fromJson(data);
      }
    } catch (_) {
      // Fallback to default template if not created yet
    }
    return HrContractTemplate.defaultTemplate(company: company);
  }

  @override
  Future<HrContractTemplate> saveDraft({
    required String company,
    required HrContractTemplate template,
  }) async {
    final res = await client.callAsoudMethod(
      'asoud_erp.api.v1.employment_contracts.save_contract_template',
      data: {
        'company': company,
        'clauses': template.clauses.map((c) => c.toJson()).toList(),
        'salary_rows': template.payrollRows.map((r) => r.toJson()).toList(),
        'title': template.title,
        'expected_version': template.version,
      },
    );
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      return HrContractTemplate.fromJson(data);
    }
    return template;
  }

  @override
  Future<HrContractTemplate> publishTemplate({
    required String company,
    required HrContractTemplate template,
  }) async {
    final res = await client.callAsoudMethod(
      'asoud_erp.api.v1.employment_contracts.publish_contract_template',
      data: {
        'company': company,
        'template_id': template.id,
        'expected_version': template.version,
      },
    );
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      return HrContractTemplate.fromJson(data);
    }
    return template.copyWith(
      version: template.version + 1,
      isPublished: true,
    );
  }

  @override
  Future<List<HrPayrollFieldOption>> getPayrollFields({
    required String company,
  }) async {
    try {
      final res = await client.callAsoudMethod(
        'asoud_erp.api.v1.employment_contracts.get_contract_field_catalog',
        data: {'company': company},
      );
      if (res is Map<String, dynamic>) {
        final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
        final categories = data['categories'] as List<dynamic>?;
        if (categories != null) {
          for (final cat in categories) {
            if (cat is Map && cat['key'] == 'payroll') {
              final fields = cat['fields'] as List<dynamic>?;
              if (fields != null) {
                return fields
                    .whereType<Map<String, dynamic>>()
                    .map((item) => HrPayrollFieldOption(
                          id: '${item['id'] ?? ''}',
                          label: '${item['label'] ?? ''}',
                          group: '${item['group'] ?? 'مزایا'}',
                        ))
                    .toList();
              }
            }
          }
        }
      }
    } catch (_) {}
    return defaultPayrollFields;
  }

  @override
  Future<Map<String, List<String>>> getAvailableCatalogFields({
    required String company,
  }) async {
    try {
      final res = await client.callAsoudMethod(
        'asoud_erp.api.v1.employment_contracts.get_contract_field_catalog',
        data: {'company': company},
      );
      if (res is Map<String, dynamic>) {
        final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
        final categories = data['categories'] as List<dynamic>?;
        if (categories != null) {
          final result = <String, List<String>>{};
          for (final cat in categories) {
            if (cat is Map) {
              final key = '${cat['key'] ?? ''}';
              final fields = (cat['fields'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((f) => '${f['label'] ?? f['id'] ?? ''}')
                  .toList() ?? [];
              result[key] = fields;
            }
          }
          if (result.isNotEmpty) return result;
        }
      }
    } catch (_) {}
    return defaultCatalogGroups;
  }
}
