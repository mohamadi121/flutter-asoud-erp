import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/failure_message.dart';
import '../../data/hiring_order_repository.dart';

enum HiringOrdersStatus { initial, loading, loaded, error }

class HiringOrdersState extends Equatable {
  const HiringOrdersState({
    this.status = HiringOrdersStatus.initial,
    this.errorMessage,
    this.orders = const [],
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.people = const [],
    this.publishedTemplate,
    this.currentOrder,
    this.currentPayroll,
    this.currentPrint,
    this.isSubmitting = false,
  });

  final HiringOrdersStatus status;
  final String? errorMessage;
  final List<HiringOrderSummary> orders;
  final String searchQuery;
  final String statusFilter;
  final List<HiringOrderPerson> people;
  final Map<String, dynamic>? publishedTemplate;
  final HiringOrderDetail? currentOrder;
  final HiringOrderPayroll? currentPayroll;
  final HiringOrderPrint? currentPrint;
  final bool isSubmitting;

  HiringOrdersState copyWith({
    HiringOrdersStatus? status,
    String? errorMessage,
    bool clearError = false,
    List<HiringOrderSummary>? orders,
    String? searchQuery,
    String? statusFilter,
    List<HiringOrderPerson>? people,
    Map<String, dynamic>? publishedTemplate,
    bool clearTemplate = false,
    HiringOrderDetail? currentOrder,
    bool clearCurrentOrder = false,
    HiringOrderPayroll? currentPayroll,
    bool clearCurrentPayroll = false,
    HiringOrderPrint? currentPrint,
    bool clearCurrentPrint = false,
    bool? isSubmitting,
  }) =>
      HiringOrdersState(
        status: status ?? this.status,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        orders: orders ?? this.orders,
        searchQuery: searchQuery ?? this.searchQuery,
        statusFilter: statusFilter ?? this.statusFilter,
        people: people ?? this.people,
        publishedTemplate: clearTemplate
            ? null
            : (publishedTemplate ?? this.publishedTemplate),
        currentOrder: clearCurrentOrder
            ? null
            : (currentOrder ?? this.currentOrder),
        currentPayroll: clearCurrentPayroll
            ? null
            : (currentPayroll ?? this.currentPayroll),
        currentPrint: clearCurrentPrint
            ? null
            : (currentPrint ?? this.currentPrint),
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        orders,
        searchQuery,
        statusFilter,
        people,
        publishedTemplate,
        currentOrder,
        currentPayroll,
        currentPrint,
        isSubmitting,
      ];
}

class HiringOrdersCubit extends Cubit<HiringOrdersState> {
  HiringOrdersCubit({
    required this.repository,
    required this.company,
  }) : super(const HiringOrdersState());

  final HiringOrderRepository repository;
  final String company;

  Future<void> load({bool refresh = false}) async {
    if (!refresh && state.status == HiringOrdersStatus.loading) return;
    emit(state.copyWith(status: HiringOrdersStatus.loading, clearError: true));
    try {
      final orders = await repository.listOrders(
        company: company,
        search: state.searchQuery,
        status: state.statusFilter == 'all' ? '' : state.statusFilter,
      );
      final template = await repository.getTemplate(company: company);
      emit(state.copyWith(
        status: HiringOrdersStatus.loaded,
        orders: orders,
        publishedTemplate: template,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HiringOrdersStatus.error,
        errorMessage: failureMessage(e),
      ));
    }
  }

  Future<void> setSearch(String query) async {
    emit(state.copyWith(searchQuery: query));
    await load(refresh: true);
  }

  Future<void> setStatusFilter(String filter) async {
    emit(state.copyWith(statusFilter: filter));
    await load(refresh: true);
  }

  Future<void> loadPeople() async {
    try {
      final list = await repository.people(company: company);
      emit(state.copyWith(people: list));
    } catch (_) {}
  }

  Future<void> loadPayroll({
    required String employee,
    required String effectiveDate,
  }) async {
    try {
      final payroll = await repository.payroll(
        company: company,
        employee: employee,
        effectiveDate: effectiveDate,
      );
      emit(state.copyWith(currentPayroll: payroll));
    } catch (e) {
      emit(state.copyWith(
        currentPayroll: null,
        errorMessage: failureMessage(e),
      ));
    }
  }

  Future<HiringOrderDetail?> saveDraft({
    required String requestId,
    int revision = 0,
    String? order,
    required String employee,
    required String effectiveDate,
    String? location,
    String? unit,
    String? position,
    String? employment,
    String? note,
    List<Map<String, dynamic>>? payrollRows,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final saved = await repository.saveOrder(
        company: company,
        requestId: requestId,
        revision: revision,
        order: order,
        employee: employee,
        effectiveDate: effectiveDate,
        values: {
          if (unit != null) 'unit': unit,
          if (position != null) 'position': position,
          if (location != null) 'location': location,
          if (employment != null) 'employment': employment,
          if (note != null) 'note': note,
        },
        payrollRows: payrollRows,
      );
      emit(state.copyWith(
        isSubmitting: false,
        currentOrder: saved,
      ));
      await load(refresh: true);
      return saved;
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: failureMessage(e),
      ));
      return null;
    }
  }

  Future<bool> sendForReview({
    required String name,
    required int revision,
    required String requestId,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final order = await repository.sendForReview(
        name: name,
        revision: revision,
        requestId: requestId,
      );
      emit(state.copyWith(
        isSubmitting: false,
        currentOrder: order,
      ));
      await load(refresh: true);
      return true;
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: failureMessage(e),
      ));
      return false;
    }
  }

  Future<void> loadOrder(String name) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final order = await repository.getOrder(name: name);
      emit(state.copyWith(
        isSubmitting: false,
        currentOrder: order,
        currentPayroll: order.payrollSnapshot,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: failureMessage(e),
      ));
    }
  }

  Future<void> loadPrint(String name) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final printDoc = await repository.printOrder(name: name);
      emit(state.copyWith(
        isSubmitting: false,
        currentPrint: printDoc,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: failureMessage(e),
      ));
    }
  }

  Future<bool> publishTemplate(Map<String, dynamic> template, {int revision = 0}) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final saved = await repository.saveTemplate(
        company: company,
        revision: revision,
        template: template,
      );
      final pubRev = (saved['revision'] as num?)?.toInt() ?? 0;
      final published = await repository.publishTemplate(
        company: company,
        revision: pubRev,
      );
      final publishedMap = (published['template'] as Map?) != null
          ? Map<String, dynamic>.from(published['template'] as Map)
          : null;
      emit(state.copyWith(
        isSubmitting: false,
        publishedTemplate: publishedMap,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: failureMessage(e),
      ));
      return false;
    }
  }
}
