import '../workflows/data/request_demo_source.dart';
import '../workflows/presentation/request_screen_registry.dart';
import 'data/system_templates.dart';
import 'data/templates_demo_source.dart';
import 'presentation/pages/leave_form_page.dart';
import 'presentation/pages/request_detail_pages.dart';
import 'presentation/pages/request_form_pages.dart';
import 'presentation/pages/request_list_pages.dart';
import 'presentation/widgets/request_cards.dart';

export 'presentation/pages/leave_form_page.dart';
export 'presentation/pages/request_detail_pages.dart';
export 'presentation/pages/request_form_pages.dart';
export 'presentation/pages/request_list_pages.dart';

/// Registers the dedicated screens (form, detail, list, card) of the
/// `purchase`, `supply` and `leave` system templates and their preview/demo
/// source (CONTRACT §6.5, §6.6). Call it once at start-up; calling it again
/// replaces the registrations with identical ones.
void registerRequestTemplates() {
  RequestScreenRegistry.register(
    SystemTemplateKeys.purchase,
    RequestTemplateScreens(
      form: (context, repository, type, existing) => PurchaseRequestFormPage(
          repository: repository, type: type, existing: existing),
      detail: (context, repository, name) =>
          PurchaseRequestDetailPage(repository: repository, name: name),
      list: (context, repository) => PurchaseRequestsListPage(
          company: repository.company, repository: repository),
      cardBuilder: (context, summary) =>
          ProcurementRequestCard(summary: summary),
    ),
  );
  RequestScreenRegistry.register(
    SystemTemplateKeys.supply,
    RequestTemplateScreens(
      form: (context, repository, type, existing) => SupplyRequestFormPage(
          repository: repository, type: type, existing: existing),
      detail: (context, repository, name) =>
          SupplyRequestDetailPage(repository: repository, name: name),
      list: (context, repository) => SupplyRequestsListPage(
          company: repository.company, repository: repository),
      cardBuilder: (context, summary) =>
          ProcurementRequestCard(summary: summary),
    ),
  );
  RequestScreenRegistry.register(
    SystemTemplateKeys.leave,
    RequestTemplateScreens(
      form: (context, repository, type, existing) => LeaveRequestFormPage(
          repository: repository, type: type, existing: existing),
      detail: (context, repository, name) =>
          LeaveRequestDetailPage(repository: repository, name: name),
      list: (context, repository) => LeaveRequestsListPage(
          company: repository.company, repository: repository),
      cardBuilder: (context, summary) => LeaveRequestCard(summary: summary),
    ),
  );
  RequestDemoRegistry.register(_demoSource);
}

/// One instance, so registering twice stays a no-op.
final _demoSource = TemplatesDemoSource();
