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

  int _loadVersion = 0;

  Future<void> suggestPersonnel({PartyRole? role}) async {
    if (isClosed ||
        state.status == PartiesStatus.saving ||
        state.status == PartiesStatus.loading) {
      return;
    }
    if (company == null || company!.trim().isEmpty) {
      emit(PartiesState(
          status: PartiesStatus.failure,
          items: state.items,
          message:
              'ابتدا دفتر را انتخاب کنید تا پرسنل نمونه به همان دفتر متصل شوند.'));
      return;
    }
    ++_loadVersion;
    emit(PartiesState(status: PartiesStatus.saving, items: state.items));
    try {
      final Object suggestions = repository;
      if (suggestions is LocalPersonnelSuggestions &&
          suggestions.supportsLocalSuggestions) {
        await suggestions.suggestLocalPersonnel(company!);
        final items = await repository.list(company: company, role: role);
        if (!isClosed) {
          emit(PartiesState(
              status: PartiesStatus.offlineSaved,
              items: items,
              message:
                  'سه پرسنل نمونه روی دستگاه ذخیره شدند؛ اجرای دوباره، آن‌ها را تکرار نمی‌کند.'));
        }
        return;
      }
      final existing =
          await repository.list(company: company, role: PartyRole.employee);
      const titles = ['حسابدار', 'کارشناس منابع انسانی', 'کارشناس فروش'];
      for (var index = 0; index < titles.length; index++) {
        final marker =
            'پرسنل پیشنهادی نمونه ${index + 1}؛ اطلاعات غیرواقعی و قابل ویرایش.';
        if (existing.any((item) => item.description == marker)) continue;
        await repository.save(
            PartyProfile(
              company: company,
              kind: PartyKind.individual,
              displayName: 'پرسنل نمونه ${index + 1}',
              roles: const {PartyRole.employee},
              jobTitle: titles[index],
              description: marker,
            ),
            primaryRole: PartyRole.employee);
      }
      if (!isClosed) await load(role: role);
    } catch (_) {
      if (!isClosed) {
        emit(PartiesState(
            status: PartiesStatus.failure,
            items: state.items,
            message:
                'ایجاد پیشنهادها کامل نشد؛ موارد ذخیره‌شده حفظ شده‌اند. بازخوانی و دوباره تلاش کنید.'));
      }
    }
  }

  Future<void> load({PartyRole? role, String? search}) async {
    if (isClosed) return;
    final version = ++_loadVersion;
    emit(PartiesState(status: PartiesStatus.loading, items: state.items));
    try {
      final items =
          await repository.list(company: company, role: role, search: search);
      if (isClosed || version != _loadVersion) return;
      emit(PartiesState(
        status: items.isEmpty ? PartiesStatus.empty : PartiesStatus.success,
        items: items,
      ));
    } catch (_) {
      if (isClosed || version != _loadVersion) return;
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
