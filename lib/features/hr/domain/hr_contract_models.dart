/// Domain models for HR Employment Contracts (قالب و صدور قراردادهای کار پرسنلی)
/// Conforms to reference mockups:
/// - ASOUD_Contract_Form_Builder_Reference_v2.html
/// - ASOUD_HR_Contracts_Search_Print.html
library;

class HrContractClause {
  const HrContractClause({
    required this.id,
    required this.title,
    required this.body,
  });

  factory HrContractClause.fromJson(Map<String, dynamic> json) =>
      HrContractClause(
        id: json['id'] as Object? ?? '',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
      );

  final Object id;
  final String title;
  final String body;

  HrContractClause copyWith({
    Object? id,
    String? title,
    String? body,
  }) =>
      HrContractClause(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
      };
}

class HrPayrollTableRow {
  const HrPayrollTableRow({
    required this.id,
    required this.name,
    this.period = 'monthly',
    required this.fieldRef,
  });

  factory HrPayrollTableRow.fromJson(Map<String, dynamic> json) =>
      HrPayrollTableRow(
        id: json['id'] as Object? ?? '',
        name: '${json['name'] ?? ''}',
        period: '${json['period_raw'] ?? json['period'] ?? 'monthly'}',
        fieldRef: '${json['fieldRef'] ?? json['field_ref'] ?? ''}',
      );

  final Object id;
  final String name;
  final String period; // 'monthly', 'annual', 'once'
  final String fieldRef; // e.g. 'payroll.base_salary'

  HrPayrollTableRow copyWith({
    Object? id,
    String? name,
    String? period,
    String? fieldRef,
  }) =>
      HrPayrollTableRow(
        id: id ?? this.id,
        name: name ?? this.name,
        period: period ?? this.period,
        fieldRef: fieldRef ?? this.fieldRef,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'period': period,
        'fieldRef': fieldRef,
      };
}

class HrPayrollFieldOption {
  const HrPayrollFieldOption({
    required this.id,
    required this.label,
    required this.group,
  });

  final String id;
  final String label;
  final String group;
}

const defaultPayrollFields = <HrPayrollFieldOption>[
  HrPayrollFieldOption(
      id: 'payroll.base_salary', label: 'حقوق پایه', group: 'حقوق'),
  HrPayrollFieldOption(
      id: 'payroll.housing', label: 'حق مسکن', group: 'مزایا'),
  HrPayrollFieldOption(
      id: 'payroll.food', label: 'بن خواربار', group: 'مزایا'),
  HrPayrollFieldOption(
      id: 'payroll.child', label: 'حق اولاد', group: 'مزایا'),
  HrPayrollFieldOption(
      id: 'payroll.seniority', label: 'پایه سنوات', group: 'حقوق'),
  HrPayrollFieldOption(
      id: 'payroll.attraction', label: 'حق جذب', group: 'مزایا'),
  HrPayrollFieldOption(
      id: 'payroll.responsibility', label: 'حق مسئولیت', group: 'مزایا'),
  HrPayrollFieldOption(
      id: 'payroll.position', label: 'فوق‌العاده شغل', group: 'مزایا'),
  HrPayrollFieldOption(
      id: 'payroll.transport', label: 'ایاب و ذهاب', group: 'مزایا'),
  HrPayrollFieldOption(
      id: 'payroll.mission', label: 'حق مأموریت', group: 'مزایا'),
  HrPayrollFieldOption(
      id: 'payroll.overtime', label: 'اضافه‌کاری', group: 'کارکرد'),
  HrPayrollFieldOption(
      id: 'payroll.shift', label: 'فوق‌العاده نوبت‌کاری', group: 'کارکرد'),
  HrPayrollFieldOption(
      id: 'payroll.night', label: 'فوق‌العاده شب‌کاری', group: 'کارکرد'),
  HrPayrollFieldOption(
      id: 'payroll.bonus', label: 'پاداش', group: 'مزایا'),
  HrPayrollFieldOption(
      id: 'payroll.other_benefit', label: 'سایر مزایا', group: 'مزایا'),
];

const defaultCatalogGroups = <String, List<String>>{
  'personnel': [
    'نام و نام خانوادگی',
    'نام',
    'نام خانوادگی',
    'نام پدر',
    'کد ملی',
    'شماره شناسنامه',
    'سریال شناسنامه',
    'محل صدور شناسنامه',
    'تاریخ تولد',
    'محل تولد',
    'تابعیت',
    'وضعیت تأهل',
    'تعداد فرزندان',
    'نشانی محل سکونت',
    'کد پستی',
    'تلفن همراه',
    'تلفن ثابت',
    'ایمیل',
    'کد پرسنلی',
    'تاریخ استخدام',
    'تاریخ شروع همکاری',
    'واحد سازمانی',
    'جایگاه سازمانی',
    'عنوان شغلی',
    'نوع همکاری',
    'شماره بیمه',
    'شماره شبا',
    'مدرک تحصیلی',
    'رشته تحصیلی',
  ],
  'company': [
    'نام قانونی شرکت',
    'نام تجاری',
    'شناسه ملی شرکت',
    'شماره ثبت',
    'تاریخ ثبت',
    'کد اقتصادی',
    'نشانی دفتر مرکزی',
    'کد پستی شرکت',
    'تلفن شرکت',
    'ایمیل شرکت',
    'نام نماینده قانونی',
    'سمت نماینده قانونی',
    'نام مدیرعامل',
    'شعبه یا محل خدمت',
  ],
  'contract': [
    'نوع قرارداد',
    'تاریخ شروع',
    'تاریخ پایان',
    'محل انجام کار',
    'تاریخ تنظیم قرارداد',
  ],
  'payroll': [
    'حقوق پایه',
    'حق مسکن',
    'بن خواربار',
    'حق اولاد',
    'پایه سنوات',
    'حق جذب',
    'حق مسئولیت',
    'فوق‌العاده شغل',
    'ایاب و ذهاب',
    'حق مأموریت',
  ],
};

class HrContractTemplate {
  const HrContractTemplate({
    required this.id,
    required this.title,
    this.version = 1,
    this.isPublished = true,
    required this.clauses,
    required this.payrollRows,
    this.company = '',
  });

  factory HrContractTemplate.fromJson(Map<String, dynamic> json) =>
      HrContractTemplate(
        id: '${json['template_id'] ?? json['id'] ?? 'contract-standard'}',
        title: '${json['title'] ?? 'قالب قرارداد کار'}',
        version: json['version'] is int
            ? json['version'] as int
            : int.tryParse('${json['version']}') ?? 1,
        isPublished: json['has_draft'] != true && json['isPublished'] != false && json['is_published'] != false,
        clauses: (json['clauses'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(HrContractClause.fromJson)
                .toList() ??
            const [],
        payrollRows: ((json['salary_rows'] ?? json['payrollRows']) as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(HrPayrollTableRow.fromJson)
                .toList() ??
            const [],
        company: '${json['company'] ?? ''}',
      );

  final String id;
  final String title;
  final int version;
  final bool isPublished;
  final List<HrContractClause> clauses;
  final List<HrPayrollTableRow> payrollRows;
  final String company;

  HrContractTemplate copyWith({
    String? id,
    String? title,
    int? version,
    bool? isPublished,
    List<HrContractClause>? clauses,
    List<HrPayrollTableRow>? payrollRows,
    String? company,
  }) =>
      HrContractTemplate(
        id: id ?? this.id,
        title: title ?? this.title,
        version: version ?? this.version,
        isPublished: isPublished ?? this.isPublished,
        clauses: clauses ?? this.clauses,
        payrollRows: payrollRows ?? this.payrollRows,
        company: company ?? this.company,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'version': version,
        'isPublished': isPublished,
        'clauses': clauses.map((c) => c.toJson()).toList(),
        'payrollRows': payrollRows.map((r) => r.toJson()).toList(),
        'company': company,
      };

  static HrContractTemplate defaultTemplate({String company = ''}) =>
      HrContractTemplate(
        id: 'contract-standard',
        title: 'قالب قرارداد کار',
        version: 1,
        isPublished: true,
        company: company,
        clauses: const [
          HrContractClause(
            id: 1,
            title: 'طرفین قرارداد',
            body:
                'این قرارداد میان [نام قانونی شرکت] به نمایندگی [نام نماینده قانونی] و [نام و نام خانوادگی پرسنل] تنظیم می‌شود.',
          ),
          HrContractClause(
            id: 2,
            title: 'موضوع و محل کار',
            body:
                'موضوع همکاری، عنوان شغل و محل انجام کار مطابق اطلاعات درج‌شده در قرارداد تعیین می‌شود.',
          ),
          HrContractClause(
            id: 3,
            title: 'مدت همکاری',
            body:
                'تاریخ شروع همکاری [تاریخ شروع] و تاریخ پایان در قراردادهای مدت‌معین [تاریخ پایان] است.',
          ),
          HrContractClause(
            id: 4,
            title: 'حقوق و مزایا',
            body:
                'حقوق و مزایای طرف قرارداد مطابق اقلام مندرج در جدول زیر و مقررات مربوط تعیین می‌شود.',
          ),
          HrContractClause(
            id: 5,
            title: 'تعهدات طرفین',
            body:
                'شرایط محرمانگی، مسئولیت‌ها و سایر تعهدات مطابق متن مصوب قرارداد خواهد بود.',
          ),
        ],
        payrollRows: const [
          HrPayrollTableRow(
            id: 1,
            name: 'حقوق پایه',
            period: 'monthly',
            fieldRef: 'payroll.base_salary',
          ),
          HrPayrollTableRow(
            id: 2,
            name: 'حق مسکن',
            period: 'monthly',
            fieldRef: 'payroll.housing',
          ),
          HrPayrollTableRow(
            id: 3,
            name: 'بن خواربار',
            period: 'monthly',
            fieldRef: 'payroll.food',
          ),
        ],
      );
}

class HrContractRecord {
  const HrContractRecord({
    this.clientId,
    required this.id,
    required this.staffId,
    required this.employeeName,
    required this.employeeCode,
    this.unit = '',
    this.jobTitle = '',
    required this.kind, // 'مدت‌معین', 'غیرمدت‌معین', 'کار معین'
    required this.status, // 'پیش‌نویس', 'در جریان', 'نهایی'
    required this.startDate,
    this.endDate,
    required this.workplace,
    this.subject,
    this.notes,
    required this.salaries,
    this.templateVersion = 1,
    this.snapshotClauses = const [],
    this.snapshotPayrollRows = const [],
  });

  factory HrContractRecord.fromJson(Map<String, dynamic> json) =>
      HrContractRecord(
        clientId: json['client_id'] as String?,
        id: '${json['contract_id'] ?? json['id'] ?? json['name'] ?? ''}',
        staffId: '${json['employee'] ?? json['staffId'] ?? json['staff_id'] ?? ''}',
        employeeName:
            '${json['employeeName'] ?? json['employee_name'] ?? json['employee'] ?? ''}',
        employeeCode:
            '${json['employeeCode'] ?? json['employee_code'] ?? json['code'] ?? ''}',
        unit: '${json['department'] ?? json['unit'] ?? ''}',
        jobTitle: '${json['jobTitle'] ?? json['job_title'] ?? json['job'] ?? ''}',
        kind: '${json['contract_type'] ?? json['kind'] ?? 'مدت‌معین'}',
        status: '${json['status'] ?? 'پیش‌نویس'}',
        startDate: '${json['jalali_start_date'] ?? json['startDate'] ?? json['start_date'] ?? json['start'] ?? ''}',
        endDate: json['jalali_end_date'] as String? ?? json['endDate'] as String? ??
            json['end_date'] as String? ??
            json['end'] as String?,
        workplace: '${json['work_location'] ?? json['workplace'] ?? json['place'] ?? ''}',
        subject: json['subject'] as String?,
        notes: json['notes'] as String?,
        salaries: json['salary_table'] is List ? {
          for (final row in (json['salary_table'] as List).whereType<Map>())
            '${row['fieldRef']}': row['has_value'] == false || row['amount'] == null ? null : (row['amount'] as num).toInt(),
        } : (json['salaries'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(
                k,
                v == null ? null : (v is int ? v : int.tryParse('$v')),
              ),
            ) ??
            const {},
        templateVersion: int.tryParse('${json['template_version'] ?? json['templateVersion']}') ?? 1,
        snapshotClauses: ((json['rendered_clauses'] ?? json['snapshotClauses']) as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(HrContractClause.fromJson)
                .toList() ??
            const [],
        snapshotPayrollRows: ((json['salary_table'] ?? json['snapshotPayrollRows']) as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(HrPayrollTableRow.fromJson)
                .toList() ??
            const [],
      );

  final String id;
  final String staffId;
  final String? clientId;
  final String employeeName;
  final String employeeCode;
  final String unit;
  final String jobTitle;
  final String kind;
  final String status;
  final String startDate;
  final String? endDate;
  final String workplace;
  final String? subject;
  final String? notes;
  final Map<String, int?> salaries;
  final int templateVersion;
  final List<HrContractClause> snapshotClauses;
  final List<HrPayrollTableRow> snapshotPayrollRows;

  bool get isFinal => status == 'نهایی';
  bool get isDraft => status == 'پیش‌نویس';

  HrContractRecord copyWith({
    String? clientId,
    String? id,
    String? staffId,
    String? employeeName,
    String? employeeCode,
    String? unit,
    String? jobTitle,
    String? kind,
    String? status,
    String? startDate,
    String? endDate,
    String? workplace,
    String? subject,
    String? notes,
    Map<String, int?>? salaries,
    int? templateVersion,
    List<HrContractClause>? snapshotClauses,
    List<HrPayrollTableRow>? snapshotPayrollRows,
  }) =>
      HrContractRecord(
        clientId: clientId ?? this.clientId,
        id: id ?? this.id,
        staffId: staffId ?? this.staffId,
        employeeName: employeeName ?? this.employeeName,
        employeeCode: employeeCode ?? this.employeeCode,
        unit: unit ?? this.unit,
        jobTitle: jobTitle ?? this.jobTitle,
        kind: kind ?? this.kind,
        status: status ?? this.status,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        workplace: workplace ?? this.workplace,
        subject: subject ?? this.subject,
        notes: notes ?? this.notes,
        salaries: salaries ?? this.salaries,
        templateVersion: templateVersion ?? this.templateVersion,
        snapshotClauses: snapshotClauses ?? this.snapshotClauses,
        snapshotPayrollRows: snapshotPayrollRows ?? this.snapshotPayrollRows,
      );

  Map<String, dynamic> toJson() => {
        if (clientId != null) 'client_id': clientId,
        'id': id,
        'staffId': staffId,
        'employeeName': employeeName,
        'employeeCode': employeeCode,
        'unit': unit,
        'jobTitle': jobTitle,
        'kind': kind,
        'status': status,
        'startDate': startDate,
        'endDate': endDate,
        'workplace': workplace,
        'subject': subject,
        'notes': notes,
        'salaries': salaries,
        'templateVersion': templateVersion,
        'snapshotClauses': snapshotClauses.map((c) => c.toJson()).toList(),
        'snapshotPayrollRows':
            snapshotPayrollRows.map((r) => r.toJson()).toList(),
      };
}
