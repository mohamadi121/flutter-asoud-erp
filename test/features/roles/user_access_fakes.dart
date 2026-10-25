import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/roles/domain/role_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const userAccessRole = ManagedRole(
    code: 'HR_MANAGER',
    title: '',
    category: 'HR',
    baseRoles: ['HR Manager']);

/// Replays the exact `asoud_erp.api.v1.user_access` / `role_management`
/// response shapes read from the backend code, never a guessed shape.
class UserAccessClient extends Fake implements FrappeApiClient {
  UserAccessClient({this.roles = const ['Administrator'], this.mode = 'ok'});
  final List<String> roles;

  /// `ok`, `network` or `forbidden`: how `directory` fails.
  final String mode;
  final List<String> calls = [];
  Map<String, dynamic>? lastApply;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
      userId: 'Administrator', fullName: 'Administrator', roles: roles);

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    calls.add(method);
    if (method == 'asoud_erp.api.v1.user_access.directory') {
      if (mode == 'network') {
        throw const ApiException(
            kind: ApiFailureKind.network, message: 'ارتباط برقرار نشد');
      }
      if (mode == 'forbidden') {
        throw const ApiException(
            kind: ApiFailureKind.forbidden, message: 'دسترسی ندارید');
      }
      return _envelope([
        {
          'name': 'hr-manager@asoud-demo.local',
          'full_name': 'کاربر نمونه',
          'first_name': 'کاربر',
          'last_name': 'نمونه',
          'mobile_no': '۰۹۱۲۰۰۰۰۰۰۰',
          'enabled': 1,
          'modified': '2026-10-09 17:18:20.825763',
        },
      ]);
    }
    if (method == 'asoud_erp.api.v1.user_access.editor') {
      return _envelope({
        'catalog': [
          {
            'module': 'حسابداری',
            'doctype': 'Journal Entry',
            'title': 'سند حسابداری',
            'actions': ['read', 'create', 'write', 'delete'],
            'advanced_actions': [
              'submit', 'cancel', 'amend', 'print', 'email', 'export',
              'report', 'share', 'import',
            ],
            'levels': {
              'simple': ['read'],
              'medium': ['read', 'create', 'write', 'delete'],
              'advanced': [
                'read', 'create', 'write', 'delete', 'submit', 'cancel',
                'amend', 'print', 'email', 'export', 'report', 'share',
                'import',
              ],
            },
          },
          {
            'module': 'مدیریت کاربران',
            'doctype': 'User',
            'title': 'کاربران',
            'actions': ['read'],
            'advanced_actions': <String>[],
            'levels': {
              'simple': ['read'],
              'medium': ['read'],
              'advanced': ['read'],
            },
          },
        ],
        'grants': {
          'Journal Entry': <String>[],
          'User': ['read'],
        },
        'advanced_grants': {
          'Journal Entry': <String>[],
          'User': <String>[],
        },
        'inherited': {
          'Journal Entry': <String>[],
          'User': ['read'],
        },
        'inherited_advanced': {
          'Journal Entry': <String>[],
          'User': <String>[],
        },
        'levels': ['simple', 'medium', 'advanced'],
        'token': 'token-1',
        'base_roles': ['HR Manager'],
      });
    }
    if (method == 'asoud_erp.api.v1.user_access.apply') {
      lastApply = Map<String, dynamic>.from(data!['payload'] as Map);
      return _envelope({'applied': true, 'affected_users': 1});
    }
    if (method == 'asoud_erp.api.v1.role_management.catalog') {
      return _envelope({
        'categories': <dynamic>[],
        'roles': [
          {
            'code': 'HR_MANAGER',
            'title': '',
            'category': 'HR',
            'parent': '',
            'description': '',
            'enabled': true,
            'profile': 'ASOUD:HR_MANAGER',
            'base_roles': ['HR Manager'],
            'assigned_users': 1,
          },
        ],
        'base_roles': <dynamic>[],
        'templates': <dynamic>[],
        'template_categories': <dynamic>[],
      });
    }
    throw StateError('Unexpected method: $method');
  }

  Map<String, dynamic> _envelope(Object? data) => {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': data,
        },
      };
}

Widget userAccessApp(Widget child) =>
    MaterialApp(theme: AsoudTheme.light, home: child);

Widget userAccessSettings(FrappeApiClient client) => MaterialApp(
      theme: AsoudTheme.light,
      home: RepositoryProvider<FrappeApiClient>.value(
        value: client,
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: SettingsDashboardContent(company: 'شرکت نمونه آسود'),
        ),
      ),
    );
