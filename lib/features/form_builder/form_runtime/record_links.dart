import '../../../core/utils/jalali_date.dart';
import '../form_repository.dart';
import 'rules_engine.dart';

/// Link sources whose rows exist only on the server (no offline sample rows).
const serverOnlyLinkSources = {
  'Attendance',
  'Shift Type',
  'Leave Type',
  'Training Event',
  'Asset',
};

const formFetchAttributes = <String, Map<String, String>>{
  'Attendance': {
    'in_time': 'ساعت ورود',
    'out_time': 'ساعت خروج',
    'attendance_date': 'تاریخ',
    'status': 'وضعیت',
    'shift': 'شیفت',
  },
  'Shift Type': {
    'start_time': 'ساعت شروع',
    'end_time': 'ساعت پایان',
  },
  'Training Event': {
    'start_time': 'ساعت شروع',
    'end_time': 'ساعت پایان',
    'type': 'نوع',
    'level': 'سطح',
    'training_program': 'دوره',
    'course': 'عنوان دوره',
    'location': 'محل برگزاری',
    'trainer_name': 'مدرس',
    'employee_count': 'تعداد شرکت‌کنندگان',
  },
  'Asset': {
    'asset_name': 'نام دارایی',
    'item_code': 'کد کالا',
    'location': 'محل',
  },
  'Employee': {
    'department': 'واحد',
    'designation': 'سِمت',
    'employee_number': 'کد پرسنلی',
  },
};

const noEmployeeMessage = 'پرونده پرسنلی شما ثبت نشده است.';
const serverOnlyListMessage = 'این فهرست فقط با اتصال به سرور در دسترس است.';
const excludeSelfMessage = 'نمی‌توانید خودتان را انتخاب کنید.';
const defaultNotEqualMessage = 'مقدار جدید نباید با مقدار فعلی یکسان باشد.';
const defaultTimeAfterMessage = 'ساعت باید پس از ساعت مرجع باشد.';
const defaultBeforeOrEqualMessage = 'تاریخ نباید بعد از تاریخ پایان باشد.';

/// `fetch_from` split into the Link field key and the attribute.
({String link, String attribute})? parseFetchFrom(Object? raw) {
  final text = '${raw ?? ''}';
  final dot = text.lastIndexOf('.');
  if (dot <= 0 || dot == text.length - 1) return null;
  return (link: text.substring(0, dot), attribute: text.substring(dot + 1));
}

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}');
final _timePart = RegExp(r'(\d{1,2}:\d{2})(:\d{2})?');

/// Converts a raw attribute from a link row into the stored value of [target].
dynamic fetchedValue(FormMap target, dynamic raw) {
  if (raw == null || '$raw'.trim().isEmpty) return null;
  final text = '$raw'.trim();
  final timeMatch = _timePart.firstMatch(text);
  switch ('${target['type']}') {
    case 'Time':
      return timeMatch?.group(1)?.padLeft(5, '0');
    case 'Date':
      return _isoDate.hasMatch(text) ? text.substring(0, 10) : text;
    case 'DateTime':
      return text.replaceFirst(' ', 'T');
    default:
      if (_isoDate.hasMatch(text)) {
        final date = formatJalaliIso(text.substring(0, 10));
        final hasTime = text.length > 10 && timeMatch != null;
        return hasTime
            ? '$date ${toPersianDigits(timeMatch.group(1)!.padLeft(5, '0'))}'
            : date;
      }
      if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(text)) {
        return toPersianDigits(timeMatch!.group(1)!.padLeft(5, '0'));
      }
      return text;
  }
}

List<FormMap> _allFields(FormMap schema) => [
      for (final section in formMaps(schema['sections']))
        ...formMaps(section['fields']),
    ];

/// Applies one field change: clears dependent links and their fetched fields
/// (dependent reset) and fills the fields derived from a picked link row.
FormMap applyFieldChange(
  FormMap schema,
  FormMap values,
  String key,
  dynamic value, {
  FormMap? extra,
}) {
  final fields = _allFields(schema);
  final next = {...values, key: value};

  void clearFetched(String linkKey) {
    for (final f in fields) {
      if (parseFetchFrom(f['fetch_from'])?.link == linkKey) {
        next[f['key'] as String] = null;
      }
    }
  }

  void cascade(String changed) {
    for (final f in fields) {
      final filter = formMap(f['link_filter']);
      final linkKey = f['key'] as String;
      if (f['type'] == 'Link' &&
          filter['value_field'] == changed &&
          !isEmptyValue(next[linkKey])) {
        next[linkKey] = null;
        clearFetched(linkKey);
        cascade(linkKey);
      }
    }
  }

  if (values[key] != value) cascade(key);
  clearFetched(key);
  if (extra != null) {
    for (final f in fields) {
      final parsed = parseFetchFrom(f['fetch_from']);
      if (parsed?.link == key) {
        next[f['key'] as String] = fetchedValue(f, extra[parsed!.attribute]);
      }
    }
  }
  return next;
}

String _normal(dynamic v) {
  final text = toLatinDigits('$v').trim();
  final n = double.tryParse(text);
  return n == null ? text : '$n';
}

/// Contract C12: message when [field] equals the field named in `not_equal`.
String? notEqualProblem(
  FormMap field,
  FormMap values, {
  required bool Function(FormMap other) otherVisible,
  required FormMap schema,
}) {
  final otherKey = '${field['not_equal'] ?? ''}';
  if (otherKey.isEmpty) return null;
  final mine = values[field['key']], theirs = values[otherKey];
  if (isEmptyValue(mine) || isEmptyValue(theirs)) return null;
  final other = _allFields(schema)
      .where((f) => f['key'] == otherKey)
      .cast<FormMap?>()
      .firstOrNull;
  if (other != null && !otherVisible(other)) return null;
  if (field['type'] == 'Time' && other?['type'] == 'Time') {
    final mineNext = values['${field['key']}__next_day'] == true;
    final otherNext = values['${otherKey}__next_day'] == true;
    if (_normal(mine) != _normal(theirs) || mineNext != otherNext) return null;
  } else if (_normal(mine) != _normal(theirs)) {
    return null;
  }
  final custom = '${field['not_equal_message'] ?? ''}'.trim();
  return custom.isEmpty ? defaultNotEqualMessage : custom;
}

/// Message when [field] is not strictly later than the Time field named in `time_after`.
///
/// Compares `(next day, time)` pairs, so `22:00` then `01:00 روز بعد` is valid.
String? timeOrderProblem(
  FormMap field,
  FormMap values, {
  required bool Function(FormMap other) otherVisible,
  required FormMap schema,
}) {
  final otherKey = '${field['time_after'] ?? ''}';
  if (otherKey.isEmpty) return null;
  final mine = values[field['key']], theirs = values[otherKey];
  if (isEmptyValue(mine) || isEmptyValue(theirs)) return null;
  final other = _allFields(schema)
      .where((f) => f['key'] == otherKey)
      .cast<FormMap?>()
      .firstOrNull;
  if (other != null && !otherVisible(other)) return null;
  final first = _clockMinutes(theirs, values['${otherKey}__next_day'] == true);
  final second = _clockMinutes(mine, values['${field['key']}__next_day'] == true);
  if (first == null || second == null || second > first) return null;
  final custom = '${field['time_after_message'] ?? ''}'.trim();
  return custom.isEmpty ? defaultTimeAfterMessage : custom;
}

int? _clockMinutes(dynamic value, bool nextDay) {
  final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(toLatinDigits('$value').trim());
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!) + (nextDay ? 1440 : 0);
}

/// Contract C13: first column whose `unique` flag is violated, as a message.
String? uniqueColumnProblem(FormMap table, dynamic rows) {
  final list = formMaps(rows);
  for (final column in formMaps(table['columns'])) {
    if (column['unique'] != true) continue;
    final seen = <String>{};
    for (final row in list) {
      final v = row[column['key']];
      if (isEmptyValue(v)) continue;
      if (!seen.add(_normal(v))) return 'ردیف تکراری: ${column['label']}';
    }
  }
  return null;
}
