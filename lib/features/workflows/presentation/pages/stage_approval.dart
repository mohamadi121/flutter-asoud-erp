part of 'stage_settings_page.dart';

/// Reference styling over existing approval settings, without a second engine.
extension _ApprovalSettings on _StageSettingsPageState {
  Widget _approvalPanel(List<Widget> children) => Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children)));

  FormMap? get _approvalSource => widget.design.stages
      .where((stage) => stage.type == WorkflowStageType.start)
      .map((stage) => stage.config['submission_source'])
      .whereType<Map>()
      .map(formMap)
      .firstOrNull;

  Widget _approvalInformation() {
    final source = _approvalSource;
    return _approvalPanel([
      _label('اطلاعات موردنیاز برای تأیید'),
      const Text(
          'درخواست اصلی از تنظیمات شروع دریافت می‌شود؛ انتخاب دوباره لازم نیست.',
          style:
              TextStyle(fontSize: 11, height: 1.7, color: AsoudColors.muted)),
      const SizedBox(height: 10),
      Material(
          color: const Color(0xfff5f7fc),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const AsoudIconBox(
                icon: Icons.description_outlined,
                color: AsoudColors.primary,
                size: 34),
            title: Text(source?['title']?.toString() ?? 'فرم اصلی درخواست',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: Text(
                source == null
                    ? 'فرم قابل پیش‌نمایش در شروع انتخاب نشده است.'
                    : 'نمایش اطلاعات اصلی؛ فقط مشاهده',
                style: const TextStyle(
                    fontSize: 10, height: 1.7, color: AsoudColors.muted)),
          )),
      if (source != null)
        TextButton.icon(
            key: const ValueKey('approval-source-preview'),
            onPressed: saving || previewingApprovalSource
                ? null
                : () => _previewApprovalSource().ignore(),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            label: Text(previewingApprovalSource
                ? 'در حال دریافت…'
                : 'پیش‌نمایش فرم درخواست')),
      const Divider(height: 24),
      _label('فرم تکمیلی تأیید (اختیاری)'),
      // Existing workflow-field forms stay intact. A published Form Revision
      // needs a backend binding; do not flatten away formulas or table schemas.
      PickerField(
          value: formFields.isEmpty
              ? ''
              : 'فرم تکمیلی · ${formatCount(formFields.length, 'فیلد')}',
          placeholder: 'انتخاب یا ویرایش فرم مرحله',
          icon: Icons.description_outlined,
          onTap: saving ? null : _pickForm),
      if (formFields.isNotEmpty)
        Row(children: [
          Expanded(
              child: TextButton.icon(
                  onPressed: saving ? null : _editForm,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('ویرایش فرم'))),
          TextButton(
              onPressed: saving ? null : _removeApprovalForm,
              child: const Text('حذف فرم')),
        ]),
      const SizedBox(height: 8),
      const Text(
          'نبود فرم تکمیلی مانع تصمیم‌گیری نیست؛ اطلاعات آن جدا از درخواست اصلی ثبت می‌شود.',
          style:
              TextStyle(fontSize: 10, height: 1.7, color: AsoudColors.muted)),
    ]);
  }

  Future<void> _previewApprovalSource() async {
    final source = _approvalSource;
    if (source == null || previewingApprovalSource || saving) return;
    _updateAction(() => previewingApprovalSource = true);
    try {
      final repository = FormRepository(automation.client, company ?? '');
      final record = formMap(await repository.call('get_form', {
        'name': source['form'],
        'revision_name': source['revision'],
        'manage': 1,
      }));
      final schema = formMap(record['schema']);
      if (schema.isEmpty) throw StateError('فرم قابل پیش‌نمایش دریافت نشد.');
      if (!mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .8,
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                                'پیش‌نمایش فرم اصلی؛ بدون اطلاعات اجرایی',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 16),
                            FormFieldsView(
                                schema: schema,
                                values: const {},
                                enabled: false,
                                snapshot: true,
                                onChanged: (_) {},
                                repository: repository,
                                formName: source['form']?.toString()),
                          ])))));
    } catch (failure) {
      if (mounted) {
        _message(failure is ApiException
            ? failure.message
            : 'پیش‌نمایش فرم درخواست در دسترس نیست؛ اتصال و مجوز را بررسی کنید.');
      }
    } finally {
      if (mounted) _updateAction(() => previewingApprovalSource = false);
    }
  }

  Future<void> _setApprovalDecision(String action, bool enabled) async {
    if (saving || changingApprovalDecision) return;
    _updateAction(() => changingApprovalDecision = true);
    try {
      if (!enabled && (routes[action] ?? '').isNotEmpty) {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
                    title: const Text('غیرفعال‌کردن تصمیم'),
                    content: const Text(
                        'این تصمیم مسیر خروجی دارد. با ذخیرهٔ فرم، اتصال آن حذف می‌شود؛ خود مرحلهٔ مقصد حذف نخواهد شد. ادامه می‌دهید؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('انصراف')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('تأیید غیرفعال‌سازی')),
                    ]));
        if (confirmed != true || !mounted) return;
      }
      if (!mounted) return;
      _updateAction(() {
        if (action == 'Reject') {
          allowReject = enabled;
        } else {
          allowReturn = enabled;
        }
        if (enabled) {
          confirmedDisabledApprovalRoutes.remove(action);
        } else {
          confirmedDisabledApprovalRoutes.add(action);
        }
      });
    } finally {
      if (mounted) _updateAction(() => changingApprovalDecision = false);
    }
  }
}
