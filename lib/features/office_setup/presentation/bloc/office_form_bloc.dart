import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/offline/offline_failure.dart';
import '../../../../core/offline/queued_offline_exception.dart';
import '../../domain/entities/office.dart';
import '../../domain/repositories/office_repository.dart';

part 'office_form_event.dart';
part 'office_form_state.dart';

class OfficeFormBloc extends Bloc<OfficeFormEvent, OfficeFormState> {
  OfficeFormBloc({
    required OfficeType officeType,
    required OfficeRepository repository,
    Office? office,
    this.allowOfflinePreview = AppConfig.offlineDemoMode,
  })  : _repository = repository,
        _originalOffice = office,
        super(OfficeFormState(
          officeType: office?.type ?? officeType,
          officeName: office?.name ?? '',
          ownerFullName: office?.ownerFullName ?? '',
          registrationNumber: office?.registrationNumber ?? '',
          nationalId: office?.nationalId ?? '',
          activityType: office?.activityType ?? 'بازرگانی',
          companyType: office?.companyType ??
              (officeType == OfficeType.legal ? 'سهامی خاص' : ''),
          parentOffice: office?.parentOffice ?? 'ندارد',
          phone: office?.phone ?? '',
          email: office?.email ?? '',
          website: office?.website ?? '',
          province: office?.province ?? 'تهران',
          city: office?.city ?? 'تهران',
          address: office?.address ?? '',
          postalCode: office?.postalCode ?? '',
          fiscalYear: office?.fiscalYear ?? '۱۴۰۵',
          chartTemplate: office?.chartTemplate ?? 'استاندارد ایران',
          description: office?.description ?? '',
        )) {
    on<OfficeTypeChanged>((event, emit) => emit(state.copyWith(
          officeType: event.value,
          activityType: state.activityType.isEmpty ? 'بازرگانی' : null,
          companyType:
              event.value == OfficeType.legal && state.companyType.isEmpty
                  ? 'سهامی خاص'
                  : null,
        )));
    on<OfficeFieldChanged>(_fieldChanged);
    on<OfficeLogoChanged>((event, emit) => emit(event.bytes == null
        ? state.copyWith(clearLogo: true)
        : state.copyWith(logoName: event.name, logoBytes: event.bytes)));
    on<OfficeFormSubmitted>(_submit);
    on<OfficeSuggestionRequested>((event, emit) {
      if (_originalOffice != null ||
          state.status == OfficeFormStatus.submitting) {
        return;
      }
      emit(state.copyWith(
        suggestionRevision: state.suggestionRevision + 1,
        officeName: state.officeName.trim().isEmpty
            ? (state.officeType == OfficeType.legal
                ? 'شرکت نمونه آسود'
                : 'دفتر حقیقی نمونه آسود')
            : null,
        ownerFullName: state.ownerFullName.trim().isEmpty &&
                state.officeType != OfficeType.legal
            ? 'مالک نمونه'
            : null,
        description: state.description.trim().isEmpty
            ? 'اطلاعات نمونه و قابل ویرایش؛ پیش از استفاده واقعی تکمیل شود.'
            : null,
        errors: const {},
        message:
            'اطلاعات نمونه فقط در فرم قرار گرفت؛ برای نگهداری، دکمه ذخیره را بزنید.',
      ));
    });
  }

  final OfficeRepository _repository;
  final Office? _originalOffice;
  final bool allowOfflinePreview;

  void _fieldChanged(OfficeFieldChanged event, Emitter<OfficeFormState> emit) {
    var next = switch (event.field) {
      'officeName' => state.copyWith(officeName: event.value as String),
      'ownerFullName' => state.copyWith(ownerFullName: event.value as String),
      'registrationNumber' =>
        state.copyWith(registrationNumber: event.value as String),
      'nationalId' => state.copyWith(nationalId: event.value as String),
      'activityType' => state.copyWith(activityType: event.value as String),
      'companyType' => state.copyWith(companyType: event.value as String),
      'independent' =>
        state.copyWith(hasIndependentPersonality: event.value as bool),
      'parentOffice' => state.copyWith(parentOffice: event.value as String),
      'phone' => state.copyWith(phone: event.value as String),
      'email' => state.copyWith(email: event.value as String),
      'website' => state.copyWith(website: event.value as String),
      'province' => state.copyWith(province: event.value as String, city: ''),
      'city' => state.copyWith(city: event.value as String),
      'address' => state.copyWith(address: event.value as String),
      'postalCode' => state.copyWith(postalCode: event.value as String),
      'fiscalYear' => state.copyWith(fiscalYear: event.value as String),
      'chartTemplate' => state.copyWith(chartTemplate: event.value as String),
      'description' => state.copyWith(description: event.value as String),
      _ => state,
    };
    if (state.errors.containsKey(event.field)) {
      final errors = Map<String, String>.from(state.errors)
        ..remove(event.field);
      next = next.copyWith(errors: errors);
    }
    emit(next);
  }

  Future<void> _submit(
      OfficeFormSubmitted event, Emitter<OfficeFormState> emit) async {
    if (state.status == OfficeFormStatus.submitting) return;
    final errors = _validate(state);
    if (errors.isNotEmpty) {
      emit(state.copyWith(
          status: OfficeFormStatus.invalid,
          errors: errors,
          message: 'فیلدهای مشخص‌شده را بررسی کنید.'));
      return;
    }
    emit(state.copyWith(
        status: OfficeFormStatus.submitting,
        errors: const {},
        clearMessage: true));
    try {
      final draft = Office(
        name: state.officeName.trim(),
        type: state.officeType,
        fiscalYearStart: DateTime(DateTime.now().year, 1),
        nationalId: state.nationalId.trim(),
        ownerFullName: state.ownerFullName.trim(),
        registrationNumber: state.registrationNumber.trim(),
        activityType: state.activityType.trim(),
        companyType: state.companyType.trim(),
        parentOffice: state.parentOffice.trim(),
        phone: state.phone.trim(),
        email: state.email.trim(),
        website: state.website.trim(),
        province: state.province.trim(),
        city: state.city.trim(),
        address: state.address.trim(),
        postalCode: state.postalCode.trim(),
        fiscalYear: state.fiscalYear.trim(),
        chartTemplate: state.chartTemplate.trim(),
        description: state.description.trim(),
      );
      final office = _originalOffice == null
          ? await _repository.createOffice(draft)
          : await _repository.updateOffice(_originalOffice.name, draft);
      final Object repository = _repository;
      final local = repository is LocalPreviewOfficeRepository &&
          repository.isLocalPreview;
      emit(state.copyWith(
          status: local
              ? OfficeFormStatus.offlinePreview
              : OfficeFormStatus.success,
          createdOffice: office,
          message: local
              ? 'دفتر روی همین دستگاه ذخیره شد؛ هنوز روی سرور ثبت نشده است.'
              : 'دفتر کار با موفقیت ذخیره شد.'));
    } catch (error) {
      if (isRetryableOfflineFailure(error)) {
        emit(state.copyWith(
          status: OfficeFormStatus.offlinePreview,
          createdOffice: _draftOffice(),
          message: error is QueuedOfflineException
              ? error.message
              : 'اتصال برقرار نیست؛ دفتر روی گوشی ذخیره شد و در انتظار همگام‌سازی است.',
        ));
        return;
      }
      final message = error is ApiException
          ? error.message
          : 'خطای غیرمنتظره‌ای رخ داد. دوباره تلاش کنید.';
      emit(state.copyWith(status: OfficeFormStatus.failure, message: message));
    }
  }

  Office _draftOffice() => Office(
        name: state.officeName.trim(),
        type: state.officeType,
        fiscalYearStart: DateTime(DateTime.now().year, 1),
        nationalId: state.nationalId.trim(),
        ownerFullName: state.ownerFullName.trim(),
        registrationNumber: state.registrationNumber.trim(),
        activityType: state.activityType.trim(),
        companyType: state.companyType.trim(),
        parentOffice: state.parentOffice.trim(),
        phone: state.phone.trim(),
        email: state.email.trim(),
        website: state.website.trim(),
        province: state.province.trim(),
        city: state.city.trim(),
        address: state.address.trim(),
        postalCode: state.postalCode.trim(),
        fiscalYear: state.fiscalYear.trim(),
        chartTemplate: state.chartTemplate.trim(),
        description: state.description.trim(),
      );

  Map<String, String> _validate(OfficeFormState s) {
    final e = <String, String>{};
    void required(String key, String value) {
      if (value.trim().isEmpty) e[key] = 'این فیلد الزامی است.';
    }

    required('officeName', s.officeName);
    final digits = s.nationalId.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty &&
        digits.length != (s.officeType == OfficeType.legal ? 11 : 10)) {
      e['nationalId'] = 'تعداد ارقام معتبر نیست.';
    }
    if (s.phone.isNotEmpty && !RegExp(r'^0\d{9,10}$').hasMatch(s.phone)) {
      e['phone'] = 'شماره تماس معتبر نیست.';
    }
    if (s.email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.email)) {
      e['email'] = 'ایمیل معتبر نیست.';
    }
    if (s.website.isNotEmpty &&
        Uri.tryParse(s.website)?.hasAbsolutePath != true) {
      e['website'] = 'نشانی وب معتبر نیست.';
    }
    if (s.postalCode.isNotEmpty &&
        !RegExp(r'^\d{10}$').hasMatch(s.postalCode)) {
      e['postalCode'] = 'کد پستی باید ۱۰ رقم باشد.';
    }
    return e;
  }
}
