import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/hr_models.dart';
import '../../domain/hr_repository.dart';

enum HrStatus { initial, loading, success, failure }

class HrState extends Equatable {
  const HrState(
      {this.status = HrStatus.initial,
      this.dashboard,
      this.team = const [],
      this.reports = const [],
      this.communications = const [],
      this.notifications = const [],
      this.message});
  final HrStatus status;
  final HrDashboard? dashboard;
  final List<HrEmployee> team;
  final List<WorkReport> reports;
  final List<HrCommunication> communications;
  final List<Map<String, dynamic>> notifications;
  final String? message;
  HrState copyWith(
          {HrStatus? status,
          HrDashboard? dashboard,
          List<HrEmployee>? team,
          List<WorkReport>? reports,
          List<HrCommunication>? communications,
          List<Map<String, dynamic>>? notifications,
          String? message}) =>
      HrState(
          status: status ?? this.status,
          dashboard: dashboard ?? this.dashboard,
          team: team ?? this.team,
          reports: reports ?? this.reports,
          communications: communications ?? this.communications,
          notifications: notifications ?? this.notifications,
          message: message);
  @override
  List<Object?> get props => [
        status,
        dashboard,
        team,
        reports,
        communications,
        notifications,
        message
      ];
}

class HrCubit extends Cubit<HrState> {
  HrCubit(this.repository, this.company) : super(const HrState());
  final HrRepository repository;
  final String company;
  Future<void> loadDashboard() async {
    emit(state.copyWith(status: HrStatus.loading));
    try {
      emit(state.copyWith(
          status: HrStatus.success,
          dashboard: await repository.dashboard(company)));
    } catch (_) {
      emit(state.copyWith(
          status: HrStatus.failure,
          message: 'دریافت داشبورد منابع انسانی ممکن نشد.'));
    }
  }

  Future<void> loadTeam() async {
    emit(state.copyWith(status: HrStatus.loading));
    try {
      emit(state.copyWith(
          status: HrStatus.success, team: await repository.team()));
    } catch (_) {
      emit(state.copyWith(
          status: HrStatus.failure, message: 'دریافت فهرست پرسنل ممکن نشد.'));
    }
  }

  Future<void> loadReports() async {
    emit(state.copyWith(status: HrStatus.loading));
    try {
      emit(state.copyWith(
          status: HrStatus.success, reports: await repository.reports()));
    } catch (_) {
      emit(state.copyWith(
          status: HrStatus.failure, message: 'دریافت گزارش‌های کار ممکن نشد.'));
    }
  }

  Future<void> saveReport(WorkReport value) async {
    await repository.saveReport(value);
    await loadReports();
  }

  Future<void> loadCommunications() async {
    emit(state.copyWith(status: HrStatus.loading));
    try {
      emit(state.copyWith(
          status: HrStatus.success,
          communications: await repository.communications()));
    } catch (_) {
      emit(state.copyWith(
          status: HrStatus.failure, message: 'دریافت مکاتبات ممکن نشد.'));
    }
  }

  Future<void> sendCommunication(HrCommunication value) async {
    await repository.sendCommunication(value);
    await loadCommunications();
  }

  Future<void> loadNotifications() async {
    emit(state.copyWith(status: HrStatus.loading));
    try {
      emit(state.copyWith(
          status: HrStatus.success,
          notifications: await repository.notifications()));
    } catch (_) {
      emit(state.copyWith(
          status: HrStatus.failure, message: 'دریافت اعلان‌ها ممکن نشد.'));
    }
  }
}
