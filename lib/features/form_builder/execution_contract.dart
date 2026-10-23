bool executionTypeMatches(String type, List<dynamic> allowed) {
  const aliases = {
    'Currency': 'Money',
    'Checkbox': 'Check',
    'Boolean': 'Check',
    'Short Text': 'Text',
    'Long Text': 'LongText',
    'Choice': 'Select',
    'Number': 'Decimal'
  };
  return allowed
      .any((value) => (aliases[value] ?? value) == (aliases[type] ?? type));
}

List<String> executionProblems(
    Map<String, dynamic> schema, List<Map<String, dynamic>> catalog) {
  final fields = [
    for (final section in (schema['sections'] as List? ?? []))
      for (final field in (section['fields'] as List? ?? []))
        Map<String, dynamic>.from(field as Map)
  ];
  final mapped =
      fields.where((field) => field.containsKey('execution_key')).toList();
  final execution = schema['execution'];
  if (execution == null && mapped.isEmpty) return [];
  if (schema['kind'] != 'Request') {
    return ['اجرای پس از تأیید فقط برای فرم درخواست مجاز است.'];
  }
  final kind = execution is Map ? execution['kind'] : null;
  final executor = catalog.where((entry) => entry['kind'] == kind).firstOrNull;
  if (executor == null) return ['نوع اجرا معتبر نیست.'];
  final parameters = Map<String, dynamic>.from(executor['parameters'] as Map);
  final used = <String>{};
  for (final field in mapped) {
    final key = field['execution_key'];
    if (key is! String || !parameters.containsKey(key)) {
      return ['پارامتر اجرای فیلد معتبر نیست.'];
    }
    if (!used.add(key)) return ['پارامتر اجرای فیلد تکراری است.'];
    if (!executionTypeMatches(
        '${field['type']}', parameters[key]['types'] as List)) {
      return ['نوع فیلد با پارامتر اجرا سازگار نیست.'];
    }
  }
  final missing = [
    for (final entry in parameters.entries)
      if (entry.value['required'] == true && !used.contains(entry.key))
        entry.value['label']
  ];
  return missing.isEmpty
      ? []
      : ['نگاشت پارامتر الزامی مشخص نشده است: ${missing.join('، ')}'];
}
