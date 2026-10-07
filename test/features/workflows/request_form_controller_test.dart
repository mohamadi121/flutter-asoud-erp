import 'dart:convert';
import 'dart:typed_data';

import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_fixtures.dart';

RequestFormController _form(String template,
    {Map<String, dynamic> settings = const {'cost_center_required': true},
    Map<String, dynamic> initial = const {}}) {
  final type = requestOptionFixtures()
      .firstWhere((row) => row['template_key'] == template);
  return RequestFormController.fromType({...type, 'settings': settings},
      existing: initial.isEmpty ? null : {'values': initial});
}

Uint8List _bytes(int length) => Uint8List(length);

void main() {
  group('visible_when', () {
    test('hides fields and drops their values', () {
      final form = _form('leave');
      expect(form.value('request_kind'), 'Daily'); // default_value
      expect(form.isVisible('start_date'), isTrue);
      expect(form.isVisible('end_date'), isTrue);
      expect(form.isVisible('leave_date'), isFalse);
      expect(form.isVisible('start_time'), isFalse);

      form.setValue('start_date', '2026-10-10');
      form.setValue('end_date', '2026-10-12');
      form.setValue('request_kind', 'Hourly');
      expect(form.isVisible('start_date'), isFalse);
      expect(form.isVisible('leave_date'), isTrue);
      expect(form.value('start_date'), isNull);
      expect(form.value('end_date'), isNull);

      form.setValue('leave_date', '2026-10-06');
      form.setValue('start_time', '10:00');
      form.setValue('end_time', '14:00');
      form.setValue('request_kind', 'Daily');
      expect(form.value('leave_date'), isNull);
      expect(form.value('start_time'), isNull);
      // Back to hourly: the old hourly values are gone.
      form.setValue('request_kind', 'Hourly');
      expect(form.value('start_time'), isNull);
    });

    test('hidden fields are neither required nor sent', () {
      final form = _form('leave');
      form
        ..setValue('leave_type', 'Casual Leave')
        ..setValue('reason', 'سفر')
        ..setValue('start_date', '2026-10-10')
        ..setValue('end_date', '2026-10-12');
      expect(form.validate(), isTrue, reason: 'hourly fields are hidden');
      expect(form.errorFor('leave_date'), isNull);
      expect(form.errorFor('start_time'), isNull);
      expect(form.payloadValues().keys,
          isNot(anyOf(contains('leave_date'), contains('start_time'))));

      form.setValue('request_kind', 'Hourly');
      expect(form.validate(), isFalse);
      expect(form.errorFor('leave_date'), 'این فیلد الزامی است.');
      expect(form.errorFor('start_time'), isNotNull);
      expect(form.errorFor('start_date'), isNull, reason: 'now hidden');
      expect(form.firstErrorKey, 'leave_date');
    });

    test('values given at start for a hidden field are dropped', () {
      final form = _form('leave', initial: {
        'request_kind': 'Daily',
        'leave_date': '2026-10-06',
        'start_date': '2026-10-10'
      });
      expect(form.value('leave_date'), isNull);
      expect(form.value('start_date'), '2026-10-10');
    });
  });

  group('payloadValues', () {
    test('omits Auto fields, hidden fields and empty values', () {
      final form = _form('leave');
      form
        ..setValue('requester', 'sara@x')
        ..setValue('leave_type', 'Casual Leave')
        ..setValue('start_date', '2026-10-10')
        ..setValue('end_date', '2026-10-12')
        ..setValue('location', '')
        ..setValue('reason', '  سفر شخصی  ');
      form.setAutoText('duration', '۳ روز');
      expect(
          form.payloadValues(),
          {
            'requester': 'sara@x',
            'org_unit': 'ICU - WP', // default of the field
            'leave_type': 'Casual Leave',
            'request_kind': 'Daily',
            'start_date': '2026-10-10',
            'end_date': '2026-10-12',
            'reason': 'سفر شخصی',
            'location': 'Tehran', // default; the cleared value is a later set
          }..remove('location'));
      for (final auto in ['request_number', 'request_date', 'duration']) {
        expect(form.payloadValues().containsKey(auto), isFalse, reason: auto);
      }
    });

    test('numbers are numbers, Persian digits are read', () {
      final form = RequestFormController(fields: const [
        WorkflowFormFieldDefinition(key: 'a', label: 'a', type: 'Number'),
        WorkflowFormFieldDefinition(key: 'b', label: 'b', type: 'Currency'),
        WorkflowFormFieldDefinition(key: 'c', label: 'c', type: 'Checkbox'),
        WorkflowFormFieldDefinition(
            key: 'd', label: 'd', type: 'Multi Choice', options: ['x', 'y']),
      ]);
      form
        ..setValue('a', '۱۲٫۵')
        ..setValue('b', '1500000')
        ..setValue('c', false)
        ..setValue('d', ['x']);
      expect(form.payloadValues(), {
        'a': 12.5,
        'b': 1500000,
        'c': false,
        'd': ['x']
      });
      form.setValue('a', 'abc');
      expect(form.validate(), isFalse);
      expect(form.errorFor('a'), 'عدد معتبر وارد کنید.');
    });

    test('item rows keep only the input keys', () {
      final form = _form('purchase', initial: {
        'items': [
          {
            'item_code': 'ICU-MON-01',
            'item_name': 'مانیتور ICU',
            'qty': 2,
            'uom': 'Nos',
            'stock_uom': 'Nos',
            'conversion_factor': 1,
            'stock_qty': 2,
            'is_stock_item': 1,
            'description': '',
            'note': 'سریع',
            'attachment': '/private/files/m.png',
            'attachment_ref': {'name': '1a2b3c'},
          }
        ]
      });
      expect(form.payloadValues()['items'], [
        {
          'item_code': 'ICU-MON-01',
          'qty': 2,
          'uom': 'Nos',
          'note': 'سریع',
          'attachment': '/private/files/m.png',
        }
      ]);
    });

    test('keys that are not fields are not sent', () {
      final form = _form('purchase', initial: {'old_key': 'x'});
      expect(form.payloadValues().containsKey('old_key'), isFalse);
    });
  });

  group('validation', () {
    test('every required field of the purchase template is checked', () {
      final form = _form('purchase');
      expect(form.validate(), isFalse);
      for (final key in ['cost_center', 'needed_date', 'reason', 'items']) {
        expect(form.errorFor(key), isNotNull, reason: key);
      }
      expect(form.errorFor('items'), 'حداقل یک ردیف کالا لازم است.');
      expect(form.errorFor('project'), isNull);
      expect(form.errorFor('priority'), isNull, reason: 'default Normal');
      expect(form.errorFor('request_number'), isNull, reason: 'Auto');
      expect(form.subjectError, isNotNull);
    });

    test('cost_center follows the company setting', () {
      // The server resolves `required` of the row from the setting; the
      // fixture row is the "on" case, so the "off" row drops the flag.
      final type = requestOptionFixtures().first;
      final off = RequestFormController.fromType({
        ...type,
        'settings': {'cost_center_required': false},
        'fields': [
          for (final field in type['fields'] as List)
            (field as Map)['key'] == 'cost_center'
                ? {...field, 'required': false}
                : field
        ],
      });
      off.validate();
      expect(off.errorFor('cost_center'), isNull);
      final on = _form('purchase');
      on.validate();
      expect(on.errorFor('cost_center'), 'این فیلد الزامی است.');
      expect(on.isRequired(on.field('cost_center')!), isTrue,
          reason: 'resolved server-side too, from required_by_setting');
    });

    test('a complete purchase form is valid', () {
      final form = _form('purchase');
      form.subject.text = 'خرید تجهیزات ICU';
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      form
        ..setValue('cost_center', 'Main - WP')
        ..setValue('needed_date', tomorrow.toIso8601String().substring(0, 10))
        ..setValue('reason', 'نیاز بخش')
        ..setValue('items', [
          {'item_code': 'ICU-MON-01', 'qty': 2, 'uom': 'Nos'}
        ]);
      expect(form.validate(), isTrue, reason: '${form.firstErrorKey}');
      expect(form.payloadValues()['priority'], 'Normal');
    });

    test('item rows need a quantity above zero and respect max_rows', () {
      final form = _form('purchase');
      form.setValue('items', [
        {'item_code': 'A', 'qty': 0}
      ]);
      form.validate();
      expect(form.errorFor('items'), 'مقدار هر ردیف باید بیشتر از صفر باشد.');
      form.setValue('items', [
        for (var i = 0; i < 101; i++) {'item_code': 'A$i', 'qty': 1}
      ]);
      form.validate();
      expect(form.errorFor('items'), contains('حداکثر'));
    });

    test('needed_date may not be in the past, unless unchanged on edit', () {
      final past =
          DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
      final isoPast = past.substring(0, 10);
      final form = _form('purchase');
      form.setValue('needed_date', isoPast);
      form.validate();
      expect(form.errorFor('needed_date'), 'تاریخ نمی‌تواند در گذشته باشد.');
      form.setValue('needed_date', 'invalid:abc');
      form.validate();
      expect(form.errorFor('needed_date'), contains('تاریخ معتبر'));

      final edit = _form('purchase', initial: {'needed_date': isoPast});
      edit.validate();
      expect(edit.errorFor('needed_date'), isNull);
      edit.setValue(
          'needed_date',
          DateTime.now()
              .subtract(const Duration(days: 9))
              .toIso8601String()
              .substring(0, 10));
      edit.validate();
      expect(edit.errorFor('needed_date'), isNotNull);
    });

    test('Time must be a 24-hour HH:MM', () {
      final form = _form('leave');
      form
        ..setValue('request_kind', 'Hourly')
        ..setValue('start_time', '24:00')
        ..setValue('end_time', '9:3');
      form.validate();
      expect(form.errorFor('start_time'), contains('ساعت'));
      expect(form.errorFor('end_time'), contains('ساعت'));
      form
        ..setValue('start_time', '09:30')
        ..setValue('end_time', '23:59');
      form.validate();
      expect(form.errorFor('start_time'), isNull);
      expect(form.errorFor('end_time'), isNull);
    });

    test('Choice must be one of the options; max_length is enforced', () {
      final form = _form('purchase');
      form.setValue('priority', 'Whenever');
      form.setValue('reason', 'x' * 2001);
      form.validate();
      expect(form.errorFor('priority'), isNotNull);
      expect(form.errorFor('reason'), contains('حداکثر'));
    });

    test('generated subjects need no title; input subjects need 3 to 140', () {
      final leave = _form('leave');
      expect(leave.subjectMode, 'generated');
      leave.validate();
      expect(leave.subjectError, isNull);
      final purchase = _form('purchase');
      purchase.subject.text = 'ab';
      purchase.validate();
      expect(purchase.subjectError, 'عنوان ۳ تا ۱۴۰ نویسه باشد.');
      purchase.subject.text = 'abc';
      purchase.validate();
      expect(purchase.subjectError, isNull);
    });

    test('external errors block validation until cleared', () {
      final form = _form('leave');
      form
        ..setValue('leave_type', 'Casual Leave')
        ..setValue('reason', 'x')
        ..setValue('start_date', '2026-10-10')
        ..setValue('end_date', '2026-10-12');
      expect(form.validate(), isTrue);
      form.setExternalError('leave_type', 'مانده مرخصی کافی نیست.');
      expect(form.errorFor('leave_type'), 'مانده مرخصی کافی نیست.');
      expect(form.validate(), isFalse);
      form.setExternalError('leave_type', null);
      expect(form.validate(), isTrue);
    });
  });

  group('defaults', () {
    test('default_value and default_label come from request_options', () {
      final form = _form('purchase');
      expect(form.value('requester'), 'sara@x');
      expect(form.labelFor('requester'), 'سارا محمدی');
      expect(form.value('org_unit'), 'ICU - WP');
      expect(form.value('priority'), 'Normal');
      expect(form.field('requester')!.editable, isFalse);
    });

    test('editing loads the stored values and applies no defaults', () {
      final form = _form('purchase', initial: {'reason': 'x'});
      expect(form.value('reason'), 'x');
      expect(form.value('priority'), isNull);
    });
  });

  group('attachments', () {
    test('refs are unique and the upload list matches the references', () {
      final form = _form('purchase');
      final general = form.addAttachment(
          filename: 'spec.pdf', bytes: Uint8List.fromList([1, 2, 3]));
      final rowFile = form.addAttachment(
          filename: 'm.png', bytes: _bytes(10), general: false);
      final sameName = form.addAttachment(
          filename: 'm.png', bytes: _bytes(20), general: false);
      final orphan = form.addAttachment(
          filename: 'x.png', bytes: _bytes(5), general: false);
      expect({general, rowFile, sameName, orphan}, hasLength(4));
      expect(general, matches(RegExp(r'^att-\d+$')));

      form.setValue('items', [
        {
          'item_code': 'ICU-MON-01',
          'qty': 1,
          'uom': 'Nos',
          'attachment': 'attachment:$rowFile'
        },
        {
          'item_code': 'ICU-MON-01',
          'qty': 1,
          'attachment': 'attachment:$sameName'
        },
      ]);
      final uploads = form.attachmentUploads();
      expect(
          uploads.map((u) => u['ref']).toList(), [general, rowFile, sameName],
          reason: 'the unreferenced row file is not uploaded');
      for (final upload in uploads) {
        expect(upload.keys,
            unorderedEquals(['filename', 'content_base64', 'ref']));
      }
      expect(base64Decode(uploads.first['content_base64']!), [1, 2, 3]);
      expect(uploads[1]['filename'], uploads[2]['filename'],
          reason: 'duplicate filenames are allowed with refs');
    });

    test('removing a file clears the values that reference it', () {
      final form = _form('purchase');
      final ref = form.addAttachment(
          filename: 'm.png', bytes: _bytes(10), general: false);
      form.setValue('items', [
        {'item_code': 'A', 'qty': 1, 'attachment': 'attachment:$ref'}
      ]);
      expect(form.attachmentUploads(), hasLength(1));
      form.removeAttachment(ref);
      expect(form.attachmentUploads(), isEmpty);
      expect(
          (form.payloadValues()['items'] as List)
              .single
              .containsKey('attachment'),
          isFalse);
    });

    test('hidden fields do not keep their files uploaded', () {
      final form = RequestFormController(fields: const [
        WorkflowFormFieldDefinition(
            key: 'kind', label: 'k', type: 'Choice', options: ['a', 'b']),
        WorkflowFormFieldDefinition(
            key: 'doc',
            label: 'd',
            type: 'Attachment',
            visibleWhen: VisibleWhen(field: 'kind', equals: 'a')),
      ]);
      form.setValue('kind', 'a');
      final ref = form.addAttachment(
          filename: 'a.pdf', bytes: _bytes(4), general: false);
      form.setValue('doc', 'attachment:$ref');
      expect(form.attachmentUploads(), hasLength(1));
      form.setValue('kind', 'b');
      expect(form.attachmentUploads(), isEmpty);
    });

    test('type, size, count and total limits are enforced', () {
      final form = _form('leave'); // jpg jpeg png pdf docx
      expect(form.attachmentError('a.exe', 10), contains('فرمت'));
      expect(form.attachmentError('a.xlsx', 10), contains('فرمت'),
          reason: 'the leave list has no xlsx');
      expect(form.attachmentError('a.PDF', 10), isNull,
          reason: 'extensions are case-insensitive');
      expect(form.attachmentError('a.pdf', 10 * 1024 * 1024 + 1),
          contains('۱۰ مگابایت'));
      expect(() => form.addAttachment(filename: 'a.exe', bytes: _bytes(1)),
          throwsA(isA<RequestAttachmentException>()));
      for (var i = 0; i < 10; i++) {
        form.addAttachment(filename: 'f$i.pdf', bytes: _bytes(1));
      }
      expect(form.attachmentError('f11.pdf', 1), contains('۱۰ فایل'));

      final big = _form('purchase');
      big.addAttachment(filename: 'a.pdf', bytes: _bytes(10 * 1024 * 1024));
      big.addAttachment(filename: 'b.pdf', bytes: _bytes(10 * 1024 * 1024));
      expect(big.attachmentError('c.pdf', 6 * 1024 * 1024),
          contains('۲۵ مگابایت'));
      expect(big.attachmentError('c.pdf', 5 * 1024 * 1024), isNull);
    });

    test('limits come from request_options', () {
      final limits = RequestAttachmentLimits.fromMap({
        'max_files': 3,
        'max_mb': 2,
        'extensions': ['PDF', 'png']
      });
      expect(limits.maxFiles, 3);
      expect(limits.maxBytes, 2 * 1024 * 1024);
      expect(limits.extensions, ['pdf', 'png']);
      expect(limits.extensionsLabel, 'PDF، PNG');
      expect(RequestAttachmentLimits.fromMap(null).maxFiles, 10);
    });

    test('editing: kept files, removal and cleared references', () {
      final existing = {
        'values': {
          'items': [
            {
              'item_code': 'A',
              'qty': 1,
              'attachment': '/private/files/m.png',
            }
          ]
        },
        'attachments': [
          {
            'name': '1a2b3c',
            'filename': 'm.png',
            'file_url': '/private/files/m.png',
            'size': 18211,
            'is_image': true,
            'scope': 'row:items:0'
          },
          {
            'name': '9z',
            'filename': 'spec.pdf',
            'file_url': '/private/files/spec.pdf',
            'size': 100,
            'scope': 'general'
          },
        ],
      };
      final type = requestOptionFixtures().first;
      final form = RequestFormController.fromType(type, existing: existing);
      expect(form.keptExistingAttachments, hasLength(2));
      expect(form.attachmentLabel('/private/files/m.png'), 'm.png');
      form.removeExistingAttachment('1a2b3c');
      expect(form.removedAttachmentNames, ['1a2b3c']);
      expect(form.keptExistingAttachments.single.filename, 'spec.pdf');
      expect(
          (form.payloadValues()['items'] as List)
              .single
              .containsKey('attachment'),
          isFalse);
    });
  });

  test('RequestListPage and summaries parse the list fixtures', () {
    final all = requestFixture('list_all') as Map;
    final rows = [
      for (final row in all['data'] as List) RequestSummary.fromMap(row as Map)
    ];
    expect(rows.map((row) => row.statusKey), [
      RequestStatusKey.submitted,
      RequestStatusKey.inReview,
      RequestStatusKey.approved,
      RequestStatusKey.rejected,
    ]);
    expect(rows.first.number, 'PR-1405-0023');
    expect(rows.first.summary['priority_label'], 'مهم');
    expect(rows.first.itemCount, 3);
    expect(rows.first.attachmentCount, 2);
    final detail = RequestDetail.fromMap(requestData('get_request_purchase'));
    expect(detail.canEdit, isTrue);
    expect(detail.items.single.attachmentRef!.filename, 'm.png');
    expect(detail.attachments.single.rowIndex, 0);
    expect(detail.attachments.single.rowField, 'items');
    expect(detail.generalAttachments, isEmpty);
    expect(detail.commentCount, 1);
    final leave =
        RequestDetail.fromMap(requestData('get_request_leave_rejected'));
    expect(leave.rejectionReason, 'به دلیل مدارک ناقص');
    expect(leave.statusKey, RequestStatusKey.rejected);
  });

  test('leave models parse the §4.11 shapes', () {
    final balance = LeaveBalance.fromMap(requestData('leave_balance'));
    expect(balance.category('annual')!.remainingDays, 12.5);
    expect(balance.category('sick')!.availableDays, 8.0);
    expect(balance.leaveType('Casual Leave')!.hourlyTaken, 0.625);
    final preview =
        LeavePreview.fromMap(requestData('preview_leave_insufficient'));
    expect(preview.valid, isFalse);
    expect(preview.errors.single.code, 'INSUFFICIENT_LEAVE_BALANCE');
    expect(preview.firstMessage, 'مانده مرخصی کافی نیست.');
    expect(preview.duration.label, '۴ ساعت');
    expect(preview.balance!.remainingAfter, 12.0);
    final valid = LeavePreview.fromMap(requestData('preview_leave_valid'));
    expect(valid.valid, isTrue);
    expect(valid.duration.label, '۳ روز');
    expect(valid.holidaysExcluded, 1);
    expect(const LeaveDuration(unit: 'hour', hours: 1.5).label, '۱٫۵ ساعت');
  });
}
