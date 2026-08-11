import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/offline/offline_failure.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';

enum PartiesStatus {
  initial,
  loading,
  success,
  empty,
  failure,
  saving,
  offlineSaved
}

class PartiesState extends Equatable {
  const PartiesState({
    this.status = PartiesStatus.initial,
    this.items = const [],
    this.message,
  });
  final PartiesStatus status;
  final List<PartyProfile> items;
  final String? message;
  @override
  List<Object?> get props => [status, items, message];
}

class PartiesCubit extends Cubit<PartiesState> {
  PartiesCubit(this.repository, {this.company}) : super(const PartiesState());
  final PartyRepository repository;
  final String? company;

  Future<void> load({PartyRole? role, String? search}) async {
    emit(PartiesState(status: PartiesStatus.loading, items: state.items));
    try {
      final items =
          await repository.list(company: company, role: role, search: search);
      emit(PartiesState(
        status: items.isEmpty ? PartiesStatus.empty : PartiesStatus.success,
        items: items,
      ));
    } catch (_) {
      emit(PartiesState(
        status: PartiesStatus.failure,
        items: state.items,
        message: 'دریافت اطلاعات اشخاص از ASOUD ERP انجام نشد.',
      ));
    }
  }

  Future<PartyProfile?> save(PartyProfile profile) async {
    emit(PartiesState(status: PartiesStatus.saving, items: state.items));
    try {
      final saved = await repository.save(profile);
      await load();
      return saved;
    } catch (error) {
      if (isRetryableOfflineFailure(error)) {
        final items = await repository.list(company: company);
        emit(PartiesState(
          status: PartiesStatus.offlineSaved,
          items: items,
          message: 'اطلاعات شخص روی گوشی ذخیره شد و در انتظار همگام‌سازی است.',
        ));
        return profile;
      }
      emit(PartiesState(
        status: PartiesStatus.failure,
        items: state.items,
        message: 'ذخیره اطلاعات در ASOUD ERP انجام نشد.',
      ));
      return null;
    }
  }
}
