part of 'organization_page.dart';

// Setup drafts use the existing import contract; only its final confirmation
// writes Departments and chart rows in one server transaction.
Widget _setupCard(List<Widget> children) => Card(
    child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children)));

class _OrganizationExcelImport extends StatefulWidget {
  const _OrganizationExcelImport();
  @override
  State<_OrganizationExcelImport> createState() =>
      _OrganizationExcelImportState();
}

class _OrganizationExcelImportState extends State<_OrganizationExcelImport> {
  bool busy = false;
  bool downloading = false;
  String? fileName, error;

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy && !downloading,
      child: Scaffold(
          backgroundColor: _orgCanvas,
          appBar: const AsoudHeader(
              title: 'ورود از اکسل',
              subtitle: 'مدیریت ساختار سازمانی | آسود ERP'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            _setupCard([
              const Text('ورود ساختار سازمانی',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('از طریق فایل اکسل'),
              const Divider(height: 28),
              const Text('۱. دریافت الگوی اکسل'),
              const SizedBox(height: 8),
              const Text(
                  'ابتدا الگو را دریافت و اطلاعات واحدها و جایگاه‌های شغلی را در آن تکمیل کنید.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: downloading || busy
                      ? null
                      : () async {
                          setState(() => downloading = true);
                          await _downloadOrganizationTemplate(context);
                          if (mounted) setState(() => downloading = false);
                        },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('دانلود الگوی اکسل')),
            ]),
            const SizedBox(height: 12),
            _setupCard([
              const Text('۲. بارگذاری فایل تکمیل‌شده'),
              const SizedBox(height: 12),
              const Icon(Icons.upload_file_outlined,
                  color: AsoudColors.warning, size: 36),
              const SizedBox(height: 8),
              const Text('فقط فایل‌های XLSX', textAlign: TextAlign.center),
              if (fileName != null)
                Text(fileName!, textAlign: TextAlign.center),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!, style: const TextStyle(color: AsoudColors.danger)),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: busy || downloading ? null : _importExcel,
                  child: Text(
                      busy ? 'در حال بررسی فایل…' : 'انتخاب فایل از دستگاه')),
              const SizedBox(height: 8),
              const Text(
                  'اطلاعات ابتدا بررسی و پیش‌نمایش داده می‌شود. تا تأیید نهایی هیچ تغییری ثبت نمی‌شود. فایل اصلاح‌شده را می‌توانید دوباره انتخاب کنید.'),
            ]),
          ])));

  Future<void> _importExcel() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final cubit = context.read<OrganizationCubit>();
    List<OrgPosition> imported;
    List<Map<String, dynamic>> importedUnits = [];
    try {
      final file = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
      if (file == null || !mounted) {
        if (mounted) setState(() => busy = false);
        return;
      }
      setState(() => fileName = file.files.single.name);
      final data = file.files.single.bytes;
      if (data == null) throw const FormatException('خواندن فایل ممکن نشد.');
      final workbook = xls.Excel.decodeBytes(data);
      final sheets =
          workbook.tables.values.where((sheet) => sheet.rows.isNotEmpty);
      if (sheets.isEmpty) throw const FormatException('فایل خالی است.');
      final table = (workbook.tables['positions'] ??
                  (workbook.tables.containsKey('units') ? null : sheets.first))
              ?.rows ??
          [];
      final unitTable = workbook.tables['units']?.rows;
      if (unitTable != null && unitTable.length > 1) {
        final unitHeaders = unitTable.first
            .map((e) => e?.value.toString().trim().toLowerCase() ?? '')
            .toList();
        if (!unitHeaders.contains('code') ||
            !unitHeaders.contains('title') ||
            unitHeaders.where((h) => h.isNotEmpty).toSet().length !=
                unitHeaders.where((h) => h.isNotEmpty).length) {
          throw const FormatException(
              'ستون‌های واحدها باید code و title داشته باشند و تکراری نباشند.');
        }
        for (final cells in unitTable.skip(1)) {
          if (cells.every((c) => c?.value.toString().trim().isEmpty ?? true)) {
            continue;
          }
          importedUnits.add({
            for (var i = 0; i < unitHeaders.length; i++)
              if (unitHeaders[i].isNotEmpty)
                unitHeaders[i]: i < cells.length
                    ? cells[i]?.value.toString().trim() ?? ''
                    : ''
          });
        }
      }
      final headers = table.isEmpty
          ? <String>['code', 'title']
          : table.first
              .map((e) => e?.value.toString().trim().toLowerCase() ?? '')
              .toList();
      if (!headers.contains('code') || !headers.contains('title')) {
        throw const FormatException('ستون‌های code و title الزامی هستند.');
      }
      final names = headers.where((h) => h.isNotEmpty).toList();
      if (names.toSet().length != names.length) {
        throw const FormatException('نام ستون‌های فایل نباید تکراری باشد.');
      }
      imported = [];
      for (final (index, row) in table.indexed.skip(1)) {
        if (row
            .every((cell) => cell?.value.toString().trim().isEmpty ?? true)) {
          continue;
        }
        final record = <String, dynamic>{};
        for (var i = 0; i < headers.length; i++) {
          record[headers[i]] =
              i < row.length ? row[i]?.value.toString().trim() ?? '' : '';
        }
        if (record.containsKey('capacity')) {
          final capacity =
              int.tryParse(_normalizedOrgCode('${record['capacity']}'));
          if (capacity == null || capacity < 1) {
            throw FormatException(
                'ردیف ${toPersianDigits('${index + 1}')} جایگاه‌ها: ظرفیت باید عدد صحیح مثبت باشد.');
          }
          record['capacity'] = capacity;
          record['occupants'] = '${record['employee'] ?? ''}'.isEmpty
              ? <String>[]
              : ['${record['employee']}'];
        }
        if ('${record['code'] ?? ''}'.isEmpty ||
            '${record['title'] ?? ''}'.isEmpty) {
          throw FormatException(
              'ردیف ${toPersianDigits('${index + 1}')} جایگاه‌ها: کد و عنوان الزامی است.');
        }
        imported.add(OrgPosition.fromJson(record));
      }
      if (imported.isEmpty && importedUnits.isEmpty) {
        throw const FormatException('فایل جایگاهی برای ورود ندارد.');
      }
      validateOrganization([...cubit.state.snapshot.rows, ...imported]);
      validateOrganization(importedUnits.map(OrgPosition.fromJson).toList());
    } catch (e) {
      if (context.mounted) {
        setState(() {
          busy = false;
          error =
              e is FormatException ? e.message : 'فایل اکسل قابل پردازش نیست.';
        });
      }
      return;
    }
    if (!mounted) return;
    final saved = await _openOrganizationPage<bool>(
        context,
        _OrganizationImportReview(payload: {
          'units': importedUnits,
          'rows': imported.map((r) => r.toJson()).toList()
        }));
    if (!mounted) return;
    setState(() => busy = false);
    await WidgetsBinding.instance.endOfFrame;
    if (saved == true && mounted) Navigator.pop(context, true);
  }
}

class _OrganizationManualSetup extends StatefulWidget {
  const _OrganizationManualSetup();
  @override
  State<_OrganizationManualSetup> createState() =>
      _OrganizationManualSetupState();
}

class _OrganizationManualSetupState extends State<_OrganizationManualSetup> {
  final unitTitle = TextEditingController();
  final positionTitle = TextEditingController();
  final capacity = TextEditingController(text: '1');
  final duties = TextEditingController();
  List<Map<String, dynamic>> existing = [];
  final List<Map<String, dynamic>> units = [];
  final List<OrgPosition> positions = [];
  String unitParent = '', positionUnit = '', positionParent = '';
  String? editUnit, editPosition, error;
  bool loading = true, reviewing = false, closing = false, allowed = false;
  int stage = 0, serial = 0;
  String nextCode(String kind) =>
      '$kind-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${serial++}';

  OrganizationCubit get cubit => context.read<OrganizationCubit>();
  List<OrgPosition> get allPositions =>
      [...cubit.state.snapshot.rows, ...positions];
  List<Map<String, dynamic>> get allUnits => [
        ...existing,
        for (final u in units)
          {
            'name': u['code'],
            'department_name': u['title'],
            'parent_department': u['parent'],
            'is_group': 1,
            'disabled': 0
          }
      ];
  String unitLabel(String id) =>
      allUnits
          .where((u) => u['name'] == id)
          .map((u) => organizationUnitLabel(u))
          .firstOrNull ??
      (id.isEmpty ? 'بدون بالادستی / واحد اصلی' : 'واحد در دسترس نیست');
  String positionLabel(String id) =>
      allPositions.where((p) => p.code == id).firstOrNull?.displayTitle ??
      (id.isEmpty ? 'بدون جایگاه بالادستی' : 'جایگاه در دسترس نیست');

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await cubit.repository.units(cubit.company);
      if (!mounted) return;
      setState(() {
        existing = (result['units'] as List)
            .map((u) => Map<String, dynamic>.from(u as Map))
            .toList();
        allowed = result['can_manage'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get hasInput =>
      unitTitle.text.trim().isNotEmpty ||
      positionTitle.text.trim().isNotEmpty ||
      duties.text.trim().isNotEmpty ||
      capacity.text != '1' ||
      unitParent.isNotEmpty ||
      positionUnit.isNotEmpty ||
      positionParent.isNotEmpty;
  Future<bool> confirmDiscard(String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                title: const Text('تغییرات ثبت‌نشده'),
                content: Text(text),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('ادامه ویرایش')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('صرف‌نظر')),
                ],
              )) ==
      true;

  Future<void> close() async {
    if (reviewing) return;
    if ((hasInput || units.isNotEmpty || positions.isNotEmpty) &&
        !await confirmDiscard(
            'پیش‌نویس این صفحه ذخیره نشده است. از آن صرف‌نظر می‌کنید؟')) {
      return;
    }
    if (!mounted) return;
    setState(() => closing = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  void resetUnit() {
    unitTitle.clear();
    unitParent = '';
    editUnit = null;
  }

  void resetPosition() {
    positionTitle.clear();
    duties.clear();
    capacity.text = '1';
    positionUnit = '';
    positionParent = '';
    editPosition = null;
  }

  void saveUnit() {
    final original = units.where((u) => u['code'] == editUnit).firstOrNull;
    final title = organizationEditedTitle(unitTitle.text, '${original?['title'] ?? ''}');
    if (unitParent.isNotEmpty &&
        !allUnits.any((u) =>
            u['name'] == unitParent &&
            u['disabled'] != 1 &&
            u['is_group'] == 1)) {
      setState(
          () => error = 'واحد بالادستی در دسترس نیست؛ دوباره انتخاب کنید.');
      return;
    }
    if (title.isEmpty) {
      setState(() => error = 'عنوان واحد را وارد کنید.');
      return;
    }
    // Native Department naming is company-wide, not just sibling-wide.
    if (allUnits
        .any((u) => u['name'] != editUnit && u['department_name'] == title)) {
      setState(
          () => error = 'واحدی با این عنوان وجود دارد؛ عنوان دیگری وارد کنید.');
      return;
    }
    final code = editUnit ?? nextCode('UNIT');
    final row = <String, dynamic>{
      'code': code,
      'title': title,
      'parent': unitParent
    };
    final proposed = [...units.where((u) => u['code'] != code), row];
    final parents = {
      for (final u in proposed) '${u['code']}': '${u['parent']}'
    };
    final seen = <String>{code};
    var parent = unitParent;
    while (parents.containsKey(parent)) {
      if (!seen.add(parent)) {
        setState(() => error = 'ارتباط حلقوی در واحدها مجاز نیست.');
        return;
      }
      parent = parents[parent]!;
    }
    setState(() {
      units
        ..clear()
        ..addAll(proposed);
      resetUnit();
      error = null;
    });
  }

  void savePosition() {
    final count = int.tryParse(_normalizedOrgCode(capacity.text.trim()));
    if (!allUnits.any((u) => u['name'] == positionUnit && u['disabled'] != 1)) {
      setState(() => error = 'واحد سازمانی معتبر را انتخاب کنید.');
      return;
    }
    if (positionTitle.text.trim().isEmpty ||
        positionUnit.isEmpty ||
        count == null ||
        count < 1) {
      setState(
          () => error = 'عنوان، واحد سازمانی و ظرفیت صحیح مثبت را وارد کنید.');
      return;
    }
    final row = OrgPosition(
        code: editPosition ?? nextCode('POS'),
        title: organizationEditedTitle(positionTitle.text, positions.where((p) => p.code == editPosition).firstOrNull?.title ?? ''),
        parent: positionParent,
        departmentId: positionUnit,
        department: '${allUnits.firstWhere((u) => u['name'] == positionUnit)['department_name']}',
        capacity: count,
        occupants: const [],
        duties: duties.text.trim());
    final proposed = [...positions.where((p) => p.code != row.code), row];
    try {
      validateOrganization([...cubit.state.snapshot.rows, ...proposed]);
      setState(() {
        positions
          ..clear()
          ..addAll(proposed);
        resetPosition();
        error = null;
      });
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> review() async {
    if (reviewing || !allowed || loading) return;
    if (hasInput) {
      setState(() => error =
          'اطلاعات داخل فرم هنوز به پیش‌نویس اضافه نشده؛ ابتدا آن را اضافه یا لغو کنید.');
      return;
    }
    setState(() {
      reviewing = true;
      error = null;
    });
    final draftIds = units.map((u) => u['code']).toSet();
    final saved = await _openOrganizationPage<bool>(
        context,
        _OrganizationImportReview(unitLabels: {
          for (final u in allUnits) '${u['name']}': organizationUnitLabel(u)
        }, payload: {
          'units': [
            for (final u in units)
              {
                'code': u['code'],
                'title': u['title'],
                'parent': draftIds.contains(u['parent']) ? u['parent'] : '',
                if (!draftIds.contains(u['parent'])) 'parent_id': u['parent'],
              }
          ],
          'rows': positions.map((p) => p.toJson()).toList(),
        }));
    if (!mounted) return;
    setState(() {
      reviewing = false;
      closing = saved == true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  Widget select(String label, String value, List<AppOption> options,
          ValueChanged<String> changed) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: AppSelectField(
              label: label,
              value: value,
              displayValue:
                  options.where((o) => o.value == value).firstOrNull?.label ??
                      'انتخاب کنید',
              onPick: () => showAppOptionSheet(context,
                  title: label, current: value, options: options),
              onChanged: (v) => setState(() => changed(v))));

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        backgroundColor: _orgCanvas,
        appBar: const AsoudHeader(
            title: 'ایجاد ساختار دستی', subtitle: 'آسود ERP | ساختار سازمانی'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _setupCard([
            const Text('تعریف ساختار سازمانی',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('واحدها، جایگاه‌ها و بررسی نهایی'),
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                    child: TextButton(
                        onPressed:
                            reviewing ? null : () => setState(() => stage = i),
                        style: TextButton.styleFrom(
                            backgroundColor:
                                stage == i ? const Color(0xffeeeeef) : null),
                        child: Text(
                            ['۱. واحدها', '۲. جایگاه‌ها', '۳. بررسی'][i]))),
            ]),
          ]),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: AsoudColors.danger)),
          if (!loading && !allowed)
            TextButton(
                onPressed: load,
                child: const Text('دریافت مجوز و واحدها؛ تلاش دوباره')),
          if (!loading && allowed) ...[
            const SizedBox(height: 12),
            if (stage == 0) ...[
              _setupCard([
                const Text('تعریف واحد سازمانی',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                AppTextField(
                    controller: unitTitle, label: 'عنوان واحد', required: true),
                select(
                    'واحد بالادستی',
                    unitParent,
                    [
                      const AppOption('', 'بدون بالادستی / واحد اصلی'),
                      ...allUnits
                          .where((u) =>
                              u['name'] != editUnit &&
                              u['disabled'] != 1 &&
                              u['is_group'] == 1)
                          .map((u) => AppOption(
                              '${u['name']}', organizationUnitLabel(u))),
                    ],
                    (v) => unitParent = v),
                const Text(
                    'برای ایجاد واحد اصلی، گزینه بدون بالادستی را انتخاب کنید.'),
                FilledButton(
                    onPressed: saveUnit,
                    child: Text(editUnit == null
                        ? 'افزودن واحد به پیش‌نویس'
                        : 'ثبت ویرایش پیش‌نویس')),
                TextButton(
                    onPressed: () => setState(resetUnit),
                    child: const Text('پاک‌کردن فرم')),
              ]),
              _setupCard([
                Text(
                    'واحدهای تعریف‌شده — ${formatCount(allUnits.length, 'واحد')}'),
                if (allUnits.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('هنوز واحدی تعریف نشده است.')),
                for (final u in allUnits)
                  ListTile(
                      title: Text(organizationUnitLabel(u)),
                      subtitle: Text(
                          'بالادستی: ${unitLabel('${u['parent_department'] ?? ''}')}'),
                      trailing: units.any((d) => d['code'] == u['name'])
                          ? PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'delete') {
                                  if (allUnits.any((d) =>
                                          d['parent_department'] ==
                                          u['name']) ||
                                      allPositions.any(
                                          (p) => p.departmentId == u['name'])) {
                                    setState(() => error =
                                        'ابتدا زیرواحدها و جایگاه‌های وابسته را تعیین تکلیف کنید.');
                                    return;
                                  }
                                  setState(() {
                                    units.removeWhere(
                                        (d) => d['code'] == u['name']);
                                    if (editUnit == u['name']) resetUnit();
                                  });
                                } else {
                                  if (unitTitle.text.isNotEmpty &&
                                      !await confirmDiscard(
                                          'فرم فعلی واحد کنار گذاشته شود؟')) {
                                    return;
                                  }
                                  if (!mounted) return;
                                  setState(() {
                                    editUnit = '${u['name']}';
                                    unitTitle.text = organizationUnitLabel(u);
                                    unitParent =
                                        '${u['parent_department'] ?? ''}';
                                  });
                                }
                              },
                              itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: Text('ویرایش پیش‌نویس')),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: Text('حذف از پیش‌نویس')),
                                  ])
                          : const Icon(Icons.lock_outline, size: 18)),
                if (existing.isNotEmpty)
                  const Text(
                      'واحدهای ثبت‌شده حفظ می‌شوند؛ ویرایش آن‌ها از صفحه مدیریت ساختار انجام می‌شود.'),
              ]),
            ],
            if (stage == 1) ...[
              _setupCard([
                AppTextField(
                    controller: positionTitle,
                    label: 'عنوان جایگاه',
                    required: true),
                select(
                    'واحد سازمانی',
                    positionUnit,
                    [
                      ...allUnits.where((u) => u['disabled'] != 1).map((u) =>
                          AppOption('${u['name']}', organizationUnitLabel(u))),
                    ],
                    (v) => positionUnit = v),
                select(
                    'جایگاه بالادستی',
                    positionParent,
                    [
                      const AppOption('', 'بدون جایگاه بالادستی'),
                      ...allPositions
                          .where((p) => p.code != editPosition)
                          .map((p) => AppOption(p.code, p.displayTitle)),
                    ],
                    (v) => positionParent = v),
                AppTextField(
                    controller: capacity,
                    label: 'ظرفیت جایگاه',
                    required: true,
                    keyboardType: TextInputType.number),
                AppTextField(
                    controller: duties,
                    label: 'شرح وظایف (اختیاری)',
                    maxLines: 3),
                FilledButton(
                    onPressed: savePosition,
                    child: Text(editPosition == null
                        ? 'افزودن جایگاه به پیش‌نویس'
                        : 'ثبت ویرایش پیش‌نویس')),
                TextButton(
                    onPressed: () => setState(resetPosition),
                    child: const Text('پاک‌کردن فرم')),
                const Text('جایگاه بدون انتساب پرسنل ساخته می‌شود.'),
              ]),
              _setupCard([
                Text(formatCount(positions.length, 'جایگاه جدید')),
                for (final p in positions)
                  ListTile(
                      title: Text(p.displayTitle),
                      subtitle: Text(
                          '${unitLabel(p.departmentId)} · بالادست: ${positionLabel(p.parent)}'),
                      trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'delete') {
                              if (allPositions.any((r) => r.parent == p.code)) {
                                setState(() => error =
                                    'ابتدا جایگاه‌های زیردست را تعیین تکلیف کنید.');
                                return;
                              }
                              setState(() {
                                positions.remove(p);
                                if (editPosition == p.code) resetPosition();
                              });
                            } else {
                              if (positionTitle.text.isNotEmpty &&
                                  !await confirmDiscard(
                                      'فرم فعلی جایگاه کنار گذاشته شود؟')) {
                                return;
                              }
                              if (!mounted) return;
                              setState(() {
                                editPosition = p.code;
                                positionTitle.text = p.displayTitle;
                                positionUnit = p.departmentId;
                                positionParent = p.parent;
                                capacity.text = '${p.capacity}';
                                duties.text = p.duties;
                              });
                            }
                          },
                          itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit',
                                    child: Text('ویرایش پیش‌نویس')),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text('حذف از پیش‌نویس')),
                              ])),
              ]),
            ],
            if (stage == 2)
              _setupCard([
                Text(
                    '${formatCount(units.length, 'واحد جدید')} · ${formatCount(positions.length, 'جایگاه جدید')}'),
                for (final u in units)
                  ListTile(
                      title: Text(organizationLabel('${u['title']}')),
                      subtitle:
                          Text('بالادستی: ${unitLabel('${u['parent']}')}')),
                for (final p in positions)
                  ListTile(
                      title: Text(p.displayTitle),
                      subtitle: Text(
                          'واحد: ${unitLabel(p.departmentId)}\nبالادست: ${positionLabel(p.parent)} · ظرفیت: ${toPersianDigits('${p.capacity}')}')),
                const Text(
                    'بررسی نهایی سرور و تأیید صریح در مرحله بعد انجام می‌شود. اطلاعات فعلی تغییر نمی‌کند.'),
                FilledButton(
                    onPressed: reviewing || (units.isEmpty && positions.isEmpty)
                        ? null
                        : review,
                    child: const Text('بررسی و تأیید ساختار')),
                TextButton(
                    onPressed:
                        reviewing ? null : () => setState(() => stage = 0),
                    child: const Text('بازگشت و ویرایش')),
              ]),
            if (stage < 2)
              FilledButton(
                  onPressed: stage == 0 && allUnits.isEmpty
                      ? null
                      : () => setState(() => stage++),
                  child: Text(stage == 0
                      ? 'ادامه: تعریف جایگاه‌های شغلی'
                      : 'ادامه: بررسی ساختار')),
            const SizedBox(height: 12),
            const Text(
                'تا تأیید نهایی، این اطلاعات فقط پیش‌نویس همین صفحه است.',
                textAlign: TextAlign.center),
          ],
        ]),
      ));

  @override
  void dispose() {
    unitTitle.dispose();
    positionTitle.dispose();
    capacity.dispose();
    duties.dispose();
    super.dispose();
  }
}
