import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/trial_balance.dart';
import '../../domain/repositories/reports_repository.dart';

enum ReportStatus { initial, loading, success, failure }

class TrialBalanceState extends Equatable {
  const TrialBalanceState({this.status = ReportStatus.initial, this.report, this.message});
  final ReportStatus status;
  final TrialBalanceReport? report;
  final String? message;
  @override
  List<Object?> get props => [status, report, message];
}

class TrialBalanceCubit extends Cubit<TrialBalanceState> {
  TrialBalanceCubit(this._repository) : super(const TrialBalanceState());
  final ReportsRepository _repository;

  Future<void> load({required String company, required DateTime fromDate, required DateTime toDate, String? account}) async {
    emit(const TrialBalanceState(status: ReportStatus.loading));
    try {
      final report = await _repository.getTrialBalance(company: company, fromDate: fromDate, toDate: toDate, account: account);
      emit(TrialBalanceState(status: ReportStatus.success, report: report));
    } catch (error) {
      emit(TrialBalanceState(status: ReportStatus.failure, message: error.toString()));
    }
  }
}
