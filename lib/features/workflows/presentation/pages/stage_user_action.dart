part of 'stage_settings_page.dart';

extension _UserActionSettings on _StageSettingsPageState {
  void _initAction() {
    final rule = formMap(config['assignment_rule']);
    if (rule.isNotEmpty) {
      actionBasis = '${rule['basis']}';
      actionSubject = '${rule['subject'] ?? 'Initiator'}';
      actionEmployeeField = '${rule['employee_field'] ?? ''}';
      roleScope = '${rule['scope'] ?? 'Company'}';
      ownerMode = actionBasis == 'Role' ? 'role' : 'unit';
      role = '${rule['role'] ?? role}';
      final department = '${rule['department'] ?? ''}';
      if (department.isNotEmpty) {
        unit = OrgUnitChoice.department(
            department,
            departments
                    .where((item) => item.id == department)
                    .firstOrNull
                    ?.label ??
                'واحد انتخاب‌شده');
      }
      specificPerson = rule['delivery'] == 'Direct' && actionBasis == 'Unit';
      selectedPeople = {if (rule['person'] is String) rule['person'] as String};
    } else if (ownerMode == 'unit') {
      actionBasis = unit?.kind == 'initiator' ? 'Subject Unit' : 'Unit';
    } else if (role == directManagerRole || role == initiatorRole) {
      actionBasis = role == directManagerRole ? 'Manager' : 'Subject';
      ownerMode = 'unit';
    } else {
      actionBasis = 'Role';
    }
    if (actionSubject == 'Form Employee') _loadActionEmployeeFields().ignore();
  }

  Future<void> _loadActionEmployeeFields() async {
    if (loadingEmployeeFields) return;
    _updateAction(() => loadingEmployeeFields = true);
    try {
      final source = widget.design.stages
          .where((stage) => stage.type == WorkflowStageType.start)
          .map((stage) => stage.config['submission_source'])
          .whereType<Map>()
          .firstOrNull;
      if (source == null) {
        sourceEmployeeFields = [];
        return;
      }
      final record = formMap(
          await FormRepository(automation.client, company ?? '').call(
              'get_form', {
        'name': source['form'],
        'revision_name': source['revision'],
        'manage': 1
      }));
      final fields = formMaps(formMap(record['schema'])['sections'])
          .expand((section) => formMaps(section['fields']))
          .where((field) =>
              field['type'] == 'Link' && field['source'] == 'Employee' && field['sensitive'] != true)
          .toList();
      if (mounted) _updateAction(() => sourceEmployeeFields = fields);
    } catch (failure) {
      if (mounted) {
        _message(failure is ApiException
            ? failure.message
            : 'دریافت فیلدهای پرسنلی ممکن نشد.');
      }
    } finally {
      if (mounted) _updateAction(() => loadingEmployeeFields = false);
    }
  }

  Map<String, dynamic> _actionAssignment() {
    final basis = ownerMode == 'role' ? 'Role' : actionBasis;
    final rule = <String, dynamic>{'basis': basis};
    if (basis == 'Role') {
      rule.addAll({
        'role': role,
        'scope': roleScope,
        'delivery': 'Shared',
        if (roleScope == 'Department') 'department': unit?.id
      });
      return {
        'assignment_type': 'Role',
        'assignee_roles': [role],
        'assignment_rule': rule
      };
    }
    if (basis == 'Unit') {
      rule.addAll({
        'department': unit?.id,
        'delivery': specificPerson ? 'Direct' : 'Shared',
        if (specificPerson) 'person': selectedPeople.firstOrNull
      });
      return {
        'assignment_type': specificPerson ? 'Employee' : 'Department',
        if (specificPerson)
          'assignee_employees': selectedPeople.toList()
        else
          'assignee_departments': [unit?.id],
        'assignment_rule': rule
      };
    }
    rule.addAll({
      'subject': actionSubject,
      if (actionSubject == 'Form Employee')
        'employee_field': actionEmployeeField
    });
    return {
      'assignment_type': switch (basis) {
        'Manager' => 'Direct Manager',
        'Subject Unit' => 'Initiator Department',
        _ => 'Initiator'
      },
      'assignment_rule': rule
    };
  }

  String? _validateAction() {
    if (resultMode == 'Form' && resultForm == null) {
      return 'فرم ثبت نتیجه را انتخاب کنید.';
    }
    if (!addActionAttachments && formMaps(resultSchema['sections'])
        .expand((section) => formMaps(section['fields']))
        .expand((field) => [field, ...formMaps(field['columns'])])
        .any((field) => field['required'] == true && {'File', 'Image', 'Signature'}.contains(field['type']))) {
      return 'فرم پیوست الزامی دارد؛ امکان افزودن پیوست را روشن کنید.';
    }
    if (ownerMode == 'role') {
      if (!roles.contains(role) ||
          {directManagerRole, initiatorRole, 'Guest', 'All'}.contains(role)) {
        return 'نقش واقعی مسئول را انتخاب کنید.';
      }
      if (roleScope == 'Department' && unit == null) {
        return 'واحد محدودهٔ نقش را انتخاب کنید.';
      }
    } else if (actionBasis == 'Unit') {
      if (unit == null) return 'واحد سازمانی مسئول را انتخاب کنید.';
      if (specificPerson && selectedPeople.length != 1) {
        return 'فقط یک فرد مشخص از همان واحد انتخاب کنید.';
      }
    } else if (actionSubject == 'Form Employee' &&
        !sourceEmployeeFields
            .any((field) => field['key'] == actionEmployeeField)) {
      return 'فیلد پرسنلی فرم مبنا را انتخاب کنید.';
    }
    return null;
  }

  Widget _actionTitleFields() => Card(
      margin: EdgeInsets.zero,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _label('عنوان مرحله', required: true),
            TextField(
                controller: title,
                decoration: const InputDecoration(
                    hintText: 'مثلاً: تأیید مدیر مستقیم')),
            const SizedBox(height: 14),
            _label('توضیحات'),
            TextField(
                controller: description,
                minLines: 3,
                maxLines: 4,
                maxLength: 500,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    Text(formatCounter(currentLength, maxLength),
                        style: const TextStyle(
                            fontSize: 10, color: AsoudColors.muted)),
                decoration: const InputDecoration(
                    hintText: 'شرح کوتاهی از کار این مرحله...')),
          ])));

  Future<void> _pickActionForm() async {
    final selected = await showModalBottomSheet<FormMap>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => ActionResultFormPicker(
            repository: FormRepository(automation.client, company ?? '')));
    if (selected != null && mounted) {
      _updateAction(() {
        resultForm = {
          'form': selected['form'],
          'revision': selected['revision']
        };
        resultSchema = formMap(selected['schema']);
      });
    }
  }

  Widget _actionResultSection() => Card(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _label('اطلاعات موردنیاز برای انجام اقدام', required: true),
            for (final item in const [
              ('Simple', 'فرم ساده ثبت نتیجه'),
              ('Form', 'استفاده از فرم موجود در فرم‌ساز آسود')
            ])
              ListTile(
                  title: Text(item.$2, style: const TextStyle(fontSize: 12)),
                  trailing: Icon(
                      resultMode == item.$1
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: resultMode == item.$1
                          ? AsoudColors.primary
                          : AsoudColors.muted),
                  onTap: () => _updateAction(() => resultMode = item.$1)),
            if (resultMode == 'Simple')
              _notice(
                  'مجری هنگام اجرا، نتیجهٔ اقدام، شرح نتیجه و پیوست مجاز را ثبت می‌کند. پیگیری و مانع، گردش کار را به مرحله بعد نمی‌برند.')
            else ...[
              PickerField(
                  label: 'انتخاب فرم',
                  value: resultForm == null
                      ? ''
                      : '${resultSchema['title'] ?? 'فرم انتخاب‌شده'}',
                  placeholder: 'فرم منتشرشده را انتخاب کنید',
                  icon: Icons.description_outlined,
                  onTap: _pickActionForm),
              if (resultSchema.isNotEmpty)
                TextButton.icon(
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('مشاهده فرم'),
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (_) => SizedBox(
                            height: MediaQuery.sizeOf(context).height * .8,
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: FormFieldsView(
                                    schema: resultSchema,
                                    values: const {},
                                    enabled: false,
                                    snapshot: true,
                                    onChanged: (_) {},
                                    repository: FormRepository(
                                        automation.client, company ?? ''),
                                    formName:
                                        resultForm?['form'] as String?))))),
            ],
            _notice(
                'در این صفحه فقط روش ثبت نتیجه تعیین می‌شود؛ طراح اطلاعات واقعی اقدام را وارد نمی‌کند.'),
          ])));

  Future<void> _actionPickUnit() async {
    final choice = await showModalBottomSheet<OrgUnitChoice>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: OrgUnitPickerPage(
                departments: departments
                    .where((item) =>
                        item.company == null || item.company == company)
                    .toList(),
                selected: unit)));
    if (choice != null && mounted) {
      _updateAction(() {
        if (choice.kind == 'initiator') {
          actionBasis = 'Subject Unit';
          unit = null;
        } else {
          unit = choice;
        }
        selectedPeople.clear();
      });
    }
  }

  List<Widget> _actionOwner() => [
        const SizedBox(height: 6),
        _label('مسئول انجام', required: true),
        AsoudSegmentedControl<String>(
            value: ownerMode,
            options: const [
              AsoudSegmentedOption(value: 'unit', label: 'واحد سازمانی'),
              AsoudSegmentedOption(value: 'role', label: 'نقش')
            ],
            onChanged: (value) => _updateAction(() {
                  ownerMode = value;
                  selectedPeople.clear();
                  unit = null;
                  if (value == 'unit' && actionBasis == 'Role') {
                    actionBasis = 'Subject';
                  }
                  if (value == 'role' && !roles.contains(role)) {
                    role = roles
                            .where((r) => r != 'Guest' && r != 'All')
                            .firstOrNull ??
                        '';
                  }
                })),
        const SizedBox(height: 10),
        if (ownerMode == 'role') ...[
          PickerField(
              label: 'انتخاب نقش',
              value: roleLabel(role),
              icon: roleVisual(role).icon,
              iconColor: roleVisual(role).color,
              onTap: () async {
                final choice = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    builder: (_) => SizedBox(
                        height: MediaQuery.sizeOf(context).height * .7,
                        child: ChoiceListPage<String>(
                            title: 'انتخاب نقش مسئول',
                            searchHint: 'جستجوی نقش‌ها…',
                            items: roles
                                .where((r) => !{'Guest', 'All', 'Administrator'}
                                    .contains(r))
                                .toList(),
                            selected: role,
                            labelOf: roleLabel,
                            iconOf: roleVisual)));
                if (choice != null && mounted) {
                  _updateAction(() => role = choice);
                }
              }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              initialValue: roleScope,
              decoration: const InputDecoration(labelText: 'محدوده نقش'),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Company', child: Text('کل سازمان')),
                DropdownMenuItem(
                    value: 'Department', child: Text('واحد سازمانی مشخص'))
              ],
              onChanged: (value) => _updateAction(() {
                    roleScope = value!;
                    unit = null;
                  })),
        ] else ...[
          DropdownButtonFormField<String>(
              initialValue: actionBasis == 'Role' ? 'Subject' : actionBasis,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'مبنای ارجاع'),
              items: const [
                DropdownMenuItem(
                    value: 'Unit', child: Text('واحد سازمانی مشخص')),
                DropdownMenuItem(
                    value: 'Subject Unit',
                    child: Text('واحد سازمانی شخص مبنا')),
                DropdownMenuItem(value: 'Subject', child: Text('خود شخص مبنا')),
                DropdownMenuItem(
                    value: 'Manager', child: Text('مدیر مستقیم شخص مبنا'))
              ],
              onChanged: (value) => _updateAction(() {
                    actionBasis = value!;
                    unit = null;
                    selectedPeople.clear();
                    specificPerson = false;
                  })),
          if (actionBasis != 'Unit') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: actionSubject,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'شخص مبنا'),
                items: const [
                  DropdownMenuItem(
                      value: 'Initiator', child: Text('ثبت‌کننده درخواست')),
                  DropdownMenuItem(
                      value: 'Form Employee',
                      child: Text('پرسنل انتخاب‌شده در فرم درخواست'))
                ],
                onChanged: (value) {
                  _updateAction(() {
                    actionSubject = value!;
                    actionEmployeeField = '';
                  });
                  if (value == 'Form Employee') {
                    _loadActionEmployeeFields().ignore();
                  }
                }),
            if (actionSubject == 'Form Employee') ...[
              if (loadingEmployeeFields) const LinearProgressIndicator(),
              if (!loadingEmployeeFields && sourceEmployeeFields.isEmpty)
                _notice(
                    'فرم مبنای متصل به شروع، فیلد پرسنلی قابل استفاده ندارد.'),
              DropdownButtonFormField<String>(
                  key: ValueKey(
                      'employee-field-$actionEmployeeField-${sourceEmployeeFields.length}'),
                  initialValue: sourceEmployeeFields
                          .any((f) => f['key'] == actionEmployeeField)
                      ? actionEmployeeField
                      : null,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'فیلد پرسنلی فرم مبنا'),
                  items: [
                    for (final field in sourceEmployeeFields)
                      DropdownMenuItem(
                          value: '${field['key']}',
                          child: Text('${field['label']}'))
                  ],
                  onChanged: (value) =>
                      _updateAction(() => actionEmployeeField = value ?? '')),
            ],
          ],
        ],
        if ((ownerMode == 'unit' && actionBasis == 'Unit') ||
            (ownerMode == 'role' && roleScope == 'Department')) ...[
          const SizedBox(height: 12),
          PickerField(
              label: 'انتخاب واحد سازمانی',
              value: unit?.label ?? '',
              placeholder: 'انتخاب واحد',
              icon: Icons.apartment_rounded,
              onTap: _actionPickUnit),
          if (ownerMode == 'unit') ...[
            const SizedBox(height: 10),
            AsoudSegmentedControl<bool>(
                value: specificPerson,
                options: const [
                  AsoudSegmentedOption(value: true, label: 'یک فرد مشخص'),
                  AsoudSegmentedOption(value: false, label: 'همه افراد واحد')
                ],
                onChanged: (value) => _updateAction(() {
                      specificPerson = value;
                      selectedPeople.clear();
                    })),
            if (specificPerson)
              PickerField(
                  value: selectedPeople
                      .map((id) =>
                          employees
                              .where((e) => e.id == id)
                              .firstOrNull
                              ?.label ??
                          'انتخاب نیازمند بازبینی')
                      .join('، '),
                  placeholder: 'انتخاب فرد',
                  icon: Icons.person_outline,
                  onTap: _pickPeople),
          ],
        ],
        if (ownerMode == 'role' ||
            actionBasis == 'Subject Unit' ||
            (actionBasis == 'Unit' && !specificPerson))
          _notice(
              'اقدام در صف مشترک قرار می‌گیرد؛ اولین فرد مجاز که آن را دریافت کند مسئول می‌شود. انجام کار توسط همهٔ افراد الزامی نیست.'),
      ];
}
