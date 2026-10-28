import 'package:asoud_erp/features/hr/data/personnel_introduction_letter_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  test('template workflow and choices match the real server contract', () async {
    final client = _Client();
    final repository = FrappePersonnelIntroductionLetterRepository(client);
    const module = 'asoud_erp.api.v1.personnel_introduction_letters';
    final template = <String, dynamic>{
      'name': 'intro-template', 'revision': 2, 'status': 'Draft',
      'clauses': [{'id': 'intro', 'title': 'متن', 'body': '{{employee.employee_name}}', 'enabled': true}],
      'required_recipient': true, 'required_purpose': true, 'has_expiry': false, 'workflow': 'WF-INTRO',
    };
    when(() => client.callAsoudMethod('$module.get_template', data: {'company': 'شرکت'}))
        .thenAnswer((_) async => {...template, 'can_manage_template': true, 'workflow_options': [
          {'name': 'WF-INTRO', 'title': 'بررسی معرفی‌نامه'},
        ]});
    final loaded = await repository.getTemplate(company: 'شرکت');
    expect(loaded.workflow, 'WF-INTRO');
    expect(loaded.workflowOptions.single.title, 'بررسی معرفی‌نامه');
    expect(loaded.canManageTemplate, isTrue);
    expect(PersonnelIntroductionTemplate.fromMap(template).canManageTemplate, isFalse);
    when(() => client.callAsoudMethod('$module.save_template_draft', data: {
      'company': 'شرکت', 'revision': 2, 'clauses': template['clauses'],
      'required_recipient': true, 'required_purpose': true, 'has_expiry': false, 'workflow': 'WF-INTRO',
    })).thenAnswer((_) async => {...template, 'revision': 3});
    final saved = await repository.saveTemplateDraft(company: 'شرکت', revision: 2,
      clauses: loaded.clauses, workflow: loaded.workflow);
    expect(saved.workflow, 'WF-INTRO');
    when(() => client.callAsoudMethod('$module.publish_template', data: {'company': 'شرکت', 'revision': 3}))
        .thenAnswer((_) async => {...template, 'status': 'Published', 'revision': 1});
    final published = await repository.publishTemplate(company: 'شرکت', revision: 3);
    expect(published.workflow, 'WF-INTRO');
    expect(published.status, 'Published');
  });

  test('repository uses server endpoint parameters and unwrapped response shapes', () async {
    final client = _Client();
    final repository = FrappePersonnelIntroductionLetterRepository(client);
    const module = 'asoud_erp.api.v1.personnel_introduction_letters';
    final detail = <String, dynamic>{
      'name': 'INTRO-DRAFT-1', 'id': 'INTRO-DRAFT-1', 'company': 'شرکت',
      'employee': 'HR-EMP-1', 'employee_name': 'نام پرسنل', 'employee_number': '125',
      'recipient_type': 'bank', 'recipient_name': '', 'bank_name': 'بانک ملت',
      'branch_name': '', 'recipient_text': 'بانک ملت', 'purpose': 'افتتاح حساب',
      'validity_date': '', 'notes': '', 'status': 'Draft', 'number': '—',
      'issue_date': '—', 'revision': 1, 'template_version': 1,
      'rendered_html': '<article>متن</article>',
      'print_html': '<article>پیش‌نویس ـ فاقد اعتبار نهایی</article>',
      'values_snapshot': <String, dynamic>{}, 'template_snapshot': <String, dynamic>{},
    };
    when(() => client.callAsoudMethod('$module.list_letters', data: {
      'company': 'شرکت', 'query': '125', 'status': 'Draft', 'start': 20, 'page_length': 10,
    })).thenAnswer((_) async => {'items': [detail], 'total': 21});
    final page = await repository.list(company: 'شرکت', query: '125', status: 'Draft', start: 20, pageLength: 10);
    expect(page.total, 21);
    expect(page.items.single.employeeNumber, '125');
    when(() => client.callAsoudMethod('$module.get_letter', data: {'name': 'INTRO-DRAFT-1'}))
        .thenAnswer((_) async => detail);
    expect((await repository.getLetter(name: 'INTRO-DRAFT-1')).printHtml, detail['print_html']);
    when(() => client.callAsoudMethod('$module.save_draft', data: {
      'company': 'شرکت', 'employee': 'HR-EMP-1', 'recipient_type': 'bank',
      'recipient_name': '', 'bank_name': 'بانک ملت', 'branch_name': '',
      'purpose': 'افتتاح حساب', 'validity_date': '', 'notes': '',
      'request_key': 'retry-key', 'revision': 0, 'name': '',
    })).thenAnswer((_) async => detail);
    final saved = await repository.saveDraft(company: 'شرکت', employee: 'HR-EMP-1',
      bankName: 'بانک ملت', purpose: 'افتتاح حساب', requestKey: 'retry-key');
    expect(saved.revision, 1);
    when(() => client.callAsoudMethod('$module.finalize_letter', data: {
      'name': saved.name, 'revision': 1, 'request_key': 'final-key',
    })).thenAnswer((_) async => {...detail, 'status': 'Final', 'number': 'INTRO-1405-0001', 'revision': 2});
    final finalLetter = await repository.finalizeLetter(name: saved.name, revision: 1, requestKey: 'final-key');
    expect(finalLetter.isFinal, isTrue);
    expect(finalLetter.number, 'INTRO-1405-0001');
    when(() => client.callAsoudMethod('$module.get_employee_options', data: {'company': 'شرکت'}))
        .thenAnswer((_) async => [{
          'employee': 'HR-EMP-1', 'employee_name': 'نام پرسنل', 'employee_number': '125',
          'national_id': '', 'designation': null, 'department': null,
          'work_location': '', 'date_of_joining': '',
        }]);
    expect((await repository.getEmployeeOptions(company: 'شرکت')).single['employee_number'], '125');
  });

  test('maps personnel introduction letter list contract without exposing ids', () {
    final item = PersonnelIntroductionLetter.fromMap({
      'name': 'INTRO-1',
      'id': 'INTRO-1',
      'employee_name': 'سهراب سپهری',
      'employee_number': 'EMP-100',
      'number': '۱۴۰۵-۱۰',
      'recipient_text': 'بانک ملت ـ شعبه ونک',
      'status': 'Draft',
      'purpose': 'افتتاح حساب',
    });
    expect(item.employeeName, 'سهراب سپهری');
    expect(item.statusLabel, 'پیش‌نویس');
    expect(item.number, '۱۴۰۵-۱۰');
    expect(item.recipientText, 'بانک ملت ـ شعبه ونک');
  });

  test('maps template with required fields and expiry configuration', () {
    final template = PersonnelIntroductionTemplate.fromMap({
      'name': 'tmpl-1',
      'revision': 3,
      'status': 'Published',
      'required_recipient': true,
      'required_purpose': true,
      'has_expiry': false,
      'clauses': [
        {'id': 'intro', 'title': 'مقدمه', 'body': 'متن بند', 'enabled': true},
      ],
    });
    expect(template.name, 'tmpl-1');
    expect(template.revision, 3);
    expect(template.status, 'Published');
    expect(template.requiredRecipient, isTrue);
    expect(template.requiredPurpose, isTrue);
    expect(template.hasExpiry, isFalse);
    expect(template.clauses.length, 1);
    expect(template.clauses.first.id, 'intro');
  });
}
