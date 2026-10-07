import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../workflows/data/generic_request_repository.dart';
import '../../../workflows/domain/entities/request_models.dart';
import '../../../workflows/presentation/request_screen_registry.dart';
import '../../../workflows/presentation/widgets/request_list_view.dart';
import '../widgets/request_cards.dart';

/// The own-requests list of one template (CONTRACT §6.5): the shared
/// [RequestListView] limited to [templateKey], with the template's card and a
/// «+» that opens the template form.
class TemplateRequestsListPage extends StatefulWidget {
  const TemplateRequestsListPage({
    required this.company,
    required this.templateKey,
    required this.title,
    required this.searchHint,
    required this.cardBuilder,
    this.subtitle,
    this.emptyText = 'هنوز درخواستی ثبت نشده است.',
    this.repository,
    super.key,
  });

  final String company, templateKey, title, searchHint;
  final String? subtitle;
  final String emptyText;
  final Widget Function(BuildContext, RequestSummary) cardBuilder;
  final GenericRequestRepository? repository;

  @override
  State<TemplateRequestsListPage> createState() =>
      _TemplateRequestsListPageState();
}

class _TemplateRequestsListPageState extends State<TemplateRequestsListPage> {
  late final repository = widget.repository ??
      GenericRequestRepository(context.read<FrappeApiClient>(), widget.company);
  final listKey = GlobalKey<RequestListViewState>();

  @override
  void dispose() {
    if (widget.repository == null) repository.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    Map<String, dynamic>? type;
    try {
      type = (await repository.options())
          .where((row) => row['template_key'] == widget.templateKey)
          .firstOrNull;
    } catch (_) {
      type = null;
    }
    if (!mounted) return;
    if (type == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('این نوع درخواست برای شما در دسترس نیست.')));
      return;
    }
    final saved =
        await RequestScreenRegistry.openForm(context, repository, type);
    if (saved == true) await listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) => RequestListView(
        key: listKey,
        repository: repository,
        templateKey: widget.templateKey,
        title: widget.title,
        subtitle: widget.subtitle,
        searchHint: widget.searchHint,
        emptyText: widget.emptyText,
        cardBuilder: widget.cardBuilder,
        onCreate: _create,
      );
}

Widget _procurementCard(BuildContext context, RequestSummary summary) =>
    ProcurementRequestCard(summary: summary);

Widget _leaveCard(BuildContext context, RequestSummary summary) =>
    LeaveRequestCard(summary: summary);

/// «درخواست‌های خرید».
class PurchaseRequestsListPage extends StatelessWidget {
  const PurchaseRequestsListPage(
      {required this.company, this.repository, super.key});
  final String company;
  final GenericRequestRepository? repository;

  @override
  Widget build(BuildContext context) => TemplateRequestsListPage(
        company: company,
        repository: repository,
        templateKey: 'purchase',
        title: 'درخواست‌های خرید',
        searchHint: 'جستجو در درخواست‌های خرید ...',
        emptyText: 'هنوز درخواست خریدی ثبت نشده است.',
        cardBuilder: _procurementCard,
      );
}

/// «درخواست‌های تأمین کالا / خدمات».
class SupplyRequestsListPage extends StatelessWidget {
  const SupplyRequestsListPage(
      {required this.company, this.repository, super.key});
  final String company;
  final GenericRequestRepository? repository;

  @override
  Widget build(BuildContext context) => TemplateRequestsListPage(
        company: company,
        repository: repository,
        templateKey: 'supply',
        title: 'درخواست‌های تأمین کالا / خدمات',
        searchHint: 'جستجو در درخواست‌های تأمین ...',
        emptyText: 'هنوز درخواست تأمینی ثبت نشده است.',
        cardBuilder: _procurementCard,
      );
}

/// «درخواست‌های مرخصی».
class LeaveRequestsListPage extends StatelessWidget {
  const LeaveRequestsListPage(
      {required this.company, this.repository, super.key});
  final String company;
  final GenericRequestRepository? repository;

  @override
  Widget build(BuildContext context) => TemplateRequestsListPage(
        company: company,
        repository: repository,
        templateKey: 'leave',
        title: 'درخواست‌های مرخصی',
        searchHint: 'جستجو در درخواست‌های مرخصی ...',
        emptyText: 'هنوز درخواست مرخصی ثبت نشده است.',
        cardBuilder: _leaveCard,
      );
}
