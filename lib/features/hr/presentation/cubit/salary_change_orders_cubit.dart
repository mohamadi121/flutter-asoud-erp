import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/failure_message.dart';
import '../../data/salary_change_order_repository.dart';

enum SalaryChangeOrdersStatus { initial, loading, loaded, error }

class SalaryChangeOrdersState extends Equatable {
  const SalaryChangeOrdersState({
    this.status = SalaryChangeOrdersStatus.initial,
    this.errorMessage,
    this.orders = const [],
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.applicationStatusFilter = 'all',
    this.people = const [],
    this.peopleLoading = false,
    this.peopleError,
    this.publishedTemplate,
    this.currentOrder,
    this.currentPayroll,
    this.currentPrint,
    this.isSubmitting = false,
  });

  final SalaryChangeOrdersStatus status;
  final String? errorMessage;
  final List<SalaryChangeOrderSummary> orders;
  final String searchQuery;
  final String statusFilter;
  final String applicationStatusFilter;
  final List<SalaryChangeOrderPerson> people;
  final bool peopleLoading;
  final String? peopleError;
  final Map<String, dynamic>? publishedTemplate;
  final SalaryChangeOrderDetail? currentOrder;
  final SalaryChangePayrollResult? currentPayroll;
  final SalaryChangeOrderPrint? currentPrint;
  final bool isSubmitting;

  SalaryChangeOrdersState copyWith({
    SalaryChangeOrdersStatus? status,
    String? errorMessage,
    bool clearError = false,
    List<SalaryChangeOrderSummary>? orders,
    String? searchQuery,
    String? statusFilter,
    String? applicationStatusFilter,
    List<SalaryChangeOrderPerson>? people,
    bool? peopleLoading,
    String? peopleError,
    bool clearPeopleError = false,
    Map<String, dynamic>? publishedTemplate,
    bool clearTemplate = false,
    SalaryChangeOrderDetail? currentOrder,
    bool clearCurrentOrder = false,
    SalaryChangePayrollResult? currentPayroll,
    bool clearCurrentPayroll = false,
    SalaryChangeOrderPrint? currentPrint,
    bool clearCurrentPrint = false,
    bool? isSubmitting,
  }) =>
      SalaryChangeOrdersState(
        status: status ?? this.status,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        orders: orders ?? this.orders,
        searchQuery: searchQuery ?? this.searchQuery,
        statusFilter: statusFilter ?? this.statusFilter,
        applicationStatusFilter:
            applicationStatusFilter ?? this.applicationStatusFilter,
        people: people ?? this.people,
        peopleLoading: peopleLoading ?? this.peopleLoading,
        peopleError: clearPeopleError ? null : (peopleError ?? this.peopleError),
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
        applicationStatusFilter,
        people,
        peopleLoading,
        peopleError,
        publishedTemplate,
        currentOrder,
        currentPayroll,
        currentPrint,
        isSubmitting,
      ];
}

class SalaryChangeOrdersCubit extends Cubit<SalaryChangeOrdersState> {
  SalaryChangeOrdersCubit({
    required this.repository,
    required this.company,
  }) : super(const SalaryChangeOrdersState());

  final SalaryChangeOrderRepository repository;
  final String company;
  int _payrollRequest = 0;
  int _listRequest = 0;

  Future<void> load({bool refresh = false}) async {
    if (!refresh && state.status == SalaryChangeOrdersStatus.loading) return;
    final request = ++_listRequest;
    emit(state.copyWith(
        status: SalaryChangeOrdersStatus.loading, clearError: true));
    try {
      final orders = await repository.listOrders(
        company: company,
        search: state.searchQuery,
        status: state.statusFilter == 'all' ? '' : state.statusFilter,
        applicationStatus: state.applicationStatusFilter == 'all'
            ? ''
            : state.applicationStatusFilter,
      );
      final template = await repository.getTemplate(company: company);
      if (isClosed || request != _listRequest) return;
      emit(state.copyWith(
        status: SalaryChangeOrdersStatus.loaded,
        orders: orders,
        publishedTemplate: template,
      ));
    } catch (e) {
      if (isClosed || request != _listRequest) return;
      emit(state.copyWith(
        status: SalaryChangeOrdersStatus.error,
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

  Future<void> setApplicationStatusFilter(String filter) async {
    emit(state.copyWith(applicationStatusFilter: filter));
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
      emit(state.copyWith(peopleLoading: false, peopleError: failureDetail(e)));
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

  Future<SalaryChangeOrderDetail?> saveDraft({
    required String requestId,
    int revision = 0,
    String? order,
    required String employee,
    required String effectiveDate,
    String reason = 'annual',
    String description = '',
    String? location,
    String? unit,
    String? position,
    List<Map<String, dynamic>> comparisonRows = const [],
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
        reason: reason,
        description: description,
        values: {
          if (unit != null) 'unit': unit,
          if (position != null) 'position': position,
          if (location != null) 'location': location,
        },
        comparisonRows: comparisonRows,
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

  Future<bool> approveOrder({
    required String name,
    required int revision,
    required String requestId,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final order = await repository.approveOrder(
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

  Future<bool> rejectOrder({
    required String name,
    required int revision,
    String reason = '',
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final order = await repository.rejectOrder(
        name: name,
        revision: revision,
        reason: reason,
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

  Future<bool> applyToPayroll({
    required String name,
    required String operationId,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final order = await repository.applyToPayroll(
        name: name,
        operationId: operationId,
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

  Future<bool> publishTemplate(Map<String, dynamic> template,
      {int revision = 0}) async {
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
