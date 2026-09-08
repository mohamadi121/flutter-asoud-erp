import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/personnel_repository.dart';

class PersonnelState {
  const PersonnelState(
      {this.rows = const [],
      this.loading = false,
      this.error,
      this.offline = false,
      this.pendingSync = false,
      this.syncFailed = false,
      this.canEdit = false,
      this.query = '',
      this.department = '',
      this.status = 'all'});
  final List<Map<String, dynamic>> rows;
  final bool loading, canEdit;
  final bool offline, pendingSync, syncFailed;
  final String? error;
  final String query, department, status;
  List<Map<String, dynamic>> get visible => rows.where((r) {
        final haystack =
            '${r['display_name']} ${r['national_id']} ${r['job_title']} ${r['department']}'
                .toLowerCase();
        return haystack.contains(query.toLowerCase().trim()) &&
            (department.isEmpty || r['department'] == department) &&
            (status == 'all' ||
                (r['disabled'] == true) == (status == 'inactive'));
      }).toList();
}

class PersonnelCubit extends Cubit<PersonnelState> {
  PersonnelCubit(this.repository, this.company) : super(const PersonnelState());
  final PersonnelRepository repository;
  final String company;
  @override
  Future<void> close() {
    repository.dispose();
    return super.close();
  }

  void filter({String? query, String? department, String? status}) =>
      emit(PersonnelState(
          rows: state.rows,
          canEdit: state.canEdit,
          offline: state.offline,
          pendingSync: state.pendingSync,
          syncFailed: state.syncFailed,
          query: query ?? state.query,
          department: department ?? state.department,
          status: status ?? state.status));
  Future<void> load() async {
    final previous = state;
    emit(PersonnelState(
        rows: previous.rows, loading: true, canEdit: previous.canEdit));
    try {
      final data = await repository.list(company);
      if (isClosed) return;
      emit(PersonnelState(
          rows: (data['rows'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList(),
          canEdit: data['can_edit'] == true,
          offline: data['offline'] == true,
          pendingSync: data['pending_sync'] == true,
          syncFailed: data['sync_failed'] == true,
          query: previous.query,
          department: previous.department,
          status: previous.status));
    } catch (_) {
      if (!isClosed) {
        emit(const PersonnelState(
            error:
                'دریافت لیست پرسنل ممکن نشد؛ اتصال و دسترسی را بررسی کنید.'));
      }
    }
  }
}
