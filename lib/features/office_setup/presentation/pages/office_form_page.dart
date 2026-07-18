import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/office.dart';
import '../../domain/repositories/office_repository.dart';
import '../bloc/office_form_bloc.dart';
import '../cubit/offices_cubit.dart';
import 'offices_page.dart';

class OfficeFormPage extends StatelessWidget {
  const OfficeFormPage({required this.officeType, super.key});
  final OfficeType officeType;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => OfficeFormBloc(
          officeType: officeType,
          repository: context.read<OfficeRepository>(),
        ),
        child: const _OfficeFormView(),
      );
}

class _OfficeFormView extends StatefulWidget {
  const _OfficeFormView();
  @override
  State<_OfficeFormView> createState() => _OfficeFormViewState();
}

class _OfficeFormViewState extends State<_OfficeFormView> {
  final _scrollController = ScrollController();
  static const _locations = {
    'تهران': ['تهران', 'ری', 'شمیرانات'],
    'اصفهان': ['اصفهان', 'کاشان', 'نجف‌آباد'],
    'فارس': ['شیراز', 'مرودشت', 'کازرون'],
    'خراسان رضوی': ['مشهد', 'نیشابور', 'سبزوار'],
    'آذربایجان شرقی': ['تبریز', 'مراغه', 'مرند'],
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<OfficeFormBloc, OfficeFormState>(
        listenWhen: (a, b) => a.status != b.status || a.message != b.message,
        listener: (context, state) {
          if (state.status == OfficeFormStatus.invalid) {
            _scrollController.animateTo(0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut);
          }
          if (state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.message!),
                backgroundColor: state.status == OfficeFormStatus.failure
                    ? AsoudColors.warning
                    : null));
          }
          if ((state.status == OfficeFormStatus.success ||
                  state.status == OfficeFormStatus.offlinePreview) &&
              state.createdOffice != null) {
            final offline = state.status == OfficeFormStatus.offlinePreview;
            Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
              builder: (_) => OfficesPage(
                initialState: offline
                    ? OfficesState(
                        status: OfficesStatus.success,
                        offices: [state.createdOffice!],
                        defaultOffice: state.createdOffice,
                        offlinePreview: true,
                      )
                    : null,
                showCreatedBanner: !offline,
                fallbackOffice: state.createdOffice,
              ),
            ));
          }
        },
        builder: (context, state) => PopScope(
          canPop: !state.isDirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _cancel();
          },
          child: Scaffold(
            appBar: const AsoudHeader(
              title: 'ایجاد دفتر کار',
              subtitle: 'تعریف یک دفتر کاری جدید',
              action: AsoudIconBox(
                  icon: Icons.person_outline_rounded,
                  color: AsoudColors.primary),
            ),
            body: SafeArea(
              child: ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _TypeSelector(value: state.officeType),
                  const SizedBox(height: 10),
                  _BaseSection(state: state),
                  const SizedBox(height: 10),
                  _ContactSection(state: state, locations: _locations),
                  const SizedBox(height: 10),
                  _FinancialSection(state: state),
                  const SizedBox(height: 10),
                  _LogoSection(state: state, onPick: _pickLogo),
                  const SizedBox(height: 10),
                  _DescriptionSection(state: state),
                ],
              ),
            ),
            bottomNavigationBar: AsoudBottomActions(
              primaryLabel: state.status == OfficeFormStatus.submitting
                  ? 'در حال ارسال…'
                  : 'ایجاد دفتر کار',
              onPrimary: state.status == OfficeFormStatus.submitting
                  ? null
                  : () => context
                      .read<OfficeFormBloc>()
                      .add(const OfficeFormSubmitted()),
              secondaryLabel: 'انصراف',
              onSecondary: _cancel,
            ),
          ),
        ),
      );

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (!mounted || file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حجم لوگو باید کمتر از ۲ مگابایت باشد.')));
      return;
    }
    context
        .read<OfficeFormBloc>()
        .add(OfficeLogoChanged(name: file.name, bytes: bytes));
  }

  Future<void> _cancel() async {
    final state = context.read<OfficeFormBloc>().state;
    if (!state.isDirty) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('انصراف از ایجاد دفتر؟'),
              content: const Text('اطلاعات واردشده ذخیره نشده‌اند.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('ادامه ویرایش')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('خروج'))
              ],
            ));
    if (leave == true && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value});
  final OfficeType value;
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AsoudColors.border),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _item(context, OfficeType.personal, 'شخص حقیقی',
              Icons.person_outline_rounded),
          _item(
              context, OfficeType.legal, 'شخص حقوقی', Icons.apartment_outlined),
        ]),
      );
  Widget _item(
      BuildContext context, OfficeType type, String label, IconData icon) {
    final selected = type == value;
    return Expanded(
        child: InkWell(
      key: ValueKey('office-type-${type.name}'),
      onTap: () => context.read<OfficeFormBloc>().add(OfficeTypeChanged(type)),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
          constraints: const BoxConstraints.expand(),
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
              color: selected ? AsoudColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 20, color: selected ? Colors.white : AsoudColors.text),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AsoudColors.text))
          ])),
    ));
  }
}

class _BaseSection extends StatelessWidget {
  const _BaseSection({required this.state});
  final OfficeFormState state;
  @override
  Widget build(BuildContext context) {
    final legal = state.officeType == OfficeType.legal;
    return _SectionCard(
        number: '۱',
        title: 'اطلاعات پایه',
        icon: Icons.badge_outlined,
        children: [
          _field(context, 'officeName', 'نام دفتر *', state.officeName),
          const SizedBox(height: 8),
          _ResponsivePair(
              children: legal
                  ? [
                      _field(context, 'registrationNumber', 'شماره ثبت',
                          state.registrationNumber,
                          numeric: true),
                      _field(
                          context, 'nationalId', 'شناسه ملی', state.nationalId,
                          numeric: true),
                    ]
                  : [
                      _field(context, 'ownerFullName',
                          'نام و نام خانوادگی صاحب دفتر', state.ownerFullName),
                      _field(
                          context, 'nationalId', 'شماره ملی', state.nationalId,
                          numeric: true),
                    ]),
          const SizedBox(height: 8),
          _select(
              context,
              legal ? 'companyType' : 'activityType',
              legal ? 'نوع شرکت' : 'نوع فعالیت',
              legal ? state.companyType : state.activityType,
              legal
                  ? const ['سهامی خاص', 'مسئولیت محدود', 'تعاونی', 'مؤسسه']
                  : const ['خدماتی', 'بازرگانی', 'تولیدی', 'پیمانکاری']),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: state.hasIndependentPersonality,
              onChanged: (v) => context
                  .read<OfficeFormBloc>()
                  .add(OfficeFieldChanged('independent', v ?? false)),
              title: Text(
                  legal
                      ? 'این دفتر شخصیت حقوقی مستقل دارد'
                      : 'این دفتر شخصیت مستقل دارد',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'در صورت استقلال، اطلاعات مالی دفتر جداگانه نگهداری می‌شود.',
                  style: TextStyle(fontSize: 9))),
          _select(
              context,
              'parentOffice',
              legal ? 'شرکت بالادستی' : 'دفتر بالادستی',
              state.parentOffice,
              const ['ندارد'],
              required: false),
        ]);
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.state, required this.locations});
  final OfficeFormState state;
  final Map<String, List<String>> locations;
  @override
  Widget build(BuildContext context) => _SectionCard(
          number: '۳',
          title: 'اطلاعات تماس و نشانی',
          icon: Icons.location_on_outlined,
          children: [
            _ResponsivePair(children: [
              _field(context, 'phone', 'شماره موبایل یا تلفن', state.phone,
                  numeric: true),
              _field(context, 'email', 'ایمیل', state.email,
                  keyboard: TextInputType.emailAddress)
            ]),
            const SizedBox(height: 8),
            _field(context, 'website', 'وب‌سایت (اختیاری)', state.website,
                keyboard: TextInputType.url),
            const SizedBox(height: 8),
            _ResponsivePair(children: [
              _select(context, 'province', 'استان', state.province,
                  locations.keys.toList()),
              _select(context, 'city', 'شهر', state.city,
                  locations[state.province] ?? const [],
                  enabled: state.province.isNotEmpty)
            ]),
            const SizedBox(height: 8),
            _field(context, 'address', 'آدرس قانونی', state.address),
            const SizedBox(height: 8),
            _field(context, 'postalCode', 'کد پستی', state.postalCode,
                numeric: true),
          ]);
}

class _FinancialSection extends StatelessWidget {
  const _FinancialSection({required this.state});
  final OfficeFormState state;
  @override
  Widget build(BuildContext context) => _SectionCard(
          number: '۴',
          title: 'تنظیمات مالی و کدینگ',
          icon: Icons.tune_rounded,
          children: [
            _ResponsivePair(children: [
              _select(context, 'fiscalYear', 'سال مالی', state.fiscalYear,
                  const ['۱۴۰۵', '۱۴۰۶']),
              _select(
                  context,
                  'chartTemplate',
                  'الگوی کدینگ',
                  state.chartTemplate,
                  const ['استاندارد ایران', 'خدماتی', 'بازرگانی', 'تولیدی'])
            ]),
            const SizedBox(height: 8),
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FF),
                    border: Border.all(color: const Color(0xFFD9E5F5)),
                    borderRadius: BorderRadius.circular(10)),
                child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AsoudColors.primary, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'راهنما\nالگوی کدینگ بر اساس نوع فعالیت انتخاب می‌شود؛ تولید کد نهایی فقط در Backend انجام خواهد شد.',
                              style: TextStyle(
                                  fontSize: 9,
                                  height: 1.6,
                                  color: AsoudColors.muted)))
                    ])),
          ]);
}

class _LogoSection extends StatelessWidget {
  const _LogoSection({required this.state, required this.onPick});
  final OfficeFormState state;
  final VoidCallback onPick;
  @override
  Widget build(BuildContext context) => _SectionCard(
          number: '۵',
          title: 'بارگذاری لوگو',
          icon: Icons.image_outlined,
          children: [
            CustomPaint(
                painter: _DashedBorderPainter(),
                child: InkWell(
                    onTap: onPick,
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                        height: 86,
                        width: double.infinity,
                        child: state.logoBytes == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        color: AsoudColors.primary),
                                    SizedBox(height: 5),
                                    Text('برای بارگذاری لوگو کلیک کنید',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: AsoudColors.primary,
                                            fontWeight: FontWeight.w700)),
                                    Text('PNG یا JPG، حداکثر ۲ مگابایت',
                                        style: TextStyle(
                                            fontSize: 8,
                                            color: AsoudColors.muted))
                                  ])
                            : _LogoPreview(
                                bytes: state.logoBytes!,
                                name: state.logoName ?? 'logo')))),
          ]);
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover)),
        const SizedBox(width: 10),
        Flexible(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10))),
        IconButton(
            tooltip: 'حذف لوگو',
            onPressed: () =>
                context.read<OfficeFormBloc>().add(const OfficeLogoChanged()),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AsoudColors.danger))
      ]);
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.state});
  final OfficeFormState state;
  @override
  Widget build(BuildContext context) => _SectionCard(
          number: '۶',
          title: 'توضیحات',
          icon: Icons.description_outlined,
          children: [
            _field(context, 'description', 'توضیحات خود را وارد کنید…',
                state.description,
                maxLines: 4, maxLength: 500)
          ]);
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.number,
      required this.title,
      required this.icon,
      required this.children});
  final String number, title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              AsoudIconBox(icon: icon, color: AsoudColors.primary, size: 28),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$number. $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            ]),
            const SizedBox(height: 10),
            ...children
          ])));
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 320
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: children[0]),
              const SizedBox(width: 8),
              Expanded(child: children[1])
            ])
          : Column(
              children: [children[0], const SizedBox(height: 8), children[1]]));
}

Widget _field(BuildContext context, String key, String label, String value,
        {bool numeric = false,
        TextInputType? keyboard,
        int maxLines = 1,
        int? maxLength}) =>
    TextFormField(
      key: ValueKey('office-$key'),
      initialValue: value,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboard ??
          (numeric
              ? TextInputType.number
              : maxLines > 1
                  ? TextInputType.multiline
                  : TextInputType.text),
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
          labelText: label,
          errorText: context.watch<OfficeFormBloc>().state.errors[key],
          counterText: maxLength == null ? null : ''),
      onChanged: (v) =>
          context.read<OfficeFormBloc>().add(OfficeFieldChanged(key, v)),
    );

Widget _select(BuildContext context, String key, String label, String value,
        List<String> items,
        {bool required = true, bool enabled = true}) =>
    DropdownButtonFormField<String>(
      key: ValueKey('office-$key-$value'),
      isExpanded: true,
      initialValue: items.contains(value) ? value : null,
      decoration: InputDecoration(
          labelText: label,
          errorText: context.watch<OfficeFormBloc>().state.errors[key]),
      items: items
          .map((v) => DropdownMenuItem(
              value: v, child: Text(v, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: enabled
          ? (v) => context
              .read<OfficeFormBloc>()
              .add(OfficeFieldChanged(key, v ?? ''))
          : null,
    );

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFD2F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(10)));
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
