import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/accounting_voucher.dart';
import '../../domain/repositories/vouchers_repository.dart';

enum VoucherFormStatus { editing, saving, success, failure }

class VoucherFormState extends Equatable {
  const VoucherFormState({required this.voucher, this.status = VoucherFormStatus.editing, this.message});
  final AccountingVoucher voucher;
  final VoucherFormStatus status;
  final String? message;
  bool get canSave => voucher.isValid && status != VoucherFormStatus.saving;

  VoucherFormState copyWith({AccountingVoucher? voucher, VoucherFormStatus? status, String? message}) =>
      VoucherFormState(voucher: voucher ?? this.voucher, status: status ?? this.status, message: message);

  @override
  List<Object?> get props => [voucher, status, message];
}

class VoucherFormCubit extends Cubit<VoucherFormState> {
  VoucherFormCubit(this._repository, AccountingVoucher voucher) : super(VoucherFormState(voucher: voucher));
  final VouchersRepository _repository;

  void replaceLines(List<VoucherLine> lines) => emit(state.copyWith(voucher: _copy(lines: lines)));
  void updateHeader({String? company, String? description, DateTime? date}) =>
      emit(state.copyWith(voucher: _copy(company: company, description: description, date: date)));

  AccountingVoucher _copy({String? company, String? description, DateTime? date, List<VoucherLine>? lines}) => AccountingVoucher(
        id: state.voucher.id,
        company: company ?? state.voucher.company,
        postingDate: date ?? state.voucher.postingDate,
        description: description ?? state.voucher.description,
        status: state.voucher.status,
        lines: lines ?? state.voucher.lines,
        rejectionReason: state.voucher.rejectionReason,
        journalEntry: state.voucher.journalEntry,
      );

  Future<void> save({bool submit = false}) async {
    if (!state.canSave) return;
    emit(state.copyWith(status: VoucherFormStatus.saving));
    try {
      var saved = await _repository.saveVoucher(state.voucher);
      if (submit) saved = await _repository.submitForApproval(saved.id);
      emit(VoucherFormState(voucher: saved, status: VoucherFormStatus.success));
    } catch (error) {
      emit(state.copyWith(status: VoucherFormStatus.failure, message: error.toString()));
    }
  }
}
