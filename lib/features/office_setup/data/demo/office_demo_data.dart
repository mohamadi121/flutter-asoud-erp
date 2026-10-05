import '../../../../core/utils/jalali_date.dart';
import '../../domain/entities/office.dart';

/// The company name used by every offline-preview demo row.
const demoCompanyName = 'شرکت نمونه آسود';

/// The office selected automatically in the offline preview (no session):
/// «شرکت نمونه آسود», with the current Jalali year and the standard chart.
/// Served only in preview and never persisted; creating a real office
/// replaces it.
Office demoPreviewOffice({DateTime? now}) {
  final current = now ?? DateTime.now();
  final jalaliYear = JalaliDate.fromDateTime(current).year;
  return Office(
    name: demoCompanyName,
    type: OfficeType.legal,
    fiscalYearStart:
        parseJalaliDate('$jalaliYear/01/01') ?? DateTime(current.year, 3, 21),
    nationalId: '۱۰۱۰۳۲۴۵۶۷۸',
    economicCode: '۴۱۱۱۲۲۲۳۳۴۴۵',
    ownerFullName: 'مدیر نمونه',
    registrationNumber: '۵۵۷۷۸۸',
    activityType: 'بازرگانی و خدمات',
    companyType: 'سهامی خاص',
    phone: '۰۲۱۸۸۷۷۶۶۵۵',
    email: 'info@asoud-demo.ir',
    province: 'تهران',
    city: 'تهران',
    address: 'تهران، خیابان نمونه، پلاک ۱۲',
    postalCode: '۱۵۸۷۶۳۴۴۱۱',
    fiscalYear: 'سال مالی ${toPersianDigits(jalaliYear)}',
    chartTemplate: 'استاندارد ایران',
    description: 'داده نمایشی آفلاین؛ روی سرور ذخیره نمی‌شود.',
  );
}
