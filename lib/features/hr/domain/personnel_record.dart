import 'dart:convert';

void validatePersonnelRecord(Map<String, dynamic> value) {
  final kind = value['kind'];
  if (!['attendance', 'evaluation', 'document', 'photo', 'history']
      .contains(kind)) {
    throw const FormatException('نوع سابقه نامعتبر است.');
  }
  final title = '${value['title'] ?? ''}'.trim();
  if (title.isEmpty || title.length > 140) {
    throw const FormatException('عنوان باید بین ۱ تا ۱۴۰ نویسه باشد.');
  }
  final date = '${value['date'] ?? ''}';
  final parsed = DateTime.tryParse(date);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
      parsed == null ||
      parsed.toIso8601String().substring(0, 10) != date) {
    throw const FormatException('تاریخ معتبر با قالب YYYY-MM-DD وارد کنید.');
  }
  if ('${value['notes'] ?? ''}'.length > 5000) {
    throw const FormatException('توضیحات بیش از حد طولانی است.');
  }
  if (kind == 'attendance') {
    int minutes(String key) {
      final text = '${value[key] ?? ''}';
      if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text)) {
        throw const FormatException('ساعت معتبر HH:mm وارد کنید.');
      }
      return int.parse(text.substring(0, 2)) * 60 +
          int.parse(text.substring(3));
    }

    if (minutes('end') <= minutes('start')) {
      throw const FormatException('خروج باید بعد از ورود باشد.');
    }
  }
  if (kind == 'evaluation') {
    final score = value['score'];
    if (score is! num || !score.isFinite || score < 0 || score > 100) {
      throw const FormatException('امتیاز باید بین صفر و صد باشد.');
    }
  }
  if (kind == 'photo' || kind == 'document') {
    final bytes = base64Decode('${value['file'] ?? ''}');
    bool starts(List<int> header) =>
        bytes.length >= header.length &&
        List.generate(header.length, (i) => bytes[i] == header[i])
            .every((v) => v);
    final image =
        starts([255, 216, 255]) || starts([137, 80, 78, 71, 13, 10, 26, 10]);
    if (bytes.isEmpty ||
        bytes.length > 5 * 1024 * 1024 ||
        (!image && !(kind == 'document' && starts([37, 80, 68, 70, 45])))) {
      throw const FormatException(
          'فایل معتبر JPG، PNG یا PDF تا ۵ مگابایت انتخاب کنید.');
    }
  }
}
