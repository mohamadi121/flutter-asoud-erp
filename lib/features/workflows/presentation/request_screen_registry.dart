import 'package:flutter/material.dart';

import '../data/generic_request_repository.dart';
import '../domain/entities/request_models.dart';
import 'pages/generic_request_page.dart';
import 'pages/request_flow_pages.dart';

/// Builds the create / edit form of a request type. [existing] is the request
/// being edited (the `get_request` map), or null for a new request.
typedef RequestFormScreenBuilder = Widget Function(
    BuildContext context,
    GenericRequestRepository repository,
    Map<String, dynamic> type,
    Map<String, dynamic>? existing);

/// Builds the detail page of request [name].
typedef RequestDetailScreenBuilder = Widget Function(
    BuildContext context, GenericRequestRepository repository, String name);

/// Builds the own-requests list of the template (e.g. «درخواست‌های مرخصی»).
typedef RequestListScreenBuilder = Widget Function(
    BuildContext context, GenericRequestRepository repository);

/// Builds the list card of a request.
typedef RequestCardWidgetBuilder = Widget Function(
    BuildContext context, RequestSummary summary);

/// The dedicated screens of one template (`template_key`). Every member is
/// optional: a missing one falls back to the generic screen.
class RequestTemplateScreens {
  const RequestTemplateScreens(
      {this.form, this.detail, this.list, this.cardBuilder});
  final RequestFormScreenBuilder? form;
  final RequestDetailScreenBuilder? detail;
  final RequestListScreenBuilder? list;
  final RequestCardWidgetBuilder? cardBuilder;
}

/// Maps a request's `template_key` to its dedicated screens. A key that is
/// not registered (custom request types) uses the generic screens.
class RequestScreenRegistry {
  RequestScreenRegistry._();

  static final Map<String, RequestTemplateScreens> _screens = {};

  static void register(String templateKey, RequestTemplateScreens screens) =>
      _screens[templateKey] = screens;

  static void unregister(String templateKey) => _screens.remove(templateKey);

  /// Removes every registration (tests).
  static void clear() => _screens.clear();

  /// The screens of [templateKey], or null.
  static RequestTemplateScreens? of(String? templateKey) =>
      templateKey == null || templateKey.isEmpty ? null : _screens[templateKey];

  static bool isRegistered(String? templateKey) => of(templateKey) != null;

  /// The registered keys.
  static Set<String> get keys => Set.unmodifiable(_screens.keys);

  /// Opens the form of [type] (the `request_options` row): the registered
  /// form of its `template_key`, else [GenericRequestPage]. Completes with
  /// true when the request was saved.
  static Future<bool?> openForm(BuildContext context,
      GenericRequestRepository repository, Map<String, dynamic> type,
      {Map<String, dynamic>? existing}) {
    final builder = of('${type['template_key'] ?? ''}')?.form;
    return Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (context) => builder != null
                ? builder(context, repository, type, existing)
                : GenericRequestPage(
                    repository: repository,
                    definition: type,
                    existing: existing)));
  }

  /// Opens the detail of request [name]: the registered page of
  /// [templateKey], else [RequestDetailPage].
  static Future<void> openDetail(
      BuildContext context, GenericRequestRepository repository, String name,
      {String? templateKey}) {
    final builder = of(templateKey)?.detail;
    return Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (context) => builder != null
                ? builder(context, repository, name)
                : RequestDetailPage(name: name, repository: repository)));
  }
}
