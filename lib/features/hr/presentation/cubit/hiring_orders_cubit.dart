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
    this.peopleLoading = false,
    this.peopleError,
    this.publishedTemplate,
    this.templateError,
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
  final bool peopleLoading;
  final String? peopleError;
  final Map<String, dynamic>? publishedTemplate;
  final String? templateError;
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
    bool? peopleLoading,
    String? peopleError,
    bool clearPeopleError = false,
    Map<String, dynamic>? publishedTemplate,
    bool clearTemplate = false,
    String? templateError,
    bool clearTemplateError = false,
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
        peopleLoading: peopleLoading ?? this.peopleLoading,
        peopleError: clearPeopleError ? null : (peopleError ?? this.peopleError),
        templateError: clearTemplateError ? null : (templateError ?? this.templateError),
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
        peopleLoading,
        peopleError,
        publishedTemplate,
        templateError,
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
  int _listRequest = 0;
  int _orderRequest = 0;
  int _printRequest = 0;
  int _payrollRequest = 0;

  Future<void> load({bool refresh = false}) async {
    if (!refresh && state.status == HiringOrdersStatus.loading) return;
    final request = ++_listRequest;
    emit(state.copyWith(status: HiringOrdersStatus.loading, clearError: true));
    try {
      final orders = await repository.listOrders(
        company: company,
        search: state.searchQuery,
        status: state.statusFilter == 'all' ? '' : state.statusFilter,
      );
      if (isClosed || request != _listRequest) return;
      emit(state.copyWith(status: HiringOrdersStatus.loaded, orders: orders));
      Map<String, dynamic>? template;
      String? templateError;
      try {
        template = await repository.getTemplate(company: company);
      } catch (error) {
        templateError = failureDetail(error);
      }
      if (isClosed || request != _listRequest) return;
      emit(state.copyWith(
        status: HiringOrdersStatus.loaded,
        orders: orders,
        publishedTemplate: template,
        clearTemplate: template == null,
        templateError: templateError,
        clearTemplateError: templateError == null,
      ));
    } catch (e) {
      if (isClosed || request != _listRequest) return;
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
    if (state.peopleLoading) return;
    emit(state.copyWith(peopleLoading: true, clearPeopleError: true));
    try {
      final list = await repository.people(company: company);
      if (isClosed) return;
      emit(state.copyWith(people: list, peopleLoading: false));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(peopleLoading: false, peopleError: failureMessage(e)));
    }
  }

  Future<void> loadPayroll({
    required String employee,
    required String effectiveDate,
  }) async {
    final request = ++_payrollRequest;
    emit(state.copyWith(clearCurrentPayroll: true, clearError: true));
    try {
      final payroll = await repository.payroll(
        company: company,
        employee: employee,
        effectiveDate: effectiveDate,
      );
      if (isClosed || request != _payrollRequest) return;
      emit(state.copyWith(currentPayroll: payroll));
    } catch (e) {
      if (isClosed || request != _payrollRequest) return;
      emit(state.copyWith(
        clearCurrentPayroll: true,
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
    if (state.isSubmitting) return null;
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
    if (state.isSubmitting) return false;
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
    final request = ++_orderRequest;
    emit(state.copyWith(isSubmitting: true, clearError: true, clearCurrentOrder: true));
    try {
      final order = await repository.getOrder(name: name);
      if (isClosed || request != _orderRequest) return;
      emit(state.copyWith(
        isSubmitting: false,
        currentOrder: order,
        currentPayroll: order.payrollSnapshot,
      ));
    } catch (e) {
      if (isClosed || request != _orderRequest) return;
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: failureMessage(e),
      ));
    }
  }

  Future<void> loadPrint(String name) async {
    final request = ++_printRequest;
    emit(state.copyWith(isSubmitting: true, clearError: true, clearCurrentPrint: true));
    try {
      final printDoc = await repository.printOrder(name: name);
      if (isClosed || request != _printRequest) return;
      emit(state.copyWith(
        isSubmitting: false,
        currentPrint: printDoc,
      ));
    } catch (e) {
      if (isClosed || request != _printRequest) return;
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: failureMessage(e),
      ));
    }
  }

  Future<bool> publishTemplate(Map<String, dynamic> template, {int revision = 0}) async {
    if (state.isSubmitting) return false;
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
