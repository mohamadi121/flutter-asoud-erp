import 'package:flutter/material.dart';

/// Fixed choices of the request type builder.
class RequestCategory {
  const RequestCategory(this.key, this.label);
  final String key, label;
}

const requestCategories = [
  RequestCategory('Finance', 'مالی'),
  RequestCategory('HR', 'منابع انسانی'),
  RequestCategory('Purchase', 'خرید'),
  RequestCategory('IT', 'فناوری اطلاعات'),
  RequestCategory('General', 'عمومی'),
  RequestCategory('Other', 'سایر موارد'),
];

class RequestIconOption {
  const RequestIconOption(this.key, this.icon, this.color, this.hex);
  final String key, hex;
  final IconData icon;
  final Color color;
}

const requestIcons = [
  RequestIconOption(
      'purchase', Icons.shopping_cart_outlined, Color(0xFF1769F6), '#1769F6'),
  RequestIconOption(
      'leave', Icons.event_note_outlined, Color(0xFFEF3340), '#EF3340'),
  RequestIconOption(
      'mission', Icons.flight_takeoff_rounded, Color(0xFF1769F6), '#1769F6'),
  RequestIconOption(
      'loan', Icons.payments_outlined, Color(0xFF16A34A), '#16A34A'),
  RequestIconOption(
      'equipment', Icons.laptop_mac_outlined, Color(0xFF1769F6), '#1769F6'),
  RequestIconOption('it', Icons.lan_outlined, Color(0xFF7C24E8), '#7C24E8'),
  RequestIconOption(
      'hr', Icons.person_outline_rounded, Color(0xFFD946EF), '#D946EF'),
  RequestIconOption(
      'other', Icons.more_horiz_rounded, Color(0xFF71809B), '#71809B'),
];

RequestIconOption requestIconFor(String? key) => requestIcons
    .firstWhere((item) => item.key == key, orElse: () => requestIcons.last);

/// A field type offered by "افزودن فیلد جدید". [type] is the server value;
/// a type the request runtime cannot store yet is listed with
/// `supported: false` and shown disabled.
class RequestFieldType {
  const RequestFieldType(this.type, this.label, this.icon,
      {this.supported = true});
  final String type, label;
  final IconData icon;
  final bool supported;
}

const requestFieldTypes = [
  RequestFieldType('Short Text', 'متن کوتاه', Icons.short_text_rounded),
  RequestFieldType('Long Text', 'متن بلند', Icons.notes_rounded),
  RequestFieldType('Number', 'عدد', Icons.pin_outlined),
  RequestFieldType('Currency', 'مبلغ', Icons.payments_outlined),
  RequestFieldType('Date', 'تاریخ', Icons.calendar_today_outlined),
  RequestFieldType('Choice', 'انتخابی', Icons.list_rounded),
  RequestFieldType('Checkbox', 'بله / خیر', Icons.check_box_outlined),
  RequestFieldType('Attachment', 'فایل', Icons.attach_file_rounded),
  RequestFieldType('Multi Choice', 'چندانتخابی', Icons.checklist_rounded),
  RequestFieldType('User', 'کاربر', Icons.person_outline_rounded),
  RequestFieldType('Department', 'واحد سازمانی', Icons.groups_outlined),
  RequestFieldType('Item Table', 'جدول اقلام', Icons.table_chart_outlined),
];

/// Types whose value is an ERPNext record or a table; the server keeps no
/// default value for them.
const requestFieldTypesWithoutDefault = {
  'Attachment',
  'Checkbox',
  'User',
  'Department',
  'Item Table',
};

RequestFieldType requestFieldTypeFor(String type) =>
    requestFieldTypes.firstWhere((item) => item.type == type,
        orElse: () => requestFieldTypes.first);

/// Fields every request already has; the builder only shows them.
const requestBaseFields = [
  'شماره درخواست',
  'ثبت‌کننده درخواست',
  'واحد سازمانی',
  'تاریخ ثبت',
  'وضعیت درخواست',
  'شرح درخواست',
  'فایل پیوست',
];

final requestFieldKeyPattern = RegExp(r'^[a-z][a-z0-9_]{1,39}$');
