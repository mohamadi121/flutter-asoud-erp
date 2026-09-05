class OrgPosition {
  factory OrgPosition.fromJson(Map<String, dynamic> row) => OrgPosition(
      code: row['code']?.toString().trim() ?? '',
      title: row['title']?.toString().trim() ?? '',
      parent: row['parent']?.toString().trim() ?? '',
      department: row['department']?.toString().trim() ?? '',
      employee: row['employee']?.toString().trim() ?? '');
  const OrgPosition(
      {required this.code,
      required this.title,
      this.parent = '',
      this.department = '',
      this.employee = ''});
  final String code, title, parent, department, employee;
  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'parent': parent,
        'department': department,
        'employee': employee
      };
}

void validateOrganization(List<OrgPosition> rows) {
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
    if (row.employee.isNotEmpty && !employees.add(row.employee)) {
      throw const FormatException('هر پرسنل در این چارت فقط یک جایگاه دارد.');
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
