import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/purchase_request.dart';
import '../../domain/purchase_request_repository.dart';

enum PurchaseRequestStatus { loading, editing, submitting, success, failure }

class PurchaseRequestState extends Equatable {
  const PurchaseRequestState({
    this.status = PurchaseRequestStatus.loading,
    this.options = const PurchaseRequestOptions(),
    this.lines = const [],
    this.result,
    this.message,
  });
  final PurchaseRequestStatus status;
  final PurchaseRequestOptions options;
  final List<PurchaseRequestLine> lines;
  final PurchaseRequestResult? result;
  final String? message;
  PurchaseRequestState copyWith({
    PurchaseRequestStatus? status,
    PurchaseRequestOptions? options,
    List<PurchaseRequestLine>? lines,
    PurchaseRequestResult? result,
    String? message,
  }) =>
      PurchaseRequestState(
        status: status ?? this.status,
        options: options ?? this.options,
        lines: lines ?? this.lines,
        result: result ?? this.result,
        message: message,
      );
  @override
  List<Object?> get props => [status, options, lines, result, message];
}

class PurchaseRequestCubit extends Cubit<PurchaseRequestState> {
  PurchaseRequestCubit(this._repository, this.company)
      : super(const PurchaseRequestState());
  final PurchaseRequestRepository _repository;
  final String company;

  Future<void> load() async {
    emit(state.copyWith(status: PurchaseRequestStatus.loading));
    try {
      emit(state.copyWith(
        status: PurchaseRequestStatus.editing,
        options: await _repository.options(company),
      ));
    } catch (error) {
      emit(state.copyWith(
        status: PurchaseRequestStatus.failure,
        message: error.toString(),
      ));
    }
  }

  void addLine(PurchaseRequestLine line) => emit(state.copyWith(
        status: PurchaseRequestStatus.editing,
        lines: [...state.lines, line],
      ));

  void removeLine(int index) {
    final lines = [...state.lines]..removeAt(index);
    emit(state.copyWith(status: PurchaseRequestStatus.editing, lines: lines));
  }

  Future<bool> submit(String subject, DateTime scheduleDate) async {
    if (subject.trim().length < 3) {
      emit(state.copyWith(message: 'عنوان درخواست باید حداقل ۳ حرف باشد.'));
      return false;
    }
    if (state.lines.isEmpty) {
      emit(state.copyWith(message: 'حداقل یک قلم کالا اضافه کنید.'));
      return false;
    }
    emit(state.copyWith(status: PurchaseRequestStatus.submitting));
    try {
      final result = await _repository.create(
        company: company,
        subject: subject,
        scheduleDate: scheduleDate,
        items: state.lines,
      );
      emit(state.copyWith(
        status: PurchaseRequestStatus.success,
        result: result,
        message: result.localOnly
            ? 'درخواست داخل گوشی ذخیره شد و پس از اتصال باید همگام شود.'
            : 'درخواست ثبت و وارد گردش‌کار شد.',
      ));
      return true;
    } catch (error) {
      emit(state.copyWith(
        status: PurchaseRequestStatus.failure,
        message: error.toString(),
      ));
      return false;
    }
  }
}
