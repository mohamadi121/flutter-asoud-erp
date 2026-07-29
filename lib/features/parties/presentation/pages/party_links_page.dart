import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';

class PartyLinksPage extends StatefulWidget {
  const PartyLinksPage(
      {required this.profile, required this.repository, super.key});
  final PartyProfile profile;
  final PartyRepository repository;
  @override
  State<PartyLinksPage> createState() => _PartyLinksPageState();
}

class _PartyLinksPageState extends State<PartyLinksPage> {
  late Future<List<FloatingDetail>> details;
  @override
  void initState() {
    super.initState();
    details = widget.repository.listDetails(search: widget.profile.displayName);
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.profile.roles.contains(PartyRole.employee);
    return Scaffold(
      appBar: AsoudHeader(
        title: employee ? 'تفصیلی‌های پرسنل' : 'تفصیلی‌های تأمین‌کننده',
        subtitle: widget.profile.displayName,
      ),
      body: SafeArea(
        child: FutureBuilder<List<FloatingDetail>>(
          future: details,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: AsoudColors.primary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14)),
                child: const Text(
                  'هر کد تفصیلی می‌تواند به حساب‌های معین مجاز متصل شود. کدها فقط در Backend تولید می‌شوند.',
                  style: TextStyle(fontSize: 9, color: AsoudColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                const _StateCard(text: 'دریافت تفصیلی‌ها از ERPNext انجام نشد.')
              else if ((snapshot.data ?? const []).isEmpty)
                const _StateCard(
                    text: 'هنوز کد تفصیلی ثبت‌شده‌ای برای این شخص وجود ندارد.')
              else
                for (final detail in snapshot.data!)
                  Card(
                    child: ListTile(
                      leading: const AsoudIconBox(
                          icon: Icons.numbers_rounded,
                          color: AsoudColors.primary),
                      title: Text(detail.title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('گروه ${detail.groupId}'),
                      trailing: Text(detail.code,
                          style: const TextStyle(
                              color: AsoudColors.primary,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
