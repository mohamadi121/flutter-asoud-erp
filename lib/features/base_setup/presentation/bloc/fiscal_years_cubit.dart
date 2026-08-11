import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/offline/offline_failure.dart';
import '../../domain/repositories/base_setup_repository.dart';

enum FiscalYearsStatus {
  initial,
  loading,
  success,
  empty,
  saving,
  offlineSaved,
  failure,
}

class FiscalYearsState extends Equatable {
  const FiscalYearsState({
    this.status = FiscalYearsStatus.initial,
    this.items = const [],
    this.message,
  });
  final FiscalYearsStatus status;
  final List<FiscalYearInfo> items;
  final String? message;
  @override
  List<Object?> get props => [status, items, message];
}

class FiscalYearsCubit extends Cubit<FiscalYearsState> {
  FiscalYearsCubit({
    required this.company,
    required this.repository,
    required this.offlinePreview,
  }) : super(const FiscalYearsState());

  final String company;
  final BaseSetupRepository repository;
  final bool offlinePreview;

  Future<void> load() async {
    emit(const FiscalYearsState(status: FiscalYearsStatus.loading));
    try {
      final items = await repository.getFiscalYears(company);
      emit(FiscalYearsState(
        status:
            items.isEmpty ? FiscalYearsStatus.empty : FiscalYearsStatus.success,
        items: items,
      ));
    } catch (_) {
      emit(const FiscalYearsState(
        status: FiscalYearsStatus.failure,
        message: 'دریافت سال‌های مالی از ASOUD ERP انجام نشد.',
      ));
    }
  }

  Future<bool> create(int year, int month, int day) async {
    final items = state.items;
    emit(FiscalYearsState(status: FiscalYearsStatus.saving, items: items));
    try {
      await repository.createFiscalYear(company, year, month, day);
      await load();
      return true;
    } catch (error) {
      if (isRetryableOfflineFailure(error)) {
        await load();
        emit(FiscalYearsState(
          status: FiscalYearsStatus.offlineSaved,
          items: state.items,
          message:
              'اتصال برقرار نیست؛ سال مالی روی گوشی ذخیره شد و در انتظار همگام‌سازی است.',
        ));
        return true;
      }
      emit(FiscalYearsState(
        status: FiscalYearsStatus.failure,
        items: items,
        message: 'ایجاد سال مالی در ASOUD ERP انجام نشد.',
      ));
      return false;
    }
  }
}
