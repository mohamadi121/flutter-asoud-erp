import '../../../core/network/frappe_client.dart';

class IntroductionLetterClause {
  const IntroductionLetterClause({
    required this.id,
    required this.title,
    required this.body,
    this.enabled = true,
  });

  factory IntroductionLetterClause.fromMap(Map<String, dynamic> map) => IntroductionLetterClause(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        body: map['body']?.toString() ?? '',
        enabled: map['enabled'] != false,
      );

  final String id;
  final String title;
  final String body;
  final bool enabled;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'enabled': enabled,
      };

  IntroductionLetterClause copyWith({String? id, String? title, String? body, bool? enabled}) =>
      IntroductionLetterClause(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        enabled: enabled ?? this.enabled,
      );
}

class PersonnelIntroductionTemplate {
  const PersonnelIntroductionTemplate({
    required this.name,
    required this.revision,
    required this.status,
    required this.clauses,
    this.requiredRecipient = true,
    this.requiredPurpose = true,
    this.hasExpiry = false,
  });

  factory PersonnelIntroductionTemplate.fromMap(Map<String, dynamic> map) => PersonnelIntroductionTemplate(
        name: map['name']?.toString() ?? '',
        revision: map['revision'] is int
            ? map['revision'] as int
            : int.tryParse(map['revision']?.toString() ?? '1') ?? 1,
        status: map['status']?.toString() ?? 'Draft',
        requiredRecipient: map['required_recipient'] != false,
        requiredPurpose: map['required_purpose'] != false,
        hasExpiry: map['has_expiry'] == true,
        clauses: (map['clauses'] as List? ?? const [])
            .map((c) => IntroductionLetterClause.fromMap(Map<String, dynamic>.from(c as Map)))
            .toList(),
      );

  final String name;
  final int revision;
  final String status;
  final bool requiredRecipient;
  final bool requiredPurpose;
  final bool hasExpiry;
  final List<IntroductionLetterClause> clauses;

  Map<String, dynamic> toMap() => {
        'name': name,
        'revision': revision,
        'status': status,
        'required_recipient': requiredRecipient,
        'required_purpose': requiredPurpose,
        'has_expiry': hasExpiry,
        'clauses': clauses.map((c) => c.toMap()).toList(),
      };
}

class PersonnelIntroductionLetter {
  const PersonnelIntroductionLetter({
    required this.name,
    required this.id,
    required this.employeeName,
    required this.employeeNumber,
    required this.number,
    required this.recipientText,
    required this.status,
    this.recipientType = 'bank',
    this.bankName = '',
    this.branchName = '',
    this.recipientName = '',
    this.purpose = '',
    this.issueDate = '',
    this.validityDate = '',
  });

  factory PersonnelIntroductionLetter.fromMap(Map<String, dynamic> map) => PersonnelIntroductionLetter(
        name: map['name']?.toString() ?? '',
        id: map['id']?.toString() ?? map['name']?.toString() ?? '',
        employeeName: map['employee_name']?.toString().trim().isNotEmpty == true
            ? map['employee_name'].toString()
            : 'پرسنل منتسب',
        employeeNumber: map['employee_number']?.toString() ?? '',
        number: map['number']?.toString() ?? '—',
        recipientText: map['recipient_text']?.toString() ??
            (map['bank_name']?.toString() ?? map['recipient_name']?.toString() ?? '—'),
        status: map['status']?.toString() ?? 'Draft',
        recipientType: map['recipient_type']?.toString() ?? 'bank',
        bankName: map['bank_name']?.toString() ?? '',
        branchName: map['branch_name']?.toString() ?? '',
        recipientName: map['recipient_name']?.toString() ?? '',
        purpose: map['purpose']?.toString() ?? '',
        issueDate: map['issue_date']?.toString() ?? '',
        validityDate: map['validity_date']?.toString() ?? '',
      );

  final String name;
  final String id;
  final String employeeName;
  final String employeeNumber;
  final String number;
  final String recipientText;
  final String status;
  final String recipientType;
  final String bankName;
  final String branchName;
  final String recipientName;
  final String purpose;
  final String issueDate;
  final String validityDate;

  String get statusLabel => switch (status) {
        'Draft' => 'پیش‌نویس',
        'Final' => 'نهایی',
        _ => 'در جریان',
      };
}

class PersonnelIntroductionLetterDetail {
  const PersonnelIntroductionLetterDetail({
    required this.name,
    required this.id,
    required this.company,
    required this.employee,
    required this.employeeName,
    required this.employeeNumber,
    required this.number,
    required this.recipientType,
    required this.recipientName,
    required this.bankName,
    required this.branchName,
    required this.recipientText,
    required this.purpose,
    required this.validityDate,
    required this.notes,
    required this.status,
    required this.revision,
    required this.templateVersion,
    required this.renderedHtml,
    required this.printHtml,
    required this.issueDate,
  });

  factory PersonnelIntroductionLetterDetail.fromMap(Map<String, dynamic> map) => PersonnelIntroductionLetterDetail(
        name: map['name']?.toString() ?? '',
        id: map['id']?.toString() ?? map['name']?.toString() ?? '',
        company: map['company']?.toString() ?? '',
        employee: map['employee']?.toString() ?? '',
        employeeName: map['employee_name']?.toString().trim().isNotEmpty == true
            ? map['employee_name'].toString()
            : 'پرسنل منتسب',
        employeeNumber: map['employee_number']?.toString() ?? '',
        number: map['number']?.toString() ?? '—',
        recipientType: map['recipient_type']?.toString() ?? 'bank',
        recipientName: map['recipient_name']?.toString() ?? '',
        bankName: map['bank_name']?.toString() ?? '',
        branchName: map['branch_name']?.toString() ?? '',
        recipientText: map['recipient_text']?.toString() ??
            (map['bank_name']?.toString() ?? map['recipient_name']?.toString() ?? '—'),
        purpose: map['purpose']?.toString() ?? '',
        validityDate: map['validity_date']?.toString() ?? '',
        notes: map['notes']?.toString() ?? '',
        status: map['status']?.toString() ?? 'Draft',
        revision: map['revision'] is int
            ? map['revision'] as int
            : int.tryParse(map['revision']?.toString() ?? '1') ?? 1,
        templateVersion: map['template_version'] is int
            ? map['template_version'] as int
            : int.tryParse(map['template_version']?.toString() ?? '1') ?? 1,
        renderedHtml: map['rendered_html']?.toString() ?? '',
        printHtml: map['print_html']?.toString() ?? '',
        issueDate: map['issue_date']?.toString() ?? '',
      );

  final String name;
  final String id;
  final String company;
  final String employee;
  final String employeeName;
  final String employeeNumber;
  final String number;
  final String recipientType;
  final String recipientName;
  final String bankName;
  final String branchName;
  final String recipientText;
  final String purpose;
  final String validityDate;
  final String notes;
  final String status;
  final int revision;
  final int templateVersion;
  final String renderedHtml;
  final String printHtml;
  final String issueDate;

  bool get isFinal => status == 'Final';
  String get statusLabel => switch (status) {
        'Draft' => 'پیش‌نویس',
        'Final' => 'نهایی',
        _ => 'در جریان',
      };
}

abstract class PersonnelIntroductionLetterRepository {
  Future<PersonnelIntroductionTemplate> getTemplate({required String company});

  Future<PersonnelIntroductionTemplate> saveTemplateDraft({
    required String company,
    required int revision,
    required List<IntroductionLetterClause> clauses,
    bool requiredRecipient = true,
    bool requiredPurpose = true,
    bool hasExpiry = false,
  });

  Future<PersonnelIntroductionTemplate> publishTemplate({
    required String company,
    required int revision,
  });

  Future<({List<PersonnelIntroductionLetter> items, int total})> list({
    required String company,
    String query = '',
    String status = '',
    int start = 0,
    int pageLength = 20,
  });

  Future<PersonnelIntroductionLetterDetail> getLetter({required String name});

  Future<PersonnelIntroductionLetterDetail> saveDraft({
    required String company,
    required String employee,
    String recipientType = 'bank',
    String recipientName = '',
    String bankName = '',
    String branchName = '',
    String purpose = '',
    String validityDate = '',
    String notes = '',
    required String requestKey,
    int revision = 0,
    String name = '',
  });

  Future<PersonnelIntroductionLetterDetail> finalizeLetter({
    required String name,
    required int revision,
    required String requestKey,
  });

  Future<List<Map<String, dynamic>>> getEmployeeOptions({required String company});
}

class FrappePersonnelIntroductionLetterRepository implements PersonnelIntroductionLetterRepository {
  FrappePersonnelIntroductionLetterRepository(this._client);
  final FrappeApiClient _client;
  static const _module = 'asoud_erp.api.v1.personnel_introduction_letters';

  @override
  Future<PersonnelIntroductionTemplate> getTemplate({required String company}) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.get_template', data: {'company': company}) as Map,
    );
    return PersonnelIntroductionTemplate.fromMap(raw);
  }

  @override
  Future<PersonnelIntroductionTemplate> saveTemplateDraft({
    required String company,
    required int revision,
    required List<IntroductionLetterClause> clauses,
    bool requiredRecipient = true,
    bool requiredPurpose = true,
    bool hasExpiry = false,
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.save_template_draft', data: {
        'company': company,
        'revision': revision,
        'clauses': clauses.map((c) => c.toMap()).toList(),
        'required_recipient': requiredRecipient,
        'required_purpose': requiredPurpose,
        'has_expiry': hasExpiry,
      }) as Map,
    );
    return PersonnelIntroductionTemplate.fromMap(raw);
  }

  @override
  Future<PersonnelIntroductionTemplate> publishTemplate({
    required String company,
    required int revision,
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.publish_template', data: {
        'company': company,
        'revision': revision,
      }) as Map,
    );
    return PersonnelIntroductionTemplate.fromMap(raw);
  }

  @override
  Future<({List<PersonnelIntroductionLetter> items, int total})> list({
    required String company,
    String query = '',
    String status = '',
    int start = 0,
    int pageLength = 20,
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.list_letters', data: {
        'company': company,
        'query': query,
        'status': status,
        'start': start,
        'page_length': pageLength,
      }) as Map,
    );
    final items = (raw['items'] as List? ?? const [])
        .map((row) => PersonnelIntroductionLetter.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
    return (items: items, total: raw['total'] is int ? raw['total'] as int : items.length);
  }

  @override
  Future<PersonnelIntroductionLetterDetail> getLetter({required String name}) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.get_letter', data: {'name': name}) as Map,
    );
    return PersonnelIntroductionLetterDetail.fromMap(raw);
  }

  @override
  Future<PersonnelIntroductionLetterDetail> saveDraft({
    required String company,
    required String employee,
    String recipientType = 'bank',
    String recipientName = '',
    String bankName = '',
    String branchName = '',
    String purpose = '',
    String validityDate = '',
    String notes = '',
    required String requestKey,
    int revision = 0,
    String name = '',
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.save_draft', data: {
        'company': company,
        'employee': employee,
        'recipient_type': recipientType,
        'recipient_name': recipientName,
        'bank_name': bankName,
        'branch_name': branchName,
        'purpose': purpose,
        'validity_date': validityDate,
        'notes': notes,
        'request_key': requestKey,
        'revision': revision,
        'name': name,
      }) as Map,
    );
    return PersonnelIntroductionLetterDetail.fromMap(raw);
  }

  @override
  Future<PersonnelIntroductionLetterDetail> finalizeLetter({
    required String name,
    required int revision,
    required String requestKey,
  }) async {
    final raw = Map<String, dynamic>.from(
      await _client.callAsoudMethod('$_module.finalize_letter', data: {
        'name': name,
        'revision': revision,
        'request_key': requestKey,
      }) as Map,
    );
    return PersonnelIntroductionLetterDetail.fromMap(raw);
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeOptions({required String company}) async {
    final raw = await _client.callAsoudMethod('$_module.get_employee_options', data: {'company': company});
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return const [];
  }
}

class FakePersonnelIntroductionLetterRepository implements PersonnelIntroductionLetterRepository {
  PersonnelIntroductionTemplate template = const PersonnelIntroductionTemplate(
    name: 'tmpl-intro-1',
    revision: 1,
    status: 'Published',
    requiredRecipient: true,
    requiredPurpose: true,
    hasExpiry: false,
    clauses: [
      IntroductionLetterClause(
        id: 'recipient_subject',
        title: 'مخاطب و موضوع معرفی‌نامه',
        body: 'مدیریت محترم {{letter.recipient}}\nموضوع: معرفی {{employee.employee_name}}',
        enabled: true,
      ),
      IntroductionLetterClause(
        id: 'employee_intro',
        title: 'معرفی مشخصات پرسنل',
        body:
            'با سلام و احترام،\nبدین‌وسیله آقا/خانم {{employee.employee_name}} با کد ملی {{employee.national_id}} و کد پرسنلی {{employee.employee_number}} به‌عنوان یکی از کارکنان {{company.company_name}} معرفی می‌گردد.',
        enabled: true,
      ),
      IntroductionLetterClause(
        id: 'position_purpose',
        title: 'سمت و هدف معرفی',
        body:
            'نامبرده در جایگاه {{employee.designation}} و واحد {{employee.department}} فعالیت دارد و جهت {{letter.purpose}} به آن مرجع معرفی می‌شود.',
        enabled: true,
      ),
      IntroductionLetterClause(
        id: 'cooperation_notes',
        title: 'درخواست همکاری و اعتبار نامه',
        body: 'خواهشمند است در حدود ضوابط آن مرجع، همکاری لازم با نامبرده به عمل آید.\n{{letter.notes}}',
        enabled: true,
      ),
      IntroductionLetterClause(
        id: 'authority_sign',
        title: 'مشخصات مقام صادرکننده',
        body: 'با احترام\n{{company.representative}}\n{{company.representative_position}}\n{{company.company_name}}',
        enabled: true,
      ),
    ],
  );

  final List<PersonnelIntroductionLetter> letters = [
    const PersonnelIntroductionLetter(
      name: 'INTRO-DRAFT-1',
      id: 'INTRO-DRAFT-1',
      employeeName: 'علی محمدی',
      employeeNumber: 'EMP-001',
      number: '—',
      recipientText: 'بانک ملت ـ شعبه مرکزی',
      recipientType: 'bank',
      bankName: 'بانک ملت',
      branchName: 'شعبه مرکزی',
      status: 'Draft',
      purpose: 'افتتاح حساب',
      issueDate: '—',
    ),
    const PersonnelIntroductionLetter(
      name: 'INTRO-1405-001',
      id: 'INTRO-1405-001',
      employeeName: 'سارا احمدی',
      employeeNumber: 'EMP-002',
      number: '۱۴۰۵-۰۰۱',
      recipientText: 'اداره ثبت اسناد',
      recipientType: 'organization',
      recipientName: 'اداره ثبت اسناد',
      status: 'Final',
      purpose: 'گواهی اداری',
      issueDate: '۱۴۰۵/۰۸/۰۱',
    ),
  ];

  @override
  Future<PersonnelIntroductionTemplate> getTemplate({required String company}) async => template;

  @override
  Future<PersonnelIntroductionTemplate> saveTemplateDraft({
    required String company,
    required int revision,
    required List<IntroductionLetterClause> clauses,
    bool requiredRecipient = true,
    bool requiredPurpose = true,
    bool hasExpiry = false,
  }) async {
    template = PersonnelIntroductionTemplate(
      name: template.name,
      revision: revision + 1,
      status: 'Draft',
      requiredRecipient: requiredRecipient,
      requiredPurpose: requiredPurpose,
      hasExpiry: hasExpiry,
      clauses: clauses,
    );
    return template;
  }

  @override
  Future<PersonnelIntroductionTemplate> publishTemplate({
    required String company,
    required int revision,
  }) async {
    template = PersonnelIntroductionTemplate(
      name: template.name,
      revision: revision,
      status: 'Published',
      requiredRecipient: template.requiredRecipient,
      requiredPurpose: template.requiredPurpose,
      hasExpiry: template.hasExpiry,
      clauses: template.clauses,
    );
    return template;
  }

  @override
  Future<({List<PersonnelIntroductionLetter> items, int total})> list({
    required String company,
    String query = '',
    String status = '',
    int start = 0,
    int pageLength = 20,
  }) async {
    var filtered = letters;
    if (status.isNotEmpty && status != 'all') {
      filtered = filtered.where((l) => l.status.toLowerCase() == status.toLowerCase()).toList();
    }
    if (query.isNotEmpty) {
      filtered = filtered
          .where((l) =>
              l.employeeName.contains(query) ||
              l.employeeNumber.contains(query) ||
              l.number.contains(query) ||
              l.recipientText.contains(query))
          .toList();
    }
    return (items: filtered, total: filtered.length);
  }

  @override
  Future<PersonnelIntroductionLetterDetail> getLetter({required String name}) async {
    final item = letters.firstWhere(
      (l) => l.name == name || l.id == name,
      orElse: () => letters.first,
    );
    return PersonnelIntroductionLetterDetail(
      name: item.name,
      id: item.id,
      company: 'شرکت نمونه',
      employee: item.employeeNumber,
      employeeName: item.employeeName,
      employeeNumber: item.employeeNumber,
      number: item.number,
      recipientType: item.recipientType,
      recipientName: item.recipientName,
      bankName: item.bankName,
      branchName: item.branchName,
      recipientText: item.recipientText,
      purpose: item.purpose,
      validityDate: item.validityDate,
      notes: '',
      status: item.status,
      revision: 1,
      templateVersion: 1,
      renderedHtml: '<article><p>متن معرفی‌نامه برای ${item.employeeName}</p></article>',
      printHtml: '<article><p>متن چاپ برای ${item.employeeName}</p></article>',
      issueDate: item.issueDate,
    );
  }

  @override
  Future<PersonnelIntroductionLetterDetail> saveDraft({
    required String company,
    required String employee,
    String recipientType = 'bank',
    String recipientName = '',
    String bankName = '',
    String branchName = '',
    String purpose = '',
    String validityDate = '',
    String notes = '',
    required String requestKey,
    int revision = 0,
    String name = '',
  }) async {
    final letterId = name.isNotEmpty ? name : 'INTRO-DRAFT-99';
    final recText = recipientType == 'bank'
        ? (branchName.isNotEmpty ? '$bankName ـ شعبه $branchName' : bankName)
        : recipientName;
    return PersonnelIntroductionLetterDetail(
      name: letterId,
      id: letterId,
      company: company,
      employee: employee,
      employeeName: 'علی محمدی',
      employeeNumber: employee,
      number: '—',
      recipientType: recipientType,
      recipientName: recipientName,
      bankName: bankName,
      branchName: branchName,
      recipientText: recText,
      purpose: purpose,
      validityDate: validityDate,
      notes: notes,
      status: 'Draft',
      revision: revision + 1,
      templateVersion: 1,
      renderedHtml: '<article><p>متن پیش‌نویس معرفی‌نامه</p></article>',
      printHtml: '<article><p>متن چاپ پیش‌نویس</p></article>',
      issueDate: '',
    );
  }

  @override
  Future<PersonnelIntroductionLetterDetail> finalizeLetter({
    required String name,
    required int revision,
    required String requestKey,
  }) async {
    return PersonnelIntroductionLetterDetail(
      name: name,
      id: name,
      company: 'شرکت نمونه',
      employee: 'EMP-001',
      employeeName: 'علی محمدی',
      employeeNumber: 'EMP-001',
      number: 'INTRO-1405-999',
      recipientType: 'bank',
      recipientName: '',
      bankName: 'بانک ملت',
      branchName: 'شعبه مرکزی',
      recipientText: 'بانک ملت ـ شعبه مرکزی',
      purpose: 'افتتاح حساب',
      validityDate: '',
      notes: '',
      status: 'Final',
      revision: revision + 1,
      templateVersion: 1,
      renderedHtml: '<article><p>متن نهایی شده</p></article>',
      printHtml: '<article><p>متن چاپ نهایی</p></article>',
      issueDate: '۱۴۰۵/۰۸/۱۰',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeOptions({required String company}) async {
    return [
      {
        'employee': 'EMP-001',
        'employee_name': 'علی محمدی',
        'employee_number': 'EMP-001',
        'national_id': '0012345678',
        'department': 'فنی و مهندسی',
        'designation': 'توسعه‌دهنده نرم‌افزار',
        'work_location': 'دفتر مرکزی',
        'date_of_joining': '۱۴۰۰/۰۱/۱۵',
      },
      {
        'employee': 'EMP-002',
        'employee_name': 'سارا احمدی',
        'employee_number': 'EMP-002',
        'national_id': '0023456789',
        'department': 'مالی و اداری',
        'designation': 'کارشناس حسابداری',
        'work_location': 'دفتر مرکزی',
        'date_of_joining': '۱۴۰۱/۰۳/۲۰',
      },
    ];
  }
}
