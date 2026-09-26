import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_exception.dart';
import '../data/role_repository.dart';
import '../domain/role_catalog.dart';

String roleFailure(Object error) {
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
      this.error});
  final RoleCatalog catalog;
  final bool loading, saving, loaded;
  final String? error;
}

class RoleCubit extends Cubit<RoleState> {
  RoleCubit(this.repository) : super(const RoleState());
  final RoleRepository repository;

  Future<void> load() async {
    if (isClosed || state.loading || state.saving) return;
    emit(
        RoleState(catalog: state.catalog, loading: true, loaded: state.loaded));
    try {
      final catalog = await repository.load();
      if (!isClosed) emit(RoleState(catalog: catalog, loaded: true));
    } catch (e) {
      if (!isClosed) {
        emit(RoleState(
            catalog: state.catalog, loaded: false, error: roleFailure(e)));
      }
    }
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (isClosed || !state.loaded || state.saving || state.loading) {
      return false;
    }
    emit(RoleState(catalog: state.catalog, loaded: true, saving: true));
    try {
      await operation();
    } catch (e) {
      if (!isClosed) {
        emit(RoleState(
            catalog: state.catalog, loaded: true, error: roleFailure(e)));
      }
      return false;
    }
    if (isClosed) return true;
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
}
