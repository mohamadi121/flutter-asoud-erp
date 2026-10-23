class OrgPosition {
  factory OrgPosition.fromJson(Map<String, dynamic> row) => OrgPosition(
      code: row['code']?.toString().trim() ?? '',
      title: row['title']?.toString().trim() ?? '',
      parent: row['parent']?.toString().trim() ?? '',
      department: row['department']?.toString().trim() ?? '',
      departmentId: row['department_id']?.toString() ?? '',
      occupants:
          row['occupants'] is List ? List<String>.from(row['occupants']) : null,
      capacity: (row['capacity'] as num?)?.toInt() ?? 1,
      duties: row['duties']?.toString() ?? '',
      history: (row['assignment_history'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      employee: row['employee']?.toString().trim() ?? '');
  const OrgPosition(
      {required this.code,
      required this.title,
      this.parent = '',
      this.department = '',
      this.departmentId = '',
      this.occupants,
      this.capacity = 1,
      this.duties = '',
      this.history = const [],
      this.employee = ''});
  final String code, title, parent, department, employee;
  final String departmentId, duties;
  final List<String>? occupants;
  final int capacity;
  final List<Map<String, dynamic>> history;
  List<String> get activeEmployees =>
      occupants ?? (employee.isEmpty ? [] : [employee]);
  OrgPosition copyWith(
          {String? title,
          String? parent,
          String? department,
          String? departmentId,
          List<String>? occupants,
          int? capacity,
          String? duties}) =>
      OrgPosition(
          code: code,
          title: title ?? this.title,
          parent: parent ?? this.parent,
          department: department ?? this.department,
          departmentId: departmentId ?? this.departmentId,
          employee: employee,
          occupants: occupants ?? this.occupants,
          capacity: capacity ?? this.capacity,
          duties: duties ?? this.duties,
          history: history);
  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'parent': parent,
        'department': department,
        if (departmentId.isNotEmpty) 'department_id': departmentId,
        if (occupants != null) ...{
          'occupants': occupants,
          'capacity': capacity,
          'duties': duties,
          'assignment_history': history,
        },
        'employee': employee
      };
}

void validateOrganization(List<OrgPosition> rows) {
  if (rows.length > 500) {
    throw const FormatException(
        'ساختار سازمانی حداکثر می‌تواند ۵۰۰ جایگاه داشته باشد.');
  }
  final codes = <String, OrgPosition>{};
  final employees = <String>{};
  for (final row in rows) {
    if (row.code.isEmpty || row.title.isEmpty) {
      throw const FormatException('کد و عنوان جایگاه الزامی است.');
    }
    if (codes.containsKey(row.code)) {
      throw FormatException('کد تکراری: ${row.code}');
    }
    codes[row.code] = row;
    if (row.capacity < 1 ||
        row.activeEmployees.length > row.capacity ||
        row.activeEmployees.toSet().length != row.activeEmployees.length) {
      throw const FormatException(
          'ظرفیت باید مثبت و حداقل برابر تعداد انتساب‌های فعال باشد؛ انتساب تکراری مجاز نیست.');
    }
    for (final employee in row.activeEmployees) {
      if (!employees.add(employee)) {
        throw const FormatException('هر پرسنل در این چارت فقط یک جایگاه دارد.');
      }
    }
  }
  for (final row in rows) {
    final seen = <String>{row.code};
    var parent = row.parent;
    while (parent.isNotEmpty) {
      if (!codes.containsKey(parent)) {
        throw FormatException('جایگاه بالادست یافت نشد: $parent');
      }
      if (!seen.add(parent)) {
        throw const FormatException('ارتباط حلقوی در چارت مجاز نیست.');
      }
      parent = codes[parent]!.parent;
    }
  }
}

const standardOrganization = [
  OrgPosition(code: 'CEO', title: 'مدیرعامل'),
  OrgPosition(
      code: 'FIN', title: 'مدیر مالی', parent: 'CEO', department: 'مالی'),
  OrgPosition(
      code: 'ACC-LEAD',
      title: 'سرپرست حسابداری',
      parent: 'FIN',
      department: 'مالی'),
  OrgPosition(
      code: 'ACC', title: 'حسابدار', parent: 'ACC-LEAD', department: 'مالی'),
  OrgPosition(
      code: 'HR',
      title: 'مدیر منابع انسانی',
      parent: 'CEO',
      department: 'منابع انسانی'),
];
