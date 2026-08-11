import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/purchase_request.dart';
import '../../domain/purchase_request_repository.dart';
import 'purchase_request_page.dart';

class PurchaseRequestsPage extends StatefulWidget {
  const PurchaseRequestsPage({required this.company, super.key});
  final String company;
  @override
  State<PurchaseRequestsPage> createState() => _PurchaseRequestsPageState();
}

class _PurchaseRequestsPageState extends State<PurchaseRequestsPage> {
  late Future<List<PurchaseRequestSummary>> requests;

  @override
  void initState() {
    super.initState();
    requests = _load();
  }

  Future<List<PurchaseRequestSummary>> _load() =>
      context.read<PurchaseRequestRepository>().list(widget.company);

  void _reload() => setState(() => requests = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'درخواست‌های خرید من',
          subtitle: 'پیگیری درخواست‌های ثبت‌شده و آفلاین',
        ),
        body: FutureBuilder<List<PurchaseRequestSummary>>(
          future: requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تلاش دوباره'),
                ),
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) return const _EmptyRequests();
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (_, index) => _RequestCard(item: items[index]),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => PurchaseRequestPage(company: widget.company),
              ),
            );
            if (changed == true) _reload();
          },
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('درخواست جدید'),
        ),
      );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item});
  final PurchaseRequestSummary item;
  @override
  Widget build(BuildContext context) {
    final color = item.localOnly ? AsoudColors.warning : AsoudColors.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          AsoudIconBox(icon: Icons.shopping_cart_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                item.workflowInstance.isEmpty
                    ? item.status
                    : '${item.status} • ${item.workflowInstance}',
                style: const TextStyle(fontSize: 9, color: AsoudColors.muted),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(item.localOnly ? 'آفلاین' : 'ثبت‌شده',
                style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_cart_outlined,
              size: 54, color: AsoudColors.primary),
          SizedBox(height: 10),
          Text('هنوز درخواست خریدی ثبت نکرده‌اید.',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}
