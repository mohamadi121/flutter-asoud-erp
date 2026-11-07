import '../../../core/utils/persian_server_values.dart';

class SetupResetBlockingRole {
  const SetupResetBlockingRole(this.user, this.label);
  final String user;
  final String label;
}

class SetupResetPreviewDetails {
  const SetupResetPreviewDetails(this.users, this.roles);

  factory SetupResetPreviewDetails.fromJson(Map<String, dynamic> json) {
    final users = json['blocking_users'];
    final roles = json['blocking_roles'];
    return SetupResetPreviewDetails(
      users is List
          ? users
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .map(_userLabel)
              .toList()
          : const [],
      roles is List
          ? roles.whereType<Map>().map((row) {
              final role = row['role'];
              final label = role is String ? persianRoleLabel(role) : '';
              return SetupResetBlockingRole(
                _userLabel(row['user']),
                _hasPersian(label) ? label : 'نقش اختصاصی',
              );
            }).toList()
          : const [],
    );
  }

  final List<String> users;
  final List<SetupResetBlockingRole> roles;
  bool get hasBlockers => users.isNotEmpty || roles.isNotEmpty;
}

bool _hasPersian(String value) => RegExp(r'[\u0600-\u06ff]').hasMatch(value);

String _userLabel(Object? value) {
  if (value is! String || value.trim().isEmpty) return 'حساب کاربری وابسته';
  final text = value.trim();
  return text.contains('@') || _hasPersian(text) ? text : 'حساب کاربری وابسته';
}
