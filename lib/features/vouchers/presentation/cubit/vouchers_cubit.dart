import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/accounting_voucher.dart';
import '../../domain/repositories/vouchers_repository.dart';

enum VouchersStatus { initial, loading, success, failure }

class VouchersState extends Equatable {
  const VouchersState({this.status = VouchersStatus.initial, this.items = const [], this.message});
  final VouchersStatus status;
  final List<AccountingVoucher> items;
  final String? message;
  @override
  List<Object?> get props => [status, items, message];
}

class VouchersCubit extends Cubit<VouchersState> {
  VouchersCubit(this._repository) : super(const VouchersState());
  final VouchersRepository _repository;

  Future<void> load(String company, {VoucherStatus? status, String? search}) async {
    emit(const VouchersState(status: VouchersStatus.loading));
    try {
      emit(VouchersState(status: VouchersStatus.success, items: await _repository.getVouchers(company, status: status, search: search)));
    } catch (error) {
      emit(VouchersState(status: VouchersStatus.failure, message: error.toString()));
    }
  }

  Future<void> approve(String id) => _transition(() => _repository.approve(id));
  Future<void> reject(String id, String reason) => _transition(() => _repository.reject(id, reason));

  Future<void> _transition(Future<AccountingVoucher> Function() action) async {
    try {
      final updated = await action();
      emit(VouchersState(
        status: VouchersStatus.success,
        items: state.items.map((item) => item.id == updated.id ? updated : item).toList(),
      ));
    } catch (error) {
      emit(VouchersState(status: VouchersStatus.failure, items: state.items, message: error.toString()));
    }
  }
}
