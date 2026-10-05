/// Demo parties for the offline preview (no session): two customers and
/// two suppliers of «شرکت نمونه آسود», so the party screens can be tried
/// end to end without a server.
///
/// Served transiently (never persisted) only in preview while no party was
/// saved on the device; an authenticated session never sees these rows.
/// `PartyProfile` carries no sample flag, so every demo is marked with a
/// «نمونه نمایشی» description and a `DEMO-` id.
library;

import '../../../office_setup/data/demo/office_demo_data.dart';
import '../../domain/entities/party_profile.dart';

const _marker = 'نمونه نمایشی آفلاین؛ قابل ویرایش و حذف پس از ذخیره.';

/// Four demo parties: two customers, two suppliers.
List<PartyProfile> demoParties() => const [
      PartyProfile(
        id: 'DEMO-PARTY-CUSTOMER-1',
        company: demoCompanyName,
        kind: PartyKind.organization,
        displayName: 'فروشگاه نمونه تهران',
        roles: {PartyRole.customer},
        phone: '۰۲۱۶۶۵۵۴۴۳۳',
        province: 'تهران',
        city: 'تهران',
        address: 'تهران، بازار بزرگ، پاساژ نمونه',
        description: _marker,
        creditLimit: 200000000,
      ),
      PartyProfile(
        id: 'DEMO-PARTY-CUSTOMER-2',
        company: demoCompanyName,
        kind: PartyKind.individual,
        displayName: 'علی رضایی',
        roles: {PartyRole.customer},
        mobile: '۰۹۱۲۱۱۱۲۲۳۳',
        province: 'تهران',
        city: 'تهران',
        description: _marker,
      ),
      PartyProfile(
        id: 'DEMO-PARTY-SUPPLIER-1',
        company: demoCompanyName,
        kind: PartyKind.organization,
        displayName: 'شرکت پخش نمونه',
        roles: {PartyRole.supplier},
        phone: '۰۲۱۸۸۹۹۰۰۱۱',
        province: 'تهران',
        city: 'تهران',
        address: 'تهران، جاده مخصوص، انبار نمونه',
        description: _marker,
        creditLimit: 500000000,
      ),
      PartyProfile(
        id: 'DEMO-PARTY-SUPPLIER-2',
        company: demoCompanyName,
        kind: PartyKind.organization,
        displayName: 'تولیدی نمونه اصفهان',
        roles: {PartyRole.supplier},
        phone: '۰۳۱۳۷۷۶۶۵۵۴',
        province: 'اصفهان',
        city: 'اصفهان',
        description: _marker,
      ),
    ];
