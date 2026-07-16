import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/parties_repository.dart';

enum PartyFormStatus { editing, saving, success, failure, invalid }

class PartyFormState extends Equatable {
  const PartyFormState({
    this.id = '',
    this.type = PartyType.individual,
    this.displayName = '',
    this.nationalId = '',
    this.mobile = '',
    this.email = '',
    this.roles = const {},
    this.status = PartyFormStatus.editing,
    this.saved,
    this.message,
  });

  final String id;
  final PartyType type;
  final String displayName;
  final String nationalId;
  final String mobile;
  final String email;
  final Set<PartyRole> roles;
  final PartyFormStatus status;
  final PartyProfile? saved;
  final String? message;

  PartyFormState copyWith({
    PartyType? type,
    String? displayName,
    String? nationalId,
    String? mobile,
    String? email,
    Set<PartyRole>? roles,
    PartyFormStatus? status,
    PartyProfile? saved,
    String? message,
  }) =>
      PartyFormState(
        id: id,
        type: type ?? this.type,
        displayName: displayName ?? this.displayName,
        nationalId: nationalId ?? this.nationalId,
        mobile: mobile ?? this.mobile,
        email: email ?? this.email,
        roles: roles ?? this.roles,
        status: status ?? PartyFormStatus.editing,
        saved: saved ?? this.saved,
        message: message,
      );

  @override
  List<Object?> get props => [id, type, displayName, nationalId, mobile, email, roles, status, saved, message];
}

class PartyFormCubit extends Cubit<PartyFormState> {
  PartyFormCubit(this._repository, {PartyProfile? party})
      : super(
          PartyFormState(
            id: party?.id ?? '',
            type: party?.type ?? PartyType.individual,
            displayName: party?.displayName ?? '',
            nationalId: party?.nationalId ?? '',
            mobile: party?.mobile ?? '',
            email: party?.email ?? '',
            roles: party?.roles ?? const {},
          ),
        );

  final PartiesRepository _repository;

  void setType(PartyType value) => emit(state.copyWith(type: value));
  void setName(String value) => emit(state.copyWith(displayName: value));
  void setNationalId(String value) => emit(state.copyWith(nationalId: value));
  void setMobile(String value) => emit(state.copyWith(mobile: value));
  void setEmail(String value) => emit(state.copyWith(email: value));
  void toggleRole(PartyRole role, bool selected) {
    final roles = Set<PartyRole>.from(state.roles);
    selected ? roles.add(role) : roles.remove(role);
    emit(state.copyWith(roles: roles));
  }

  Future<void> submit() async {
    if (state.displayName.trim().length < 3 || state.roles.isEmpty) {
      emit(state.copyWith(status: PartyFormStatus.invalid));
      return;
    }
    emit(state.copyWith(status: PartyFormStatus.saving));
    try {
      final saved = await _repository.saveParty(
        PartyProfile(
          id: state.id,
          type: state.type,
          displayName: state.displayName.trim(),
          nationalId: state.nationalId.trim(),
          mobile: state.mobile.trim(),
          email: state.email.trim(),
          roles: state.roles,
        ),
      );
      emit(state.copyWith(status: PartyFormStatus.success, saved: saved));
    } catch (error) {
      emit(state.copyWith(status: PartyFormStatus.failure, message: error.toString()));
    }
  }
}
