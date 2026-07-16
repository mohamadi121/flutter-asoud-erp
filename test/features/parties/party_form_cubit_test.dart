import 'package:asoud_erp/features/parties/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/parties/domain/entities/account_detail_mapping.dart';
import 'package:asoud_erp/features/parties/domain/entities/floating_detail.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/parties_repository.dart';
import 'package:asoud_erp/features/parties/presentation/cubit/party_form_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('نام و حداقل یک نقش برای ذخیره شخص الزامی است', () async {
    final cubit = PartyFormCubit(_FakePartiesRepository());
    cubit.setName('شرکت نمونه');
    await cubit.submit();
    expect(cubit.state.status, PartyFormStatus.invalid);
  });

  test('نقش‌های چندگانه بدون حذف یکدیگر ذخیره می‌شوند', () async {
    final cubit = PartyFormCubit(_FakePartiesRepository());
    cubit.setType(PartyType.organization);
    cubit.setName('شرکت نمونه');
    cubit.toggleRole(PartyRole.customer, true);
    cubit.toggleRole(PartyRole.supplier, true);
    await cubit.submit();
    expect(cubit.state.status, PartyFormStatus.success);
    expect(cubit.state.saved?.roles, {PartyRole.customer, PartyRole.supplier});
  });
}

class _FakePartiesRepository implements PartiesRepository {
  @override
  Future<List<AccountDetailMapping>> getAccountMappings(String company) async => const [];

  @override
  Future<AccountDetailMapping> saveAccountMapping(String company, AccountDetailMapping mapping) async => mapping;

  @override
  Future<FloatingDetail> createFloatingDetail(FloatingDetail detail) async => detail;

  @override
  Future<List<DetailGroup>> getDetailGroups() async => const [];

  @override
  Future<List<FloatingDetail>> getFloatingDetails({String? search}) async => const [];

  @override
  Future<List<PartyProfile>> getParties({String? search}) async => const [];

  @override
  Future<PartyProfile> saveParty(PartyProfile party) async => party;
}
