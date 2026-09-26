import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/organization_repository.dart';
import '../../domain/organization_chart.dart';

class OrganizationState {
  const OrganizationState(
      {this.snapshot = const OrganizationSnapshot([], 0, false),
      this.busy = false,
      this.sessionChanged = false,
      this.error});
  final OrganizationSnapshot snapshot;
  final bool busy;
  final bool sessionChanged;
  final String? error;
}

class OrganizationCubit extends Cubit<OrganizationState> {
  OrganizationCubit(this.repository, this.company)
      : super(const OrganizationState()) {
    _session = repository.authenticationChanges.listen((_) {
      _epoch++;
      if (!isClosed) emit(const OrganizationState(sessionChanged: true));
    });
  }
  late final StreamSubscription<bool> _session;
  int _epoch = 0;
  @override
  Future<void> close() async {
    _epoch++;
    await _session.cancel();
    await repository.dispose();
    return super.close();
  }

  final OrganizationRepository repository;
  final String company;
  Future<void> load() async {
    if (state.busy || isClosed || state.sessionChanged) return;
    final epoch = _epoch;
    emit(OrganizationState(snapshot: state.snapshot, busy: true));
    try {
      final result = await repository.load(company);
      if (!isClosed && epoch == _epoch)
        emit(OrganizationState(snapshot: result));
    } catch (e) {
      if (!isClosed && epoch == _epoch) {
        emit(OrganizationState(
            snapshot: e is ApiException &&
                    (e.isUnauthorized || e.kind == ApiFailureKind.forbidden)
                ? const OrganizationSnapshot([], 0, false)
                : state.snapshot,
            error: e is ApiException
                ? e.message
                : 'دریافت چارت ممکن نشد؛ دوباره تلاش کنید.'));
      }
    }
  }

  Future<bool> save(List<OrgPosition> rows) async {
    if (state.busy || isClosed || state.sessionChanged) return false;
    final epoch = _epoch;
    if (state.snapshot.server != null &&
        state.snapshot.server!.revision != state.snapshot.revision) {
      emit(OrganizationState(
          snapshot: state.snapshot,
          error:
              'نسخه سرور تغییر کرده؛ ابتدا مقایسه و انتخاب نسخه را انجام دهید.'));
      return false;
    }
    emit(OrganizationState(snapshot: state.snapshot, busy: true));
    try {
      final result =
          await repository.save(company, rows, state.snapshot.revision);
      if (isClosed || epoch != _epoch) return false;
      emit(OrganizationState(snapshot: result));
      return true;
    } catch (e) {
      if (!isClosed && epoch == _epoch) {
        emit(OrganizationState(
            snapshot: e is ApiException &&
                    (e.isUnauthorized || e.kind == ApiFailureKind.forbidden)
                ? const OrganizationSnapshot([], 0, false)
                : OrganizationSnapshot(rows, state.snapshot.revision, true,
                    server: state.snapshot.server, rejected: true),
            error: e is FormatException
                ? e.message
                : e is ApiException
                    ? e.message
                    : 'ذخیره تأیید نشد؛ اتصال، دسترسی یا تعارض نسخه را بررسی کنید.'));
      }
      return false;
    }
  }

  Future<void> resolve({required bool useServer}) async {
    if (state.busy ||
        isClosed ||
        state.sessionChanged ||
        state.snapshot.server == null) return;
    final epoch = _epoch;
    emit(OrganizationState(snapshot: state.snapshot, busy: true));
    try {
      final result = await repository.resolve(company, state.snapshot,
          useServer: useServer);
      if (!isClosed && epoch == _epoch)
        emit(OrganizationState(snapshot: result));
    } catch (e) {
      if (!isClosed && epoch == _epoch)
        emit(OrganizationState(
            snapshot: state.snapshot,
            error: e is ApiException ? e.message : 'انتخاب نسخه انجام نشد.'));
    }
  }
}
