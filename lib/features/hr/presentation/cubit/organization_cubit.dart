import 'package:bloc/bloc.dart';
import '../../data/organization_repository.dart';
import '../../domain/organization_chart.dart';

class OrganizationState {
  const OrganizationState(
      {this.snapshot = const OrganizationSnapshot([], 0, false),
      this.busy = false,
      this.error});
  final OrganizationSnapshot snapshot;
  final bool busy;
  final String? error;
}

class OrganizationCubit extends Cubit<OrganizationState> {
  OrganizationCubit(this.repository, this.company)
      : super(const OrganizationState());
  final OrganizationRepository repository;
  final String company;
  Future<void> load() async {
    emit(OrganizationState(snapshot: state.snapshot, busy: true));
    try {
      final result = await repository.load(company);
      if (!isClosed) emit(OrganizationState(snapshot: result));
    } catch (_) {
      if (!isClosed) {
        emit(OrganizationState(
            snapshot: state.snapshot,
            error: 'دریافت چارت ممکن نشد؛ دوباره تلاش کنید.'));
      }
    }
  }

  Future<bool> save(List<OrgPosition> rows) async {
    if (state.busy) return false;
    emit(OrganizationState(snapshot: state.snapshot, busy: true));
    try {
      final result =
          await repository.save(company, rows, state.snapshot.revision);
      if (!isClosed) emit(OrganizationState(snapshot: result));
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(OrganizationState(
            snapshot: state.snapshot,
            error: e is FormatException
                ? e.message
                : 'ذخیره تأیید نشد؛ اتصال، دسترسی یا تعارض نسخه را بررسی کنید.'));
      }
      return false;
    }
  }
}
