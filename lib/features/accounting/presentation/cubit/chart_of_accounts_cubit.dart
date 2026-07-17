import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/account_node.dart';

part 'chart_of_accounts_state.dart';

class ChartOfAccountsCubit extends Cubit<ChartOfAccountsState> {
  ChartOfAccountsCubit() : super(const ChartOfAccountsState());

  void load() => emit(
      const ChartOfAccountsState(status: ChartStatus.success, accounts: []));
}
