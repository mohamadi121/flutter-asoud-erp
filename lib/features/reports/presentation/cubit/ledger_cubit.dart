import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/ledger_report.dart';
import '../../domain/repositories/reports_repository.dart';
import 'trial_balance_cubit.dart';

class LedgerState extends Equatable {
  const LedgerState({this.status = ReportStatus.initial, this.report, this.message});
  final ReportStatus status;
  final LedgerReport? report;
  final String? message;
  @override
  List<Object?> get props => [status, report, message];
}

class LedgerCubit extends Cubit<LedgerState> {
  LedgerCubit(this._repository) : super(const LedgerState());
  final ReportsRepository _repository;

  Future<void> load({required String company, required DateTime fromDate, required DateTime toDate, required String account, String? partyType, String? party}) async {
    emit(const LedgerState(status: ReportStatus.loading));
    try {
      final report = await _repository.getLedger(company: company, fromDate: fromDate, toDate: toDate, account: account, partyType: partyType, party: party);
      emit(LedgerState(status: ReportStatus.success, report: report));
    } catch (error) {
      emit(LedgerState(status: ReportStatus.failure, message: error.toString()));
    }
  }
}
