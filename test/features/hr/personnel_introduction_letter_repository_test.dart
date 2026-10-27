import 'package:asoud_erp/features/hr/data/personnel_introduction_letter_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
