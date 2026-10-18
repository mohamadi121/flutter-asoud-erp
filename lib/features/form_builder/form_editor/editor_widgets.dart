import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/jalali_date.dart';
import '../form_repository.dart';

const formModules = {
  'General': 'عمومی',
  'HR': 'منابع انسانی',
  'Finance': 'مالی',
  'Purchase': 'خرید',
  'Sales': 'فروش',
  'Stock': 'انبار',
  'Manufacturing': 'تولید',
  'Projects': 'پروژه‌ها',
  'IT': 'فناوری اطلاعات',
};

FormMap blankSchema(String kind) => {
      'schema_version': 2,
      'format': 1,
      'kind': kind,
      'title': '',
      'module': 'General',
      'description': '',
      'sections': [
        {'id': 'main', 'title': 'اطلاعات اصلی', 'fields': <FormMap>[]},
      ],
      'rules': <FormMap>[],
      'access': {'mode': 'all', 'roles': [], 'departments': []},
    };

Future<T?> formSheet<T>(
  BuildContext context,
  String title,
  Widget Function(BuildContext, StateSetter) content,
) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheet).height * .85,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheet),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    content(sheet, update),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

Widget formSelect(
  String label,
  String? value,
  Map<String, String> options,
  ValueChanged<String> change,
) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$value'),
        initialValue: options.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: options.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) {
            change(v);
          }
        },
      ),
    );

Future<String?> formText(
  BuildContext context,
  String title,
  String initial,
) async {
  var value = initial;
  return formSheet<String>(
    context,
    title,
    (sheet, update) => Column(
      children: [
        TextFormField(initialValue: initial, onChanged: (v) => value = v),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.pop(sheet, value.trim()),
          child: const Text('ذخیره'),
        ),
      ],
    ),
  );
}

Future<bool> formConfirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأیید عملیات'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    ) ??
    false;

Widget editorFieldText({
  required String label,
  required dynamic value,
  required ValueChanged<dynamic> onChanged,
  bool numeric = false,
  int lines = 1,
  Key? key,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: key ?? ValueKey('$label:$value'),
        initialValue: value == null ? '' : '$value',
        maxLines: lines,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              )
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        onChanged: (v) {
          if (numeric && v.trim().isEmpty) {
            onChanged(null);
          } else {
            onChanged(numeric ? num.tryParse(toLatinDigits(v)) : v);
          }
        },
      ),
    );

Map<String, String> nativeFieldLabels(String target) => switch (target) {
      'Journal Entry' => {
          'voucher_type': 'نوع سند',
          'posting_date': 'تاریخ ثبت',
          'user_remark': 'شرح',
          'accounts': 'آرتیکل‌ها',
        },
      'Material Request' => {
          'material_request_type': 'نوع درخواست کالا',
          'schedule_date': 'تاریخ نیاز',
          'items': 'اقلام',
        },
      'accounts' => {
          'account': 'حساب',
          'cost_center': 'مرکز هزینه',
          'project': 'پروژه',
          'debit_in_account_currency': 'بدهکار',
          'credit_in_account_currency': 'بستانکار',
        },
      'items' => {
          'item_code': 'کالا',
          'qty': 'تعداد',
          'uom': 'واحد',
          'warehouse': 'انبار',
          'schedule_date': 'تاریخ نیاز',
          'description': 'شرح',
        },
      _ => {},
    };
