import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_exception.dart';
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
    } catch (error) {
      emit(state.copyWith(
          status: HrStatus.failure, message: _dashboardErrorMessage(error)));
    }
  }

  String _dashboardErrorMessage(Object error) {
    if (error is ApiException &&
        error.message.contains('No active Employee is linked')) {
      return 'دریافت خدمات منابع انسانی ممکن نشد. دلیل: حساب کاربری شما به پرسنل فعال متصل نیست.';
    }
    if (error is ApiException) {
      final reason = switch (error.kind) {
        ApiFailureKind.invalidCredentials => 'اطلاعات ورود معتبر نیست.',
        ApiFailureKind.unauthenticated => 'نشست کاربری معتبر نیست.',
        ApiFailureKind.validation => 'اطلاعات یا دسترسی لازم کامل نیست.',
        ApiFailureKind.forbidden => 'دسترسی لازم برای این بخش وجود ندارد.',
        ApiFailureKind.conflict => 'اطلاعات سرور با درخواست تداخل دارد.',
        ApiFailureKind.rateLimited => 'تعداد درخواست‌ها بیش از حد مجاز است.',
        ApiFailureKind.timeout => 'پاسخ سرور بیش از حد طول کشید.',
        ApiFailureKind.network => 'ارتباط با سرور برقرار نشد.',
        ApiFailureKind.server => 'سرور هنگام پردازش با خطا روبه‌رو شد.',
        ApiFailureKind.protocol => 'پاسخ سرور قابل پردازش نیست.',
        ApiFailureKind.responseTooLarge => 'پاسخ سرور بیش از حد بزرگ است.',
        ApiFailureKind.cancelled => 'دریافت اطلاعات لغو شد.',
      };
      return 'دریافت خدمات منابع انسانی ممکن نشد. دلیل: $reason';
    }
    return 'دریافت خدمات منابع انسانی ممکن نشد. دلیل: خطای پیش‌بینی‌نشده رخ داد.';
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
