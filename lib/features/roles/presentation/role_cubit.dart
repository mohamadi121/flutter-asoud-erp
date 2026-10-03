import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_exception.dart';
import '../data/role_repository.dart';
import '../domain/role_catalog.dart';

String roleFailure(Object error) {
  if (error is FormatException) return error.message;
  if (error is ApiException) return error.message;
  if (error is TimeoutException) {
    return 'پاسخ سرور دریافت نشد. پیش از تکرار ذخیره، فهرست را بازخوانی کنید.';
  }
  return 'عملیات نقش‌ها تأیید نشد؛ اتصال و نصب نسخه جدید بک‌اند را بررسی کنید.';
}

class RoleState {
  const RoleState(
      {this.catalog = const RoleCatalog(),
      this.loading = false,
      this.saving = false,
      this.loaded = false,
      this.sessionEnded = false,
      this.error});
  final RoleCatalog catalog;
  final bool loading, saving, loaded;
  final bool sessionEnded;
  final String? error;
}

class RoleCubit extends Cubit<RoleState> {
  RoleCubit(this.repository) : super(const RoleState()) {
    _session = repository.sessionChanges.listen((_) {
      _epoch++;
      if (!isClosed) emit(const RoleState(sessionEnded: true));
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

  final RoleRepository repository;

  Future<void> load() async {
    if (isClosed || state.sessionEnded || state.loading || state.saving) return;
    final epoch = _epoch;
    emit(
        RoleState(catalog: state.catalog, loading: true, loaded: state.loaded));
    try {
      final catalog = await repository.load();
      if (!isClosed && epoch == _epoch) {
        emit(RoleState(catalog: catalog, loaded: true));
      }
    } catch (e) {
      if (!isClosed && epoch == _epoch) {
        emit(RoleState(
            catalog: state.catalog, loaded: false, error: roleFailure(e)));
      }
    }
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (isClosed ||
        state.sessionEnded ||
        !state.loaded ||
        state.saving ||
        state.loading) {
      return false;
    }
    final epoch = _epoch;
    emit(RoleState(catalog: state.catalog, loaded: true, saving: true));
    try {
      await operation();
    } catch (e) {
      if (!isClosed && epoch == _epoch) {
        emit(RoleState(
            catalog: repository.localCatalog,
            loaded: !(e is ApiException && (e.isUnauthorized || e.kind == ApiFailureKind.forbidden)),
            error: roleFailure(e)));
      }
      return false;
    }
    if (isClosed || epoch != _epoch) return false;
    if (repository.offline) {
      emit(RoleState(catalog: repository.localCatalog, loaded: true));
      return true;
    }
    emit(RoleState(catalog: state.catalog, loaded: true));
    await load();
    return true;
  }

  Future<bool> save(ManagedRole role) => _mutate(() async {
        await repository.save(role);
      });
  Future<bool> createCategory(String code, String title, String style) =>
      _mutate(() async {
        await repository.createCategory(code, title, style);
      });
  Future<bool> applyTemplates(List<String> codes) =>
      _mutate(() => repository.applyTemplates(codes));
  Future<bool> synchronize() => _mutate(repository.synchronize);
  Future<bool> discardDrafts() => _mutate(repository.discardDrafts);
}
