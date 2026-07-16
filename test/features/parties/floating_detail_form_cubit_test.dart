import 'package:asoud_erp/features/parties/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/parties/domain/entities/account_detail_mapping.dart';
import 'package:asoud_erp/features/parties/domain/entities/floating_detail.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/parties_repository.dart';
import 'package:asoud_erp/features/parties/presentation/cubit/floating_detail_form_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('تفصیلی بدون گروه نامعتبر است', () async {
    final cubit = FloatingDetailFormCubit(_FakePartiesRepository());
    await cubit.initialize();
    cubit.setTitle('شرکت نمونه');
    await cubit.submit();
    expect(cubit.state.status, DetailFormStatus.invalid);
  });

  test('کد تفصیلی می‌تواند توسط Backend تولید شود', () async {
    final cubit = FloatingDetailFormCubit(_FakePartiesRepository());
    await cubit.initialize();
    cubit.setGroup('10000');
    cubit.setTitle('شرکت نمونه');
    await cubit.submit();
    expect(cubit.state.status, DetailFormStatus.success);
    expect(cubit.state.saved?.code, '10001');
  });
}

class _FakePartiesRepository implements PartiesRepository {
  @override
  Future<List<AccountDetailMapping>> getAccountMappings(String company) async => const [];

  @override
  Future<AccountDetailMapping> saveAccountMapping(String company, AccountDetailMapping mapping) async => mapping;

  @override
  Future<FloatingDetail> createFloatingDetail(FloatingDetail detail) async => FloatingDetail(
        id: '10001',
        code: '10001',
        title: detail.title,
        type: detail.type,
        groupCode: detail.groupCode,
      );

  @override
  Future<List<DetailGroup>> getDetailGroups() async => const [DetailGroup(code: '10000', title: 'مشتریان')];

  @override
  Future<List<FloatingDetail>> getFloatingDetails({String? search}) async => const [];

  @override
  Future<List<PartyProfile>> getParties({String? search}) async => const [];

  @override
  Future<PartyProfile> saveParty(PartyProfile party) async => party;
}
