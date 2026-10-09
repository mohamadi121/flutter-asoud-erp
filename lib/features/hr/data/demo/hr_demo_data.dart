/// Rich, deterministic demo personnel data for the offline preview.
///
/// The preview has no server, so every personnel screen used to fall back to
/// the flat local party profile and rendered `—` / `ثبت نشده` everywhere. This
/// module builds one Iranian SME – «شرکت نمونه آسود» – with twelve seeded
/// employees in four departments and turns it into the exact payloads
/// `asoud_erp.api.v1.personnel_file` returns.
///
/// Everything is derived from an injected clock ([HrDemoData.today]) so the
/// demo never goes stale: contracts, documents, attendance and service length
/// are always relative to "today". Every seeded row carries `is_sample: true`,
/// so nothing here is ever offered for transfer to a real server; the one
/// `LOCAL-…` person is created on the phone instead.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/utils/jalali_date.dart';

const String hrDemoCompany = 'شرکت نمونه آسود';
const String hrDemoCompanyShort = 'نمونه آسود';
const String hrDemoAddress =
    'تهران، خیابان ولیعصر، بالاتر از میدان ونک، پلاک ۱۲۴۵';
const String hrDemoPhone = '۰۲۱-۸۸۹۹۷۷۰۰';

/// Seeded employee codes, in org-chart order: CEO, four managers, then staff.
const List<String> hrDemoEmployeeCodes = [
  'EMP-0001',
  'EMP-0002',
  'EMP-0003',
  'EMP-0004',
  'EMP-0005',
  'EMP-0006',
  'EMP-0007',
  'EMP-0008',
  'EMP-0009',
  'EMP-0010',
  'EMP-0011',
  'EMP-0012',
];

/// The employee the preview pretends the signed-in user is: staff, so the file
/// shows the "no salary for employees" rule.
const String hrDemoSelfEmployeeCode = 'EMP-0006';

const _admin = 'اداری و منابع انسانی';
const _sales = 'فروش';
const _finance = 'مالی';
const _it = 'فناوری اطلاعات';

/// Static facts per employee. Relative dates (joining, contracts, documents)
/// are computed from the clock, so nothing here goes stale.
const List<Map<String, Object?>> _people = [
  {
    'code': 'EMP-0001',
    'name': 'سینا فرهمند',
    'father': 'حسین',
    'gender': 'Male',
    'national': '008124573',
    'birth': '1979-04-17',
    'marital': 'Married',
    'blood': 'O+',
    'mobile': '09121100001',
    'phone': '02188997701',
    'email': 'sina.farhmand@gmail.com',
    'work_email': 'sina.farhmand@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1968743512',
    'address': 'تهران، خیابان ولیعصر، کوچه بهار، پلاک ۳۲، واحد ۵',
    'permanent': 'تهران، شهرک آکویا، خیابان شهید محلاتی، پلاک ۱۱۴',
    'emergency': {
      'name': 'مهسا فرهمند',
      'phone': '09121100011',
      'relation': 'همسر'
    },
    'department': _admin,
    'designation': 'مدیرعامل',
    'manager': '',
    'employment': 'Full-time',
    'branch': 'دفتر مرکزی',
    'joined': '2017-08-08',
    'base': 95000000,
    'education': [
      {
        'q': 'کارشناسی ارشد مهندسی صنایع',
        'school': 'دانشگاه تهران',
        'level': 'Post Graduate',
        'major': 'مهندسی صنایع',
        'year': 2004
      },
      {
        'q': 'کارشناسی مهندسی صنایع',
        'school': 'دانشگاه آزاد تهران',
        'level': 'Graduate',
        'major': 'مهندسی صنایع',
        'year': 2001
      },
      {
        'q': 'دوره مدیریت اجرایی',
        'school': 'دانشگاه تهران',
        'level': 'Post Graduate',
        'major': 'مدیریت اجرایی',
        'year': 2013
      },
    ],
    'previous': [
      {
        'company': 'شرکت پترو صنعت پارس',
        'designation': 'مدیر برنامه‌ریزی تولید',
        'experience': '۳ سال و ۴ ماه'
      }
    ],
    'service': 'نیروی زمینی ارتش جمهوری اسلامی ایران'
  },
  {
    'code': 'EMP-0002',
    'name': 'مریم کاظمی',
    'father': 'محمد',
    'gender': 'Female',
    'national': '007735619',
    'birth': '1984-11-02',
    'marital': 'Married',
    'blood': 'A+',
    'mobile': '09121100002',
    'phone': '02188997702',
    'email': 'maryam.kazemi@gmail.com',
    'work_email': 'm.kazemi@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1458963241',
    'address': 'تهران، خیابان شریعتی، کوچه پاکدست، پلاک ۱۸، واحد ۲',
    'permanent': 'تهران، سعادت‌آباد، بلوار دریا، کوچه مطهری، پلاک ۴۷',
    'emergency': {
      'name': 'سیدرضا کاظمی',
      'phone': '09121100012',
      'relation': 'همسر'
    },
    'department': _sales,
    'designation': 'مدیر فروش',
    'manager': 'EMP-0001',
    'employment': 'Full-time',
    'branch': 'دفتر مرکزی',
    'joined': '2018-10-07',
    'base': 62000000,
    'education': [
      {
        'q': 'کارشناسی ارشد مدیریت بازرگانی',
        'school': 'دانشگاه تهران',
        'level': 'Post Graduate',
        'major': 'مدیریت بازرگانی',
        'year': 2009
      },
      {
        'q': 'کارشناسی مدیریت',
        'school': 'دانشگاه علامه طباطبایی',
        'level': 'Graduate',
        'major': 'مدیریت',
        'year': 2006
      },
    ],
    'previous': [
      {
        'company': 'شرکت بازرگانی پارس‌پرداز',
        'designation': 'سرپرست فروش',
        'experience': '۲ سال و ۷ ماه'
      }
    ],
    'service': ''
  },
  {
    'code': 'EMP-0003',
    'name': 'امیرحسین رستمی',
    'father': 'جعفر',
    'gender': 'Male',
    'national': '001245786',
    'birth': '1981-07-25',
    'marital': 'Married',
    'blood': 'B+',
    'mobile': '09121100003',
    'phone': '02188997703',
    'email': 'amirhossein.rostami@gmail.com',
    'work_email': 'a.rostami@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1584743319',
    'address': 'تهران، خیابان آزادی، کوچه دانشگاه صنعتی، پلاک ۵۶',
    'permanent': 'تهران، جنت‌آباد شمالی، کوچه یاور، پلاک ۲۲',
    'emergency': {
      'name': 'الهام رستمی',
      'phone': '09121100013',
      'relation': 'همسر'
    },
    'department': _finance,
    'designation': 'مدیر مالی',
    'manager': 'EMP-0001',
    'employment': 'Full-time',
    'branch': 'دفتر مرکزی',
    'joined': '2019-07-09',
    'base': 58000000,
    'education': [
      {
        'q': 'کارشناسی ارشد حسابداری',
        'school': 'دانشگاه امیرکبیر',
        'level': 'Post Graduate',
        'major': 'حسابداری',
        'year': 2006
      },
      {
        'q': 'کارشناسی حسابداری',
        'school': 'دانشگاه تهران',
        'level': 'Graduate',
        'major': 'حسابداری',
        'year': 2003
      },
    ],
    'previous': [
      {
        'company': 'سازمان حسابرسی یزدان',
        'designation': 'حسابرس ارشد',
        'experience': '۴ سال و ۱ ماه'
      }
    ],
    'service': 'معافیت پزشکی'
  },
  {
    'code': 'EMP-0004',
    'name': 'نگار شریفی',
    'father': 'عباس',
    'gender': 'Female',
    'national': '006318745',
    'birth': '1986-02-09',
    'marital': 'Married',
    'blood': 'O-',
    'mobile': '09121100004',
    'phone': '02188997704',
    'email': 'negar.sharifi@gmail.com',
    'work_email': 'n.sharifi@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1658754123',
    'address': 'تهران، خیابان مطهری، کوچه دانش، پلاک ۹، واحد ۴',
    'permanent': 'تهران، نارمک، پاسداران، پلاک ۲۸۷',
    'emergency': {
      'name': 'پیمان شریفی',
      'phone': '09121100014',
      'relation': 'همسر'
    },
    'department': _it,
    'designation': 'مدیر فناوری اطلاعات',
    'manager': 'EMP-0001',
    'employment': 'Full-time',
    'branch': 'دفتر مرکزی',
    'joined': '2020-04-09',
    'base': 60000000,
    'education': [
      {
        'q': 'کارشناسی ارشد مهندسی کامپیوتر',
        'school': 'دانشگاه شریف',
        'level': 'Post Graduate',
        'major': 'مهندسی کامپیوتر',
        'year': 2011
      },
      {
        'q': 'کارشناسی مهندسی کامپیوتر',
        'school': 'دانشگاه تهران',
        'level': 'Graduate',
        'major': 'مهندسی کامپیوتر',
        'year': 2008
      },
    ],
    'previous': [
      {
        'company': 'شرکت داده‌پردازی نوین',
        'designation': 'مدیر پروژه نرم‌افزار',
        'experience': '۳ سال و ۲ ماه'
      }
    ],
    'service': ''
  },
  {
    'code': 'EMP-0005',
    'name': 'حسین عباسمحمدی',
    'father': 'نورالدین',
    'gender': 'Male',
    'national': '004185963',
    'birth': '1983-09-13',
    'marital': 'Married',
    'blood': 'AB+',
    'mobile': '09121100005',
    'phone': '02188997705',
    'email': 'hossein.ebrahimi@gmail.com',
    'work_email': 'h.ebrahimi@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1745632189',
    'address': 'تهران، میرداماد، کوچه استاد معین، پلاک ۱۴، واحد ۷',
    'permanent': 'تهران، گیشا، خیابان کوهک، پلاک ۶۶',
    'emergency': {
      'name': 'زهرا عباسمحمدی',
      'phone': '09121100015',
      'relation': 'خواهر'
    },
    'department': _admin,
    'designation': 'مدیر اداری و منابع انسانی',
    'manager': 'EMP-0001',
    'employment': 'Full-time',
    'branch': 'دفتر مرکزی',
    'joined': '2019-01-10',
    'base': 48000000,
    'education': [
      {
        'q': 'کارشناسی ارشد مدیریت منابع انسانی',
        'school': 'دانشگاه تهران',
        'level': 'Post Graduate',
        'major': 'منابع انسانی',
        'year': 2008
      },
      {
        'q': 'کارشناسی روان‌شناسی صنعتی',
        'school': 'دانشگاه تبریز',
        'level': 'Graduate',
        'major': 'روان‌شناسی',
        'year': 2005
      },
    ],
    'previous': [
      {
        'company': 'گروه صنعتی مهر تابان',
        'designation': 'کارشناس منابع انسانی',
        'experience': '۵ سال و ۶ ماه'
      }
    ],
    'service': 'سپاه پاسداران'
  },
  {
    'code': 'EMP-0006',
    'name': 'زهرا احمدی',
    'father': 'محمود',
    'gender': 'Female',
    'national': '008852137',
    'birth': '1990-05-21',
    'marital': 'Married',
    'blood': 'A-',
    'mobile': '09121100006',
    'phone': '02188997706',
    'email': 'zahra.ahmadi@gmail.com',
    'work_email': 'z.ahmadi@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1588963452',
    'address': 'تهران، خیابان کریم‌خان، کوچه نگین، پلاک ۷۸، واحد ۱۲',
    'permanent': 'تهران، شهرک غرب، کوچه ایران‌زمین، پلاک ۳۵',
    'emergency': {
      'name': 'سعید احمدی',
      'phone': '09121100016',
      'relation': 'همسر'
    },
    'department': _sales,
    'designation': 'کارشناس ارشد فروش',
    'manager': 'EMP-0002',
    'employment': 'Contract',
    'branch': 'دفتر مرکزی',
    'joined': '2021-09-06',
    'education': [
      {
        'q': 'کارشناسی ارشد مدیریت بازرگانی',
        'school': 'دانشگاه شهید بهشتی',
        'level': 'Post Graduate',
        'major': 'مدیریت بازرگانی',
        'year': 2014
      },
      {
        'q': 'کارشناسی مدیریت',
        'school': 'دانشگاه زنجان',
        'level': 'Graduate',
        'major': 'مدیریت',
        'year': 2011
      },
    ],
    'previous': [
      {
        'company': 'شرکت تجارت الکترونیک پایا',
        'designation': 'کارشناس فروش سازمانی',
        'experience': '۲ سال و ۸ ماه'
      },
      {
        'company': 'پتروشیمی اروند',
        'designation': 'کارشناس بازرگانی',
        'experience': '۱ سال و ۲ ماه'
      }
    ],
    'service': ''
  },
  {
    'code': 'EMP-0007',
    'name': 'محمد صادقی',
    'father': 'حسن',
    'gender': 'Male',
    'national': '002319645',
    'birth': '1994-01-30',
    'marital': 'Single',
    'blood': 'O+',
    'mobile': '09121100007',
    'phone': '02188997707',
    'email': 'mohammad.sadeghi@gmail.com',
    'work_email': 'm.sadeghi@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1897456321',
    'address': 'تهران، خیابان رسالت، کوچه شهید نوری، پلاک ۲۱',
    'permanent': 'تهران، رسالت، ساختمان نگین، واحد ۸',
    'emergency': {
      'name': 'زینب صادقی',
      'phone': '09121100017',
      'relation': 'خواهر'
    },
    'department': _sales,
    'designation': 'کارشناس فروش',
    'manager': 'EMP-0002',
    'employment': 'Part-time',
    'branch': 'شعبه اصفهان',
    'joined': '2023-06-08',
    'education': [
      {
        'q': 'کارشناسی مدیریت بازرگانی',
        'school': 'دانشگاه اصفهان',
        'level': 'Graduate',
        'major': 'مدیریت بازرگانی',
        'year': 2016
      }
    ],
    'previous': [
      {
        'company': 'فروشگاه زنجیره‌ای مهر',
        'designation': 'فروشنده',
        'experience': '۱ سال و ۸ ماه'
      }
    ],
    'service': 'شهرداری منطقه ۳ تهران'
  },
  {
    'code': 'EMP-0008',
    'name': 'فاطمه نجفی',
    'father': 'راضی',
    'gender': 'Female',
    'national': '007741268',
    'birth': '1991-08-18',
    'marital': 'Married',
    'blood': 'B-',
    'mobile': '09121100008',
    'phone': '02188997708',
    'email': 'fatemeh.najafi@gmail.com',
    'work_email': 'f.najafi@asoud-demo.ir',
    'province': 'اصفهان',
    'city': 'اصفهان',
    'postal': '8156743921',
    'address': 'اصفهان، خیابان چهارباغ بالا، کوچه گلستان، پلاک ۴۴',
    'permanent': 'اصفهان، محله شیخ صدیق، خیابان کاوه شمالی، پلاک ۸۸',
    'emergency': {
      'name': 'محسن نجفی',
      'phone': '09121100018',
      'relation': 'همسر'
    },
    'department': _finance,
    'designation': 'کارشناس مالی',
    'manager': 'EMP-0003',
    'employment': 'Contract',
    'branch': 'شعبه اصفهان',
    'joined': '2022-03-10',
    'education': [
      {
        'q': 'کارشناسی حسابداری',
        'school': 'دانشگاه اصفهان',
        'level': 'Graduate',
        'major': 'حسابداری',
        'year': 2013
      },
      {
        'q': 'کاردانی حسابداری',
        'school': 'دانشگاه آزاد اصفهان',
        'level': 'Graduate',
        'major': 'حسابداری صنعتی',
        'year': 2011
      },
    ],
    'previous': [
      {
        'company': 'هلدینگ نگین اصفهان',
        'designation': 'کارشناس خزانه‌داری',
        'experience': '۳ سال و ۳ ماه'
      }
    ],
    'service': ''
  },
  {
    'code': 'EMP-0009',
    'name': 'رضا مرادی',
    'father': 'قاسم',
    'gender': 'Male',
    'national': '001927384',
    'birth': '1996-03-07',
    'marital': 'Single',
    'blood': 'A+',
    'mobile': '09121100009',
    'phone': '02188997709',
    'email': 'reza.moradi@gmail.com',
    'work_email': 'r.moradi@asoud-demo.ir',
    'province': 'اصفهان',
    'city': 'اصفهان',
    'postal': '8157441296',
    'address': 'اصفهان، خیابان کاوه، کوچه بهار، پلاک ۱۷، واحد ۶',
    'permanent': 'اصفهان، خیابان کاوه، پلاک ۱۷',
    'emergency': {
      'name': 'سمیرا مرادی',
      'phone': '09121100019',
      'relation': 'خواهر'
    },
    'department': _finance,
    'designation': 'حسابدار',
    'manager': 'EMP-0003',
    'employment': 'Part-time',
    'branch': 'شعبه اصفهان',
    'joined': '2024-08-06',
    'education': [
      {
        'q': 'کارشناسی حسابداری',
        'school': 'دانشگاه آزاد اصفهان',
        'level': 'Graduate',
        'major': 'حسابداری',
        'year': 2018
      }
    ],
    'previous': [
      {
        'company': 'فروشگاه بازاریابی کوثر',
        'designation': 'انباردار',
        'experience': '۱ سال و ۴ ماه'
      }
    ],
    'service': 'نیروی هوایی ارتش'
  },
  {
    'code': 'EMP-0010',
    'name': 'بهروز نیک‌پی',
    'father': 'محمود',
    'gender': 'Male',
    'national': '005583196',
    'birth': '1988-12-14',
    'marital': 'Married',
    'blood': 'O+',
    'mobile': '09121100010',
    'phone': '02188997710',
    'email': 'bahroz.nikpai@gmail.com',
    'work_email': 'b.nikpai@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1456982374',
    'address': 'تهران، خیابان امیرکبیر، کوچه شهید نیک‌نام، پلاک ۲۹',
    'permanent': 'تهران، هفت‌حوض، کوچه گلستان، پلاک ۱۱',
    'emergency': {
      'name': 'مریم نیک‌پی',
      'phone': '09121100020',
      'relation': 'همسر'
    },
    'department': _it,
    'designation': 'برنامه‌نویس ارشد',
    'manager': 'EMP-0004',
    'employment': 'Full-time',
    'branch': 'دفتر مرکزی',
    'joined': '2022-07-08',
    'education': [
      {
        'q': 'کارشناسی ارشد مهندسی نرم‌افزار',
        'school': 'دانشگاه آزاد',
        'level': 'Post Graduate',
        'major': 'مهندسی نرم‌افزار',
        'year': 2014
      },
      {
        'q': 'کارشناسی مهندسی کامپیوتر',
        'school': 'دانشگاه گیلان',
        'level': 'Graduate',
        'major': 'مهندسی کامپیوتر',
        'year': 2010
      },
    ],
    'previous': [
      {
        'company': 'شرکت نرم‌افزار پویا',
        'designation': 'برنامه‌نویس',
        'experience': '۳ سال و ۹ ماه'
      }
    ],
    'service': 'سپاه پاسداران'
  },
  {
    'code': 'EMP-0011',
    'name': 'شیما اسدی',
    'father': 'یوسف',
    'gender': 'Female',
    'national': '009183745',
    'birth': '1995-06-02',
    'marital': 'Married',
    'blood': 'A-',
    'mobile': '09121100011',
    'phone': '02188997711',
    'email': 'shima.asadi@gmail.com',
    'work_email': 's.asadi@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1658743219',
    'address': 'تهران، خیابان دانشگاه، کوچه الوند، پلاک ۵، واحد ۳',
    'permanent': 'تهران، دانشگاه، ساختمان دانش، واحد ۹',
    'emergency': {
      'name': 'حامد اسدی',
      'phone': '09121100021',
      'relation': 'همسر'
    },
    'department': _admin,
    'designation': 'کارشناس منابع انسانی',
    'manager': 'EMP-0005',
    'employment': 'Contract',
    'branch': 'دفتر مرکزی',
    'joined': '2025-04-08',
    'education': [
      {
        'q': 'کارشناسی مدیریت منابع انسانی',
        'school': 'دانشگاه الزهرا',
        'level': 'Graduate',
        'major': 'منابع انسانی',
        'year': 2017
      }
    ],
    'previous': [
      {
        'company': 'مؤسسه آموزشی پویا',
        'designation': 'کارشناس اداری',
        'experience': '۱ سال و ۲ ماه'
      }
    ],
    'service': ''
  },
  {
    'code': 'EMP-0012',
    'name': 'مهدی کیانی',
    'father': 'صادق',
    'gender': 'Male',
    'national': '003296581',
    'birth': '2001-10-11',
    'marital': 'Single',
    'blood': 'AB-',
    'mobile': '09121100012',
    'phone': '02188997712',
    'email': 'mehdi.kiani@gmail.com',
    'work_email': 'm.kiani@asoud-demo.ir',
    'province': 'تهران',
    'city': 'تهران',
    'postal': '1658796321',
    'address': 'تهران، خیابان شهید کجایی، کوچه شهود، پلاک ۶',
    'permanent': 'تهران، شهرک آزادی، کوچه سرو، پلاک ۱۸',
    'emergency': {
      'name': 'صدیقه کیانی',
      'phone': '09121100022',
      'relation': 'مادر'
    },
    'department': _it,
    'designation': 'کارآموز فناوری اطلاعات',
    'manager': 'EMP-0004',
    'employment': 'Intern',
    'branch': 'دفتر مرکزی',
    'joined': '2025-08-06',
    'education': [
      {
        'q': 'کارشناسی مهندسی کامپیوتر',
        'school': 'دانشگاه علم و صنعت ایران',
        'level': 'Graduate',
        'major': 'مهندسی کامپیوتر',
        'year': 2023
      }
    ],
    'previous': [
      {
        'company': 'دوره کارآموزی دانشگاه علم و صنعت ایران',
        'designation': 'کارآموز توسعه وب',
        'experience': '۶ ماه'
      }
    ],
    'service': ''
  },
];

/// Current contract of each employee: `[startedDaysAgo, endsInDays]` relative
/// to [HrDemoData.today]. Several contracts therefore end within 30 days, so
/// the «رو به انقضا» state is always visible somewhere in the demo.
const _contractPlans = <List<int>>[
  [365, 18], // EMP-0001 مدیرعامل
  [300, 25], // EMP-0002 مدیر فروش
  [420, 95], // EMP-0003 مدیر مالی
  [540, 400], // EMP-0004 مدیر فناوری اطلاعات
  [380, 12], // EMP-0005 مدیر اداری و منابع انسانی
  [330, 14], // EMP-0006 کارشناس ارشد فروش
  [210, 45], // EMP-0007 کارشناس فروش
  [300, 210], // EMP-0008 کارشناس مالی
  [250, 150], // EMP-0009 حسابدار
  [600, 500], // EMP-0010 برنامه‌نویس ارشد
  [180, 60], // EMP-0011 کارشناس منابع انسانی
  [200, 25], // EMP-0012 کارآموز
];

/// Employees whose first fixed-term contract ended and who were hired again.
/// Their file therefore carries a «پایان همکاری» (relieving) event between
/// two expired contracts, exactly like a real HRMS employee.
const _relievingGapDays = <String, int>{
  'EMP-0007': 400,
  'EMP-0009': 380,
  'EMP-0011': 360,
};

/// Employees whose next contract has already been drafted but not started.
const _renewalAfterDays = <String, int>{
  'EMP-0011': 30,
  'EMP-0012': 20,
};

/// Contracts drafted for renewal but still waiting for a signature.
const _unsignedAfterDays = <String, int>{
  'EMP-0006': 15,
  'EMP-0010': 25,
};

const _historyTitles = {
  'joining': 'استخدام',
  'internal': 'سابقه سازمانی',
  'promotion': 'ارتقا یا تغییر سمت',
  'transfer': 'انتقال',
  'contract': 'قرارداد',
  'salary': 'تعیین حقوق',
  'relieving': 'پایان همکاری',
};

const _employmentLabels = {
  'Full-time': 'تمام وقت',
  'Part-time': 'پاره وقت',
  'Contract': 'قراردادی',
  'Intern': 'کارآموز',
};

const _avatarPalette = [
  [0x2E, 0x6F, 0xA3],
  [0x3F, 0x7D, 0x58],
  [0x8A, 0x5A, 0x2B],
  [0x6A, 0x4C, 0x93],
  [0xA3, 0x4A, 0x4A],
  [0x2A, 0x6F, 0x6F],
];

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _iso(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _stamp(DateTime value, int hour, int minute) =>
    '${_iso(value)} ${hour.toString().padLeft(2, '0')}:'
    '${minute.toString().padLeft(2, '0')}:00';

DateTime _shift(DateTime from, int days) =>
    DateTime(from.year, from.month, from.day + days);

/// Iranian national id: ten digits whose last digit is the mod-11 check digit
/// of the first nine.
String _nationalId(String nine) {
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += int.parse(nine[i]) * (10 - i);
  }
  final check = sum % 11;
  return '$nine${check == 10 ? 0 : check}';
}

/// `۱٬۲۵۰٬۰۰۰` style amount for Persian history and activity text.
String _amount(num value) =>
    toPersianDigits(value.round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},'));

/// Fridays are the weekend in Iran, so they never count as a workday.
bool _isFriday(DateTime value) => value.weekday == DateTime.friday;

int _workdays(DateTime from, DateTime to) {
  var count = 0;
  for (var day = from; !day.isAfter(to); day = _shift(day, 1)) {
    if (!_isFriday(day)) count++;
  }
  return count;
}

DateTime _lastWorkday(DateTime value) =>
    _isFriday(value) ? _shift(value, -1) : value;

class HrDemoData {
  HrDemoData({DateTime? today}) : today = _dateOnly(today ?? DateTime.now());

  /// Fixed-clock constructor, so tests can assert contract and document
  /// windows without depending on the day the suite runs.
  HrDemoData.at(DateTime today) : today = _dateOnly(today);

  final DateTime today;

  List<String> get codes => hrDemoEmployeeCodes;

  /// Only `EMP-…` profiles are seeded demo data; `LOCAL-…` people are created
  /// on the phone and must never be replaced by demo rows.
  bool isSeeded(String profileId) => hrDemoEmployeeCodes.contains(profileId);

  bool isDemoRecord(String recordId) => recordId.startsWith('DEMO-');

  String photoRecordId(String profileId) => 'DEMO-PHOTO-$profileId';

  Map<String, dynamic>? row(String profileId) {
    final index = hrDemoEmployeeCodes.indexOf(profileId);
    if (index < 0) return null;
    final person = _people[index];
    return {
      'id': person['code'],
      'company': hrDemoCompany,
      'disabled': false,
      'is_sample': true,
      'is_user_created': false,
      'photo_record': photoRecordId(profileId),
      'display_name': person['name'],
      'employee_code': person['code'],
      'national_id': _nationalId('${person['national']}'),
      'birth_date': person['birth'],
      'employee_gender': person['gender'],
      'father_name': person['father'],
      'mobile': person['mobile'],
      'phone': person['phone'],
      'email': person['email'],
      'province': person['province'],
      'city': person['city'],
      'address_line': person['address'],
      'postal_code': person['postal'],
      'date_of_joining': _iso(_joined(person)),
      'job_title': person['designation'],
      'department': person['department'],
      'employment_type': person['employment'],
      'status': 'Active',
      // The server exposes the direct manager as the HRMS Employee name.
      'reports_to': person['manager'],
      'manager': _managerName('${person['manager']}'),
      'direct_reports': _directReports(profileId),
    };
  }

  List<Map<String, dynamic>> rows() => [
        for (final code in hrDemoEmployeeCodes)
          if (row(code) case final row?) row,
      ];

  /// The whole `get_personnel_file` payload, exactly as the domain model and
  /// the backend expect it. [selfView] returns the file the employee sees for
  /// themselves, which never contains salary data.
  Map<String, dynamic> file(String profileId, {bool selfView = false}) {
    final index = hrDemoEmployeeCodes.indexOf(profileId);
    if (index < 0) throw ArgumentError.value(profileId, 'profileId');
    final person = _people[index];
    final code = '${person['code']}';
    final joined = _joined(person);
    final salaryVisible = !selfView && _isManager(code);
    return {
      'profile_id': code,
      'can_edit': false,
      'revision': 'demo-v1-$code',
      'is_sample': true,
      'header': {
        'name': person['name'],
        'employee_code': code,
        'designation': person['designation'],
        'department': person['department'],
        'department_name': person['department'],
        'company': hrDemoCompany,
        'status': 'Active',
        'photo_record': photoRecordId(code),
        'employment_type': person['employment'],
        'date_of_joining': _iso(joined),
        'service_length': _serviceLength(joined),
        'linked': false,
        'is_sample': true,
      },
      'personal': _personal(person, index),
      'organization': _organization(person, code),
      'employment': _employment(person, joined),
      'contracts': _contracts(code, index),
      'salary': salaryVisible ? _salary(person, index) : _hiddenSalary(),
      'documents': _documents(code, index),
      'history': _history(person, index, joined),
      'attendance': _attendance(index),
      'leave': _leave(index),
      'activity': _activity(person, index),
    };
  }

  /// Legacy `get_personnel` payload: the older personnel detail page and the
  /// records list. Sample rows never expose financial fields.
  Map<String, dynamic> detail(String profileId) {
    final profile = row(profileId);
    if (profile == null) throw ArgumentError.value(profileId, 'profileId');
    final index = indexOfCode(profileId);
    final person = _people[index];
    final personal = _personal(person, index);
    final emergency = personal['emergency']! as Map;
    final employment = _employment(person, _joined(person));
    return {
      'profile': {
        ...profile,
        for (final key in ['marital_status', 'blood_group', 'company_email'])
          key: personal[key],
        'emergency_contact_name': emergency['name'],
        'emergency_phone': emergency['phone'],
        'emergency_relation': emergency['relation'],
        'branch': person['branch'],
        // An employee without a manager has no manager field to display.
        if ('${profile['reports_to']}'.isNotEmpty)
          'reports_to': profile['reports_to'],
        for (final key in [
          'final_confirmation_date',
          'contract_end_date',
          'notice_number_of_days'
        ])
          if ('${employment[key]}'.isNotEmpty) key: employment[key],
      }..removeWhere((key, value) => key == 'reports_to' && '$value'.isEmpty),
      'can_edit': false,
      'revision': 'demo-v1-$profileId',
      'is_sample': true,
      'records': [
        ..._legacyRecords(profileId)
            .where((record) => record['kind'] != 'document'),
        for (final document in _documents(profileId, index))
          {
            'name': document['id'],
            'kind': 'document',
            'title': document['title'],
            'record_date': document['issue_date'],
            'is_sample': true,
          },
        {
          'name': photoRecordId(profileId),
          'kind': 'photo',
          'title': 'تصویر پرسنلی',
          'record_date': _iso(today),
          'is_sample': true,
        },
      ],
    };
  }

  List<Map<String, dynamic>> _legacyRecords(String code) {
    final index = hrDemoEmployeeCodes.indexOf(code);
    final joined = _joined(_people[index]);
    return [
      {
        'name': 'DEMO-REC-$code-1',
        'kind': 'evaluation',
        'title': 'ارزیابی عملکرد سالانه',
        'record_date': _iso(_shift(joined, 30)),
        'is_sample': true,
      },
      {
        'name': 'DEMO-REC-$code-2',
        'kind': 'history',
        'title': 'سابقه شغلی و تحصیلی',
        'record_date': _iso(_shift(joined, 60)),
        'is_sample': true,
      },
      {
        'name': 'DEMO-REC-$code-3',
        'kind': 'document',
        'title': 'گواهی دوره آموزشی ایمنی',
        'record_date': _iso(_shift(today, -40)),
        'is_sample': true,
      },
    ];
  }

  /// Photo, document and legacy record attachments. Returns base64 payloads in
  /// the same shape `get_record` returns on a server.
  Map<String, dynamic>? record(String recordId) {
    if (recordId.startsWith('DEMO-PHOTO-')) {
      final code = recordId.replaceFirst('DEMO-PHOTO-', '');
      if (!isSeeded(code)) return null;
      return {
        'id': recordId,
        'kind': 'photo',
        'title': 'تصویر پرسنلی',
        'date': _iso(today),
        'filename': 'photo-$code.png',
        'file': base64Encode(_avatar(indexOfCode(code))),
        'notes': 'تصویر پرسنلی ثبت‌شده در پیش‌نمایش آفلاین.',
        'is_sample': true,
      };
    }
    if (recordId.startsWith('DEMO-DOC-')) {
      final parts = recordId.split('-');
      final code = parts.sublist(2, parts.length - 1).join('-');
      final number = int.tryParse(parts.last) ?? 0;
      if (!isSeeded(code)) return null;
      final documents = _documents(code, hrDemoEmployeeCodes.indexOf(code));
      if (number < 1 || number > documents.length) return null;
      final document = documents[number - 1];
      return {
        ...document,
        'kind': 'document',
        'date': document['issue_date'],
        'file': base64Encode(_pdf(
            '${document['ascii_code']} $code $number'.replaceAll('-', ' '))),
        'notes': 'پیوست نمونه برای پیش‌نمایش آفلاین.',
      };
    }
    if (recordId.startsWith('DEMO-REC-')) {
      final parts = recordId.split('-');
      final code = parts.sublist(2, parts.length - 1).join('-');
      final number = int.tryParse(parts.last) ?? 0;
      if (!isSeeded(code)) return null;
      final records = _legacyRecords(code);
      if (number < 1 || number > records.length) return null;
      final record = records[number - 1];
      return {
        ...record,
        'date': record['record_date'],
        if (record['kind'] == 'evaluation') ...{
          'score': 85 + indexOfCode(code) % 10,
          'appraisal_cycle': 'ارزیابی سالانه',
        },
        'filename': 'record-$code-$number.pdf',
        'file': base64Encode(_pdf('RECORD $code $number')),
        'notes': 'سابقه نمونه برای پیش‌نمایش آفلاین.',
      };
    }
    return null;
  }

  Map<String, dynamic> home() {
    final code = hrDemoSelfEmployeeCode;
    final index = indexOfCode(code);
    final person = _people[index];
    return {
      'profile_id': code,
      'employee': code,
      'name': person['name'],
      'designation': person['designation'],
      'department_name': person['department'],
      'company': hrDemoCompany,
      'photo_record': photoRecordId(code),
      'date': _iso(today),
      'counts': {
        'open_requests': 2,
        'open_tasks': 3 + index % 4,
        'unread_notifications': 1 + index % 5,
        'pending_leave_applications': index % 3,
        'leave_remaining': 12 + index,
      },
      'last_checkin': {
        'time': _stamp(_lastWorkday(today), 8, 12 + index),
        'log_type': 'IN',
      },
      'announcements': announcements(),
      'is_sample': true,
    };
  }

  List<Map<String, dynamic>> announcements() => [
        {
          'name': 'NOTE-1',
          'title': 'تمدید بیمه تکمیلی پرسنل',
          'summary':
              'تمدید بیمه تکمیلی سالانه از ابتدای ماه آینده آغاز می‌شود؛ هزینه سهم کارکنان از فیش حقوقی کسر می‌شود.',
          'date': _iso(_shift(today, -3)),
          'expires_on': _iso(_shift(today, 25)),
          'is_sample': true,
        },
        {
          'name': 'NOTE-2',
          'title': 'دوره آموزشی ایمنی و آتش‌نشانی',
          'summary':
              'دوره آموزشی ایمنی با مدرک معتبر برگزار می‌شود؛ حضور همه پرسنل الزامی است و گواهی آن در پرونده ثبت خواهد شد.',
          'date': _iso(_shift(today, -6)),
          'expires_on': _iso(_shift(today, 12)),
          'is_sample': true,
        },
        {
          'name': 'NOTE-3',
          'title': 'برنامه ارزیابی عملکرد نیمه دوم سال',
          'summary':
              'فرم ارزیابی عملکرد نیمه دوم سال تا پایان هفته آینده تکمیل شود؛ نتیجه در تصمیم‌های ارتقا و افزایش حقوق لحاظ می‌شود.',
          'date': _iso(_shift(today, -9)),
          'expires_on': _iso(_shift(today, 5)),
          'is_sample': true,
        },
      ];

  /// Attachment behind «مشاهده فیل» of a contract card.
  ({String filename, String contentBase64})? contractFile(String contract) {
    if (!contract.startsWith('CT-')) return null;
    return (
      filename: 'contract-${contract.replaceFirst('CT-', '')}.pdf',
      contentBase64:
          base64Encode(_pdf('CONTRACT ${contract.replaceAll('-', ' ')}')),
    );
  }

  static int indexOfCode(String code) {
    final index = hrDemoEmployeeCodes.indexOf(code);
    if (index < 0) throw ArgumentError.value(code, 'code');
    return index;
  }

  /// Managers – and the CEO, who is also a manager – see salary data.
  bool _isManager(String code) =>
      _directReports(code) > 0 ||
      '${_people[indexOfCode(code)]['manager']}'.isEmpty;

  int _directReports(String code) =>
      _people.where((person) => '${person['manager']}' == code).length;

  String _managerName(String managerCode) => managerCode.isEmpty
      ? ''
      : '${_people[hrDemoEmployeeCodes.indexOf(managerCode)]['name']}';

  /// Joining dates are fixed history – only contracts, documents and attendance
  /// follow the clock.
  DateTime _joined(Map<String, Object?> person) =>
      DateTime.parse('${person['joined']}');

  Map<String, dynamic> _serviceLength(DateTime joined) {
    var days = today.difference(joined).inDays;
    final years = days ~/ 365;
    days -= years * 365;
    final months = days ~/ 30;
    return {
      'years': years,
      'months': months.clamp(0, 11),
      'days': (days - months * 30).clamp(0, 29),
      'is_sample': true,
    };
  }

  Map<String, dynamic> _personal(Map<String, Object?> person, int index) {
    final education =
        (person['education']! as List).cast<Map<String, Object?>>();
    final previous = (person['previous']! as List).cast<Map<String, Object?>>();
    final service = '${person['service']}';
    return {
      'national_id': _nationalId('${person['national']}'),
      'father_name': person['father'],
      'birth_date': person['birth'],
      'employee_gender': person['gender'],
      'marital_status': person['marital'],
      'blood_group': person['blood'],
      'mobile': person['mobile'],
      'phone': person['phone'],
      'email': person['email'],
      'company_email': person['work_email'],
      'address_line': person['address'],
      'province': person['province'],
      'city': person['city'],
      'postal_code': person['postal'],
      'permanent_address': person['permanent'],
      'emergency': {...person['emergency']! as Map<String, Object?>},
      'education': [
        for (final row in education)
          {
            'qualification': row['q'],
            'school': row['school'],
            'level': row['level'],
            'major': row['major'],
            'year_of_passing': row['year'],
            'is_sample': true,
          },
      ],
      'previous_work': [
        for (final row in previous)
          {
            'company': row['company'],
            'designation': row['designation'],
            'experience': row['experience'],
            'is_sample': true,
          },
        // The personnel file has no dedicated military-service field, so a
        // man's service is listed as prior experience, as in Iranian files.
        if (service.isNotEmpty)
          {
            'company': service,
            'designation': service.startsWith('معافیت')
                ? 'معافیت پزشکی از خدمت'
                : 'خدمت نظامی (سربازی)',
            'experience': service.startsWith('معافیت')
                ? 'خدمت نکرده است'
                : '${_amount(1 + index % 3)} سال و ${_amount(4 + index % 6)} ماه',
            'is_sample': true,
          },
      ],
      'is_sample': true,
    };
  }

  Map<String, dynamic> _organization(Map<String, Object?> person, String code) {
    final managerCode = '${person['manager']}';
    return {
      'company': hrDemoCompany,
      'department': person['department'],
      'department_name': person['department'],
      'department_path': [
        'ستاد مرکزی',
        '${person['department']}',
        if ('${person['branch']}' != 'دفتر مرکزی') '${person['branch']}',
      ],
      'designation': person['designation'],
      'branch': person['branch'],
      'employee_number': code,
      'direct_reports': _directReports(code),
      'reports_to': managerCode.isEmpty
          ? null
          : {
              'employee': managerCode,
              'name': _people[indexOfCode(managerCode)]['name'],
              'designation': _people[indexOfCode(managerCode)]['designation'],
              'department_name': _people[indexOfCode(managerCode)]
                  ['department'],
              'is_sample': true,
            },
      'is_sample': true,
    };
  }

  Map<String, dynamic> _employment(
      Map<String, Object?> person, DateTime joined) {
    final contracts = _contracts(
        '${person['code']}', hrDemoEmployeeCodes.indexOf('${person['code']}'));
    final current = contracts.firstWhere(
        (contract) => contract['state'] != 'expired',
        orElse: () => contracts.first);
    final confirmed = _shift(joined, 365 * 2);
    final scheduled = _shift(joined, 90);
    return {
      'employment_type': person['employment'],
      'date_of_joining': _iso(joined),
      'service_length': _serviceLength(joined),
      'status': 'Active',
      'scheduled_confirmation_date': _iso(scheduled),
      'final_confirmation_date':
          person['employment'] == 'Full-time' ? _iso(confirmed) : '',
      'contract_end_date': '${current['end_date']}',
      'notice_number_of_days': person['employment'] == 'Intern' ? 15 : 30,
      'relieving_date': '',
      'holiday_list': 'تعطیلات رسمی کشور و جمعه‌ها',
      'default_shift':
          person['branch'] == 'دفتر مرکزی' ? '۸:۰۰ تا ۱۶:۳۰' : '۹:۰۰ تا ۱۷:۰۰',
      'is_sample': true,
    };
  }

  List<Map<String, dynamic>> _contracts(String code, int index) {
    final plan = _contractPlans[index];
    final started = _shift(today, -plan[0]);
    final end = _shift(today, plan[1]);
    final gap = _relievingGapDays[code];
    final rows = <Map<String, dynamic>>[
      _contract(code, 1, started, end),
      _contract(code, 2, _shift(started, -730), _shift(started, -(gap ?? 5))),
    ];
    final renewal = _renewalAfterDays[code];
    if (renewal != null) {
      final starts = _shift(end, renewal);
      rows.add(_contract(code, 3, starts, _shift(starts, 365)));
    }
    if (_unsignedAfterDays[code] != null) {
      // A renewal the company already drafted but has not signed yet.
      final starts = _shift(end, _unsignedAfterDays[code]!);
      rows.add({
        ..._contract(code, 4, starts, _shift(starts, 365)),
        'is_signed': 0,
        'signed_on': '',
        'state': 'unsigned',
      });
    }
    rows.sort((a, b) => '${b['start_date']}'.compareTo('${a['start_date']}'));
    return rows;
  }

  Map<String, dynamic> _contract(
      String code, int number, DateTime start, DateTime end) {
    final person = _people[indexOfCode(code)];
    final expired = end.isBefore(today);
    final state = start.isAfter(today)
        ? 'upcoming'
        : expired
            ? 'expired'
            : 'active';
    return {
      'name': 'CT-$code-$number',
      'start_date': _iso(start),
      'end_date': _iso(end),
      'status': expired ? 'Closed' : 'Open',
      'is_signed': 1,
      'signed_on': _iso(_shift(start, -6)),
      'docstatus': 1,
      'state': state,
      // The server always sends days remaining, so expired contracts read as a
      // negative number rather than an empty field.
      'days_remaining': end.difference(today).inDays,
      'terms': _terms(person, state),
      'file': {
        'id': 'FILE-CT-$code-$number',
        'filename': 'contract-$code-$number.pdf',
        'is_sample': true,
      },
      'is_sample': true,
    };
  }

  String _terms(Map<String, Object?> person, String state) {
    final label = _employmentLabels['${person['employment']}'];
    final head = switch (state) {
      'upcoming' => 'قرارداد آتی $label',
      'expired' => 'قرارداد پایان‌یافته $label',
      _ => 'قرارداد جاری $label',
    };
    return '$head برای «${person['designation']}». '
        'ساعت کاری طبق برنامه شیفت واحد ${person['department']} و حقوق و مزایا بر اساس '
        'ساختار حقوقی مصوب، پرداخت ماهانه تا پایان دهمین روز ماه بعد. '
        'این قرارداد مشمول مقررات قانون کار و طرح‌های مصوب شورای کار است.';
  }

  Map<String, dynamic> _hiddenSalary() => {
        'visible': false,
        'currency': 'IRR',
        'current': null,
        'history': const <Map<String, dynamic>>[],
        'latest_slip': null,
        'legacy': null,
        'is_sample': true,
      };

  Map<String, dynamic> _salary(Map<String, Object?> person, int index) {
    final base = (person['base']! as int) ~/ 50000 * 50000;
    final structure =
        index == 0 ? 'ساختار حقوقی مدیریت' : 'ساختار حقوقی کارشناسی ارشد';
    final assignments = <Map<String, dynamic>>[
      for (final (position, daysAgo, ratio) in [
        (1, 180, 1.0),
        (2, 520, 0.85),
        (3, 900, 0.72),
      ])
        {
          'name': 'SSA-$person-${person['code']}-$position',
          'salary_structure': structure,
          'from_date': _iso(_shift(today, -daysAgo)),
          'base': (base * ratio).round(),
          'variable': (base * ratio * 0.15).round(),
          'currency': 'IRR',
          'is_sample': true,
        },
    ];
    return {
      'visible': true,
      'currency': 'IRR',
      'current': assignments.first,
      'history': assignments,
      'latest_slip': _slip('${person['code']}', base, index),
      'legacy': null,
      'is_sample': true,
    };
  }

  Map<String, dynamic> _slip(String code, int base, int index) {
    final first = DateTime(today.year, today.month - 1, 1);
    final last = DateTime(today.year, today.month, 0);
    final housing = 4000000;
    final food = 9500000;
    final phone = 800000;
    final overtime = (base * 0.06).round() + index * 120000;
    final performance = (base * 0.05).round();
    final gross = base + housing + food + phone + overtime + performance;
    final insurance = (base * 0.07).round();
    final tax = (base * 0.09).round();
    final unemployment = (base * 0.03).round();
    return {
      'name': 'SAL-SLIP-$code-${first.year}-${first.month}',
      'start_date': _iso(first),
      'end_date': _iso(last),
      'gross_pay': gross,
      'total_deduction': insurance + tax + unemployment,
      'net_pay': gross - insurance - tax - unemployment,
      'earnings': [
        for (final line in {
          'حقوق پایه': base,
          'حق مسکن': housing,
          'خواربار و بن': food,
          'تلفن همراه': phone,
          'اضافه‌کاری': overtime,
          'پاداش عملکرد': performance,
        }.entries)
          {'component': line.key, 'amount': line.value, 'is_sample': true},
      ],
      'deductions': [
        for (final line in {
          'بیمه تأمین اجتماعی سهم کارگر': insurance,
          'مالیات بر درآمد': tax,
          'بیمه بیکاری': unemployment,
        }.entries)
          {'component': line.key, 'amount': line.value, 'is_sample': true},
      ],
      'is_sample': true,
    };
  }

  List<Map<String, dynamic>> _documents(String code, int index) {
    final person = _people[index];
    final contracts = _contracts(code, index);
    final contract = contracts.firstWhere((row) => row['state'] != 'expired',
        orElse: () => contracts.first);
    final contractExpiry =
        DateTime.parse('${contract['end_date']}').difference(today).inDays;
    // Every sample person carries the same spread: two documents that never
    // expire, one that is about to, one running contract scan, one document
    // waiting for HR verification and one that has run out.
    final plan = <Map<String, Object?>>[
      {
        'category': 'Identity',
        'title': 'کارت ملی هوشتی',
        'ascii_code': 'NATIONAL-CARD',
        'number': _nationalId('${person['national']}'),
        'issued': 3600 + index * 40,
        'expiry': 420,
      },
      {
        'category': 'Education',
        'title': 'مدرک تحصیلی',
        'ascii_code': 'DIPLOMA',
        'number': 'شماره دانشنامه ${_amount(40000 + index * 137)}',
        'issued': 5200 + index * 30,
        'expiry': null,
      },
      {
        'category': 'Employment',
        'title': 'قرارداد استخدامی',
        'ascii_code': 'CONTRACT',
        'number': '${contract['name']}',
        'issued': 200 + index * 10,
        'expiry': contractExpiry,
      },
      {
        'category': 'Medical',
        'title': 'گواهی سلامت و پزشکی',
        'ascii_code': 'MEDICAL',
        'number':
            'گو-${toPersianDigits(1400 + index % 6)}-${_amount(index + 1187)}',
        'issued': 300 + index * 20,
        'expiry': index.isEven ? 21 : 9,
      },
      {
        'category': 'Other',
        'title': 'گواهی دوره آموزشی ایمنی',
        'ascii_code': 'TRAINING',
        'number': 'دوره ایمنی ${_amount(120 + index * 7)}',
        'issued': 120 + index * 15,
        'expiry': 210,
        'pending': true,
      },
      if (index.isEven)
        {
          'category': 'Identity',
          'title': 'شناسنامه',
          'ascii_code': 'BIRTH-CERTIFICATE',
          'number': _nationalId('${person['national']}'),
          'issued': 6100 + index * 25,
          'expiry': null,
        }
      else
        {
          'category': 'Financial',
          'title': 'بیمه تکمیلی درمان',
          'ascii_code': 'INSURANCE',
          'number': 'بیمه ${_amount(77000 + index * 211)}',
          'issued': 700 + index * 13,
          'expiry': -60,
        },
    ];
    return [
      for (var i = 0; i < plan.length; i++)
        {
          'id': 'DEMO-DOC-$code-${i + 1}',
          'title': plan[i]['title'],
          'category': plan[i]['category'],
          'document_number': plan[i]['number'],
          'issue_date': _iso(_shift(today, -(plan[i]['issued']! as int))),
          'expiry_date': plan[i]['expiry'] == null
              ? ''
              : _iso(_shift(today, plan[i]['expiry']! as int)),
          'status': plan[i]['pending'] == true
              ? 'pending'
              : _documentStatus(plan[i]['expiry'] == null
                  ? null
                  : _shift(today, plan[i]['expiry']! as int)),
          'filename': '${plan[i]['ascii_code']}-$code-${i + 1}.pdf',
          'ascii_code': plan[i]['ascii_code'],
          'is_sample': true,
        },
    ];
  }

  String _documentStatus(DateTime? expiry) {
    if (expiry == null) return 'no_expiry';
    if (expiry.isBefore(today)) return 'expired';
    return expiry.difference(today).inDays <= 30 ? 'expiring' : 'valid';
  }

  List<Map<String, dynamic>> _history(
      Map<String, Object?> person, int index, DateTime joined) {
    final code = '${person['code']}';
    final events = <Map<String, dynamic>>[
      _event('joining', _iso(joined),
          '${person['designation']} · ${person['department']}'),
      _event('internal', _iso(_shift(joined, 730)),
          '${person['designation']} · ${person['department']} · ${person['branch']}'),
    ];
    if (_joined(person).difference(today).inDays < -1095) {
      events.add(_event('promotion', _iso(_shift(joined, 1095)),
          'Designation: کارشناس ← ${person['designation']}'));
    }
    if (index % 4 == 1) {
      events.add(_event('transfer', _iso(_shift(joined, 900)),
          'انتقال از شعبه شیراز به ${person['branch']}'));
    }
    for (final contract in _contracts(code, index)) {
      events.add(_event(
          'contract',
          '${contract['start_date']}',
          '${formatJalaliIso('${contract['start_date']}')} تا '
              '${contract['state'] == 'expired' ? formatJalaliIso('${contract['end_date']}') : 'نامحدود'}',
          reference: '${contract['name']}'));
    }
    if (_isManager(code)) {
      final base = (person['base']! as int) ~/ 50000 * 50000;
      for (final (daysAgo, ratio) in [(180, 1.0), (520, 0.85), (900, 0.72)]) {
        events.add(_event('salary', _iso(_shift(today, -daysAgo)),
            'Salary Structure: ساختار حقوقی · ${_amount((base * ratio).round())}',
            reference: 'SSA-$code'));
      }
    }
    if (_relievingGapDays[code] != null) {
      events.add(_event(
          'relieving',
          _iso(_shift(_joined(person), -_relievingGapDays[code]!)),
          'پایان قرارداد و تسویه حساب، سپس استخدام مجدد'));
    }
    events.sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    return events;
  }

  Map<String, dynamic> _event(String kind, String date, String details,
          {String? reference}) =>
      {
        'kind': kind,
        'title': _historyTitles[kind],
        'date': date,
        'details': details,
        if (reference != null) 'reference': reference,
        'is_sample': true,
      };

  Map<String, dynamic> _attendance(int index) {
    final first = DateTime(today.year, today.month, 1);
    final workdays = _workdays(first, today);
    final absent = workdays == 0 ? 0 : index % 3;
    final onLeave = workdays == 0 ? 0 : (index + 1) % 2;
    final halfDay = workdays == 0 || index % 4 != 1 ? 0 : 1;
    return {
      'from_date': _iso(first),
      'to_date': _iso(today),
      'present': (workdays - absent - onLeave - halfDay).clamp(0, workdays),
      'absent': absent,
      'on_leave': onLeave,
      'half_day': halfDay,
      'late_entries': workdays == 0 ? 0 : index % 5,
      'early_exits': workdays == 0 ? 0 : (index + 2) % 4,
      'last_checkin': {
        'time': _stamp(_lastWorkday(today), 8, 12 + index),
        'log_type': 'IN',
        'is_sample': true,
      },
      'is_sample': true,
    };
  }

  List<Map<String, dynamic>> _leave(int index) => [
        for (final balance in {
          'Privilege Leave': [
            26.0,
            (6 + index % 8).toDouble(),
            (index % 3).toDouble()
          ],
          'Sick Leave': [12.0, (index % 4).toDouble(), 0.0],
        }.entries)
          {
            'leave_type': balance.key,
            'total_leaves': balance.value[0],
            'leaves_taken': balance.value[1],
            'leaves_pending_approval': balance.value[2],
            'remaining_leaves':
                (balance.value[0] - balance.value[1] - balance.value[2])
                    .clamp(0.0, balance.value[0]),
            'expired_leaves': 0.0,
            'is_sample': true,
          },
      ];

  List<Map<String, dynamic>> _activity(Map<String, Object?> person, int index) {
    final hr = '${_people[indexOfCode('EMP-0005')]['name']}';
    final finance = '${_people[indexOfCode('EMP-0003')]['name']}';
    final manager = '${person['manager']}'.isEmpty
        ? hr
        : '${_people[indexOfCode('${person['manager']}')]['name']}';
    return [
      for (final (daysAgo, hour, minute, title, details, by) in [
        (
          -1,
          9,
          5 + index,
          'تأیید درخواست مرخصی',
          'مرخصی استحقاقی ${toPersianDigits(1 + index % 4)} روزه تأیید شد.',
          hr
        ),
        (
          -2,
          17,
          40,
          'ثبت اضافه‌کاری',
          '${toPersianDigits(2 + index % 7)} ساعت اضافه‌کاری در هفته گذشته ثبت شد.',
          'سامانه حضور و غیاب'
        ),
        (
          -5,
          11,
          20,
          'بارگذاری مدرک جدید',
          'گواهی دوره آموزشی ایمنی در پرونده ثبت شد.',
          '${person['name']}'
        ),
        (
          -12,
          10,
          0,
          'صدور فیش حقوقی',
          'فیش حقوقی دوره گذشته صادر و در پرونده بایگانی شد.',
          finance
        ),
        (
          -20,
          12,
          5,
          'ارزیابی عملکرد',
          'فرم ارزیابی عملکرد توسط $manager تکمیل شد.',
          manager
        ),
      ])
        {
          'date': _stamp(_shift(today, daysAgo), hour, minute),
          'title': title,
          'details': details,
          'by': by,
          'is_sample': true,
        },
    ];
  }
}

/// Real, tiny PNG bytes so the demo avatar actually decodes in `Image.memory`
/// without shipping an asset file.
Uint8List _avatar(int seed) {
  const size = 24;
  final color = _avatarPalette[seed % _avatarPalette.length];
  final rows = BytesBuilder();
  for (var y = 0; y < size; y++) {
    rows.addByte(0); // PNG filter: none
    for (var x = 0; x < size; x++) {
      final head = (x - 12).abs() * 2 + (y - 9).abs() < 12;
      final shoulders = y > 17 && (x - 12).abs() * 2 < (y - 17) * 3 + 6;
      rows
        ..addByte(head
            ? 0xF2
            : shoulders
                ? 0xE2
                : color[0])
        ..addByte(head
            ? 0xE4
            : shoulders
                ? 0xDF
                : color[1])
        ..addByte(head
            ? 0xD6
            : shoulders
                ? 0xE8
                : color[2]);
    }
  }
  return _png(size, size, rows.toBytes());
}

Uint8List _png(int width, int height, List<int> pixels) {
  final header = BytesBuilder()
    ..add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ihdr = BytesBuilder()
    ..add(_uint32(width))
    ..add(_uint32(height))
    ..add(<int>[8, 2, 0, 0, 0]); // 8-bit RGB
  header
    ..add(_pngChunk('IHDR', ihdr.toBytes()))
    ..add(_pngChunk('IDAT', _deflateStored(pixels)))
    ..add(_pngChunk('IEND', const <int>[]));
  return header.toBytes();
}

List<int> _uint32(int value) => [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

List<int> _pngChunk(String type, List<int> data) {
  final name = ascii.encode(type);
  final payload = Uint8List.fromList([...name, ...data]);
  return [
    ..._uint32(data.length),
    ...payload,
    ..._uint32(_crc32(payload)),
  ];
}

/// zlib stream with stored (uncompressed) deflate blocks.
List<int> _deflateStored(List<int> data) {
  final bytes = BytesBuilder()..add(<int>[0x78, 0x01]);
  var offset = 0;
  while (offset < data.length || offset == 0) {
    final size = (data.length - offset).clamp(0, 0xFFFF).toInt();
    final last = offset + size >= data.length ? 1 : 0;
    bytes.addByte(last);
    bytes.addByte(size & 0xFF);
    bytes.addByte((size >> 8) & 0xFF);
    bytes.addByte(size ^ 0xFF);
    bytes.addByte((size ^ 0xFF) >> 8);
    bytes.add(data.sublist(offset, offset + size));
    offset += size;
    if (last == 1) break;
  }
  var a = 1;
  var b = 0;
  for (final byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  bytes.add(_uint32(((b << 16) | a) & 0xFFFFFFFF));
  return bytes.toBytes();
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xEDB88320 : 0);
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// A real single-page PDF (ASCII text only, as demo scans have no embedded
/// Persian font), used for document, contract and legacy record attachments.
Uint8List _pdf(String line) {
  final content = 'BT /F1 13 Tf 28 150 Td (ASOUD DEMO SAMPLE) Tj ET\n'
      'BT /F1 10 Tf 28 128 Td ($line) Tj ET\n'
      '0.85 0.85 0.85 RG 28 100 m 272 100 l S\n'
      'BT /F1 9 Tf 28 80 Td (Offline preview sample - not a real document) Tj ET\n';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 180] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length ${content.length} >>\nstream\n$content endstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final startxref = buffer.length;
  buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$startxref\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}
