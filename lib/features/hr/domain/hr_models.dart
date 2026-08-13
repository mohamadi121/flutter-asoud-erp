// ignore_for_file: sort_constructors_first

import 'package:equatable/equatable.dart';

class HrEmployee extends Equatable {
  const HrEmployee(
      {required this.id,
      required this.name,
      required this.company,
      this.department = '',
      this.designation = '',
      this.manager = '',
      this.status = 'Active',
      this.phone = '',
      this.email = ''});
  final String id,
      name,
      company,
      department,
      designation,
      manager,
      status,
      phone,
      email;
  factory HrEmployee.fromJson(Map<String, dynamic> json) => HrEmployee(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      manager: json['reports_to']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      phone: json['cell_number']?.toString() ?? '',
      email: json['personal_email']?.toString() ?? '');
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'company': company,
        'department': department,
        'designation': designation,
        'reports_to': manager,
        'status': status,
        'cell_number': phone,
        'personal_email': email
      };
  @override
  List<Object?> get props => [
        id,
        name,
        company,
        department,
        designation,
        manager,
        status,
        phone,
        email
      ];
}

class HrDashboard extends Equatable {
  const HrDashboard(
      {required this.employee,
      this.pendingTasks = 0,
      this.unreadNotifications = 0,
      this.unreadCommunications = 0,
      this.todayReportStatus});
  final HrEmployee employee;
  final int pendingTasks, unreadNotifications, unreadCommunications;
  final String? todayReportStatus;
  factory HrDashboard.fromJson(Map<String, dynamic> json) => HrDashboard(
      employee: HrEmployee.fromJson(
          Map<String, dynamic>.from(json['employee'] as Map? ?? {})),
      pendingTasks: json['pending_tasks'] as int? ?? 0,
      unreadNotifications: json['unread_notifications'] as int? ?? 0,
      unreadCommunications: json['unread_communications'] as int? ?? 0,
      todayReportStatus: (json['today_report'] as Map?)?['status']?.toString());
  @override
  List<Object?> get props => [
        employee,
        pendingTasks,
        unreadNotifications,
        unreadCommunications,
        todayReportStatus
      ];
}

class WorkActivity extends Equatable {
  const WorkActivity(
      {required this.title,
      this.description = '',
      this.durationMinutes = 0,
      this.progress = 0,
      this.output = '',
      this.blocker = ''});
  factory WorkActivity.fromJson(Map<String, dynamic> json) => WorkActivity(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      progress: json['progress'] as int? ?? 0,
      output: json['output']?.toString() ?? '',
      blocker: json['blocker']?.toString() ?? '');
  final String title, description, output, blocker;
  final int durationMinutes, progress;
  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'duration_minutes': durationMinutes,
        'progress': progress,
        'output': output,
        'blocker': blocker
      };
  @override
  List<Object?> get props =>
      [title, description, durationMinutes, progress, output, blocker];
}

class WorkReport extends Equatable {
  const WorkReport(
      {this.id = '',
      required this.date,
      this.status = 'Draft',
      this.activities = const [],
      this.totalMinutes = 0,
      this.managerComment = ''});
  final String id, status, managerComment;
  final DateTime date;
  final List<WorkActivity> activities;
  final int totalMinutes;
  factory WorkReport.fromJson(Map<String, dynamic> json) => WorkReport(
      id: json['name']?.toString() ?? '',
      date: DateTime.tryParse(json['report_date']?.toString() ?? '') ??
          DateTime.now(),
      status: json['status']?.toString() ?? 'Draft',
      activities: (json['activities'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => WorkActivity.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      totalMinutes: json['total_minutes'] as int? ?? 0,
      managerComment: json['manager_comment']?.toString() ?? '');
  Map<String, dynamic> toJson() => {
        'name': id.isEmpty ? null : id,
        'report_date': date.toIso8601String().split('T').first,
        'status': status,
        'activities': activities.map((e) => e.toJson()).toList()
      };
  @override
  List<Object?> get props =>
      [id, date, status, activities, totalMinutes, managerComment];
}

class HrCommunication extends Equatable {
  const HrCommunication(
      {this.id = '',
      required this.subject,
      this.content = '',
      this.sender = '',
      this.type = 'Internal Letter',
      this.priority = 'Medium',
      this.status = 'Draft',
      this.confidential = false,
      this.recipients = const []});
  final String id, subject, content, sender, type, priority, status;
  final bool confidential;
  final List<String> recipients;
  factory HrCommunication.fromJson(Map<String, dynamic> json) =>
      HrCommunication(
          id: json['name']?.toString() ?? '',
          subject: json['subject']?.toString() ?? '',
          content: json['content']?.toString() ?? '',
          sender: json['sender']?.toString() ?? '',
          type: json['communication_type']?.toString() ?? 'Internal Letter',
          priority: json['priority']?.toString() ?? 'Medium',
          status: json['status']?.toString() ?? 'Draft',
          confidential:
              json['confidential'] == 1 || json['confidential'] == true,
          recipients: (json['recipients'] as List? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false));
  Map<String, dynamic> toJson() => {
        'subject': subject,
        'content': content,
        'communication_type': type,
        'priority': priority,
        'confidential': confidential,
        'recipients': recipients
      };
  @override
  List<Object?> get props => [
        id,
        subject,
        content,
        sender,
        type,
        priority,
        status,
        confidential,
        recipients
      ];
}
