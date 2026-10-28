import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';

abstract class HrContractTemplateRepository {
  String fieldTag(String group, String label);
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

  @override
  String fieldTag(String group, String label) => group == 'personnel' ? '[$label پرسنل]' : '[$label]';

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
  final Map<String, int> _draftVersions = {};
  final Map<String, String> _fieldIds = {};

  @override
  String fieldTag(String group, String label) {
    final id = _fieldIds['$group.$label'];
    if (id == null) throw const FormatException('فیلد انتخاب‌شده در کاتالوگ موجود نیست.');
    return '{{$id}}';
  }

  @override
  Future<HrContractTemplate> getTemplate({
    required String company,
    String? id,
  }) async {
      final res = await client.callAsoudMethod(
        'asoud_erp.api.v1.employment_contracts.get_contract_template',
        data: {'company': company, if (id != null) 'template_id': id},
      );
      if (res is Map<String, dynamic>) {
        final data = res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
        _draftVersions[company] = (data['draft_version'] as num?)?.toInt() ?? 1;
        return HrContractTemplate.fromJson(data);
      }
    throw const FormatException('پاسخ قالب قرارداد معتبر نیست.');
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
        'clauses': [for (var i = 0; i < template.clauses.length; i++) {...template.clauses[i].toJson(), 'id': '${template.clauses[i].id}', 'order': i + 1}],
        'salary_rows': template.payrollRows.map((r) => {...r.toJson(), 'id': '${r.id}', 'period': r.period == 'annual' ? 'yearly' : r.period}).toList(),
        'title': template.title,
        'expected_version': _draftVersions[company] ?? 0,
      },
    );
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      _draftVersions[company] = (data['draft_version'] as num?)?.toInt() ?? 1;
      return HrContractTemplate.fromJson({...data, 'version': template.version, 'has_draft': true});
    }
    throw const FormatException('پاسخ ذخیره قالب معتبر نیست.');
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
        'expected_version': _draftVersions[company] ?? 0,
      },
    );
    if (res is Map<String, dynamic>) {
      return getTemplate(company: company, id: template.id);
    }
    throw const FormatException('پاسخ انتشار قالب معتبر نیست.');
  }

  @override
  Future<List<HrPayrollFieldOption>> getPayrollFields({
    required String company,
  }) async {
      final res = await client.callAsoudMethod(
        'asoud_erp.api.v1.employment_contracts.get_contract_field_catalog',
        data: {'company': company},
      );
      if (res is Map<String, dynamic>) {
        final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
        final categories = data['categories'] as List<dynamic>?;
        if (categories != null) {
          for (final cat in categories) {
            if (cat is Map && cat['key'] == 'payroll' && cat['authorized'] == true) {
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
    return const [];
  }

  @override
  Future<Map<String, List<String>>> getAvailableCatalogFields({
    required String company,
  }) async {
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
            if (cat is Map && cat['authorized'] != false) {
              final key = '${cat['key'] ?? ''}';
              final fields = (cat['fields'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((f) {
                    final label = '${f['label'] ?? ''}';
                    _fieldIds['$key.$label'] = '${f['id']}';
                    return label;
                  })
                  .toList() ?? [];
              result[key] = fields;
            }
          }
          if (result.isNotEmpty) return result;
        }
      }
    return const {};
  }
}
