import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/employment_certificate_repository.dart';

class EmploymentCertificatesPage extends StatefulWidget {
  const EmploymentCertificatesPage({required this.company, super.key});
  final String company;
  @override
  State<EmploymentCertificatesPage> createState() => _EmploymentCertificatesPageState();
}

class _EmploymentCertificatesPageState extends State<EmploymentCertificatesPage> {
  late final EmploymentCertificateRepository _repository = EmploymentCertificateRepository(context.read<FrappeApiClient>());
  late Future<({List<EmploymentCertificate> items, int total})> _rows;
  String _status = '';
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => _rows = _repository.list(company: widget.company, status: _status);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AsoudHeader(title: 'گواهی‌های اشتغال به کار', subtitle: 'اسناد پرسنلی'),
    body: FutureBuilder<({List<EmploymentCertificate> items, int total})>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return ErrorState(failure: snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'دریافت گواهی‌ها انجام نشد؛ دوباره تلاش کنید.', onRetry: () => setState(_reload));
        final result = snapshot.data!;
        if (result.items.isEmpty) return const EmptyState(icon: Icons.description_outlined, title: 'گواهی‌ای ثبت نشده است', description: 'برای این دفتر هنوز گواهی اشتغال به کاری ثبت نشده است.');
        return ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<String>(value: _status, decoration: const InputDecoration(labelText: 'وضعیت'), items: const [DropdownMenuItem(value: '', child: Text('همه گواهی‌ها')), DropdownMenuItem(value: 'Draft', child: Text('پیش‌نویس')), DropdownMenuItem(value: 'Final', child: Text('نهایی'))], onChanged: (value) => setState(() { _status = value ?? ''; _reload(); })),
          const SizedBox(height: 12),
          for (final item in result.items) Card(child: ListTile(title: Text(item.employeeName), subtitle: Text('مخاطب: ${item.addresseeName.isEmpty ? 'تعیین نشده' : item.addresseeName}\nشماره: ${item.number}'), trailing: Text(item.statusLabel))),
        ]);
      },
    ),
  );
}
