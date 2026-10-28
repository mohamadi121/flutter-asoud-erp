import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/data/hr_contract_template_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  test('contract preparation is a read and must never enter the mutation queue', () {
    expect(FrappeClient.isReadOnlyMethod('asoud_erp.api.v1.employment_contracts.prepare_contract'), isTrue);
    expect(FrappeClient.isReadOnlyMethod('asoud_erp.api.v1.employment_contracts.save_contract_draft'), isFalse);
  });
  const prefix = 'asoud_erp.api.v1.employment_contracts.';
  late _Client client;
  late ServerHrContractsRepository repository;
  setUp(() {
    client = _Client();
    repository = ServerHrContractsRepository(client);
  });
  // Keys are from list_contracts/get_contract and the backend integration flow.
  const detail = {
    'contract_id': 'CONT-00001', 'contract_number': 'CNT-1405-00001',
    'employee': 'HR-EMP-00001', 'employee_name': 'محمد رضایی',
    'department': 'امور اداری', 'job_title': 'کارشناس اداری',
    'contract_type': 'مدت‌معین', 'start_date': '2026-10-23',
    'jalali_start_date': '۱۴۰۵/۰۸/۰۱', 'status': 'نهایی',
    'template_version': 2,
    'rendered_clauses': [{'id': 'clause_parties', 'title': 'طرفین', 'body': 'متن مصوب', 'order': 1}],
    'salary_table': [{'id': 'row_base', 'name': 'حقوق پایه', 'period': 'ماهانه', 'period_raw': 'monthly', 'fieldRef': 'payroll.base_salary', 'amount': 200000000.0, 'has_value': true}],
  };
  test('reads backend list and detail keys without losing snapshot', () async {
    when(() => client.callAsoudMethod('${prefix}list_contracts', data: any(named: 'data'))).thenAnswer((_) async => [detail]);
    when(() => client.callAsoudMethod('${prefix}get_contract', data: any(named: 'data'))).thenAnswer((_) async => detail);
    final rows = await repository.listContracts(company: 'شرکت', query: 'محمد', statusFilter: 'نهایی', page: 2);
    expect(rows.single.id, 'CONT-00001');
    expect(rows.single.staffId, 'HR-EMP-00001');
    expect(rows.single.unit, 'امور اداری');
    expect(rows.single.templateVersion, 2);
    final record = await repository.getContract(company: 'شرکت', id: rows.single.id);
    expect(record.snapshotClauses.single.id, 'clause_parties');
    expect(record.salaries['payroll.base_salary'], 200000000);
    verify(() => client.callAsoudMethod('${prefix}list_contracts', data: {'company': 'شرکت', 'search': 'محمد', 'status': 'final', 'start': 20, 'page_length': 20})).called(1);
  });
  test('template keeps stable backend ids and salary rows', () async {
    when(() => client.callAsoudMethod('${prefix}get_contract_template', data: any(named: 'data'))).thenAnswer((_) async => {
      'template_id': 'template-1', 'version': 2, 'draft_version': 3, 'has_draft': true,
      'clauses': detail['rendered_clauses'],
      'salary_rows': [{'id': 'row_base', 'name': 'حقوق پایه', 'period': 'monthly', 'fieldRef': 'payroll.base_salary'}],
    });
    final template = await ServerHrContractTemplateRepository(client).getTemplate(company: 'شرکت');
    expect(template.id, 'template-1');
    expect(template.clauses.single.toJson()['id'], 'clause_parties');
    expect(template.payrollRows.single.toJson()['id'], 'row_base');
    expect(template.isPublished, false);
  });
  test('catalog binding uses server field ids and payroll null stays missing', () async {
    when(() => client.callAsoudMethod('${prefix}get_contract_field_catalog', data: any(named: 'data'))).thenAnswer((_) async => {
      'categories': [{'key': 'personnel', 'authorized': true, 'fields': [{'id': 'personnel.employee_name', 'label': 'نام', 'type': 'Data'}]}],
    });
    final templates = ServerHrContractTemplateRepository(client);
    expect(await templates.getAvailableCatalogFields(company: 'شرکت'), {'personnel': ['نام']});
    expect(templates.fieldTag('personnel', 'نام'), '{{personnel.employee_name}}');
    when(() => client.callAsoudMethod('${prefix}prepare_contract', data: any(named: 'data'))).thenAnswer((_) async => {
      'employee_info': {'employee_name': 'محمد رضایی'},
      'company_info': {}, 'template_version': 1, 'rendered_clauses': [],
      'salary_table': [
        {'fieldRef': 'payroll.base_salary', 'amount': 200000000.0, 'has_value': true},
        {'fieldRef': 'payroll.housing', 'amount': null, 'has_value': false, 'formatted_amount': 'اطلاعات موجود نیست'},
      ],
    });
    expect(await repository.getStaffSalaries(company: 'شرکت', staffId: 'HR-EMP-00001'), {'payroll.base_salary': 200000000, 'payroll.housing': null});
  });
  test('draft dates are ISO and finalization saves before using returned id', () async {
    final draft = HrContractRecord.fromJson(detail).copyWith(id: '', status: 'پیش‌نویس', startDate: '۱۴۰۵/۰۸/۰۱');
    when(() => client.callAsoudMethod('${prefix}save_contract_draft', data: any(named: 'data'))).thenAnswer((_) async => {'contract_id': 'CONT-00001', 'status': 'پیش‌نویس'});
    when(() => client.callAsoudMethod('${prefix}finalize_contract', data: any(named: 'data'))).thenAnswer((_) async => {'contract_id': 'CONT-00001', 'contract_number': 'CNT-1405-00001', 'status': 'نهایی'});
    when(() => client.callAsoudMethod('${prefix}get_contract', data: any(named: 'data'))).thenAnswer((_) async => detail);
    final result = await repository.submitContract(company: 'شرکت', draft: draft);
    expect(result.id, 'CONT-00001');
    expect(result.employeeName, 'محمد رضایی');
    final saved = verify(() => client.callAsoudMethod('${prefix}save_contract_draft', data: captureAny(named: 'data'))).captured.single as Map;
    expect(saved['start_date'], '2026-10-23');
    expect(saved.containsKey('contract_id'), false);
    verify(() => client.callAsoudMethod('${prefix}finalize_contract', data: {'contract_id': 'CONT-00001'})).called(1);
  });
}
