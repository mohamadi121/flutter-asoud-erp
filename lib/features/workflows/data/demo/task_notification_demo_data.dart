/// Demo cartable tasks and notifications for the offline preview (no
/// session). Dates are relative to now; every row is a local sample served
/// only in preview.
library;
import '../../domain/entities/workflow_definition.dart';
import '../../domain/entities/workflow_notification.dart';
import '../../domain/entities/workflow_task.dart';
import 'request_demo_data.dart';

/// Three open tasks for the demo user.
List<WorkflowTask> demoTasks({DateTime? now}) {
  final current = now ?? DateTime.now();
  return [
    WorkflowTask(
      id: 'WFT-DEMO-001',
      instance: 'DEMO-WFI-101',
      stage: 'DEMO-STAGE-APPROVAL',
      title: 'تأیید مرخصی سارا محمدی',
      status: 'Open',
      assignedOn: current.subtract(const Duration(days: 1, hours: 3)),
      dueOn: current.add(const Duration(days: 1)),
      localOnly: true,
    ),
    WorkflowTask(
      id: 'WFT-DEMO-002',
      instance: 'DEMO-WFI-002',
      stage: 'DEMO-STAGE-REVIEW',
      title: 'بررسی درخواست خرید لپ‌تاپ',
      status: 'Open',
      assignedOn: current.subtract(const Duration(hours: 5)),
      dueOn: current.add(const Duration(days: 2)),
      localOnly: true,
    ),
    WorkflowTask(
      id: 'WFT-DEMO-003',
      instance: 'DEMO-WFI-102',
      stage: 'DEMO-STAGE-CORRECTION',
      title: 'اصلاح تنخواه خرداد',
      status: 'Open',
      assignedOn: current.subtract(const Duration(hours: 2)),
      dueOn: current.add(const Duration(days: 3)),
      localOnly: true,
    ),
  ];
}

/// Detail behind a demo task: previous values, activities and comments.
WorkflowTaskDetail demoTaskDetail(String taskId, {DateTime? now}) {
  final current = now ?? DateTime.now();
  WorkflowTask taskFor(String id, String title, String instance) =>
      WorkflowTask(
        id: id,
        instance: instance,
        stage: 'DEMO-STAGE',
        title: title,
        status: 'Open',
        assignedOn: current.subtract(const Duration(days: 1)),
        dueOn: current.add(const Duration(days: 1)),
        localOnly: true,
      );
  switch (taskId) {
    case 'WFT-DEMO-002':
      return WorkflowTaskDetail(
        task: taskFor(taskId, 'بررسی درخواست خرید لپ‌تاپ', 'DEMO-WFI-002'),
        stageType: 'Approval',
        values: const {'confirmed': true},
        previousData: const [
          WorkflowTaskDataSection(
            title: 'اطلاعات درخواست ثبت‌شده',
            values: [
              WorkflowTaskDataValue(
                  key: 'subject',
                  label: 'عنوان درخواست',
                  value: 'خرید لپ‌تاپ برای واحد فروش'),
              WorkflowTaskDataValue(
                  key: 'amount', label: 'مبلغ برآوردی', value: 145000000),
              WorkflowTaskDataValue(
                  key: 'requester',
                  label: 'درخواست‌کننده',
                  value: 'سارا محمدی'),
            ],
          ),
        ],
        activities: [
          for (final raw in demoInstanceTimeline('DEMO-WFI-002'))
            WorkflowTaskActivity(
              actor: '${raw['actor']}',
              action: '${raw['action']}',
              comment: '${raw['comment']}',
              createdOn: DateTime.tryParse('${raw['created_on']}'),
              stageTitle: '${raw['stage_title']}',
            ),
        ],
        allowReject: true,
        allowReturn: true,
        commentRequired: true,
      );
    case 'WFT-DEMO-003':
      return WorkflowTaskDetail(
        task: taskFor(taskId, 'اصلاح تنخواه خرداد', 'DEMO-WFI-102'),
        stageType: 'User Task',
        fields: const [
          WorkflowFormFieldDefinition(
              key: 'amount',
              label: 'مبلغ تنخواه',
              type: 'Currency',
              required: true),
          WorkflowFormFieldDefinition(
              key: 'purpose', label: 'مورد مصرف', type: 'Long Text'),
          WorkflowFormFieldDefinition(
              key: 'confirmed',
              label: 'اطلاعات را تأیید می‌کنم',
              type: 'Checkbox',
              required: true),
        ],
        values: const {'amount': 50000000, 'purpose': 'هزینه‌های خرداد'},
        activities: [
          WorkflowTaskActivity(
            actor: 'احمد رضایی',
            action: 'Return',
            comment: 'مبلغ هر قلم را جدا بنویسید و دوباره ارسال کنید.',
            createdOn: current.subtract(const Duration(hours: 2)),
            stageTitle: 'بررسی مدیر',
          ),
        ],
        allowReturn: false,
      );
    default:
      return WorkflowTaskDetail(
        task: taskFor(taskId, 'تأیید مرخصی سارا محمدی', 'DEMO-WFI-101'),
        stageType: 'Approval',
        previousData: const [
          WorkflowTaskDataSection(
            title: 'اطلاعات درخواست ثبت‌شده',
            values: [
              WorkflowTaskDataValue(
                  key: 'subject',
                  label: 'عنوان درخواست',
                  value: 'مرخصی استحقاقی تابستان'),
              WorkflowTaskDataValue(key: 'days', label: 'مدت (روز)', value: 3),
              WorkflowTaskDataValue(
                  key: 'requester',
                  label: 'درخواست‌کننده',
                  value: 'سارا محمدی'),
            ],
          ),
        ],
        activities: [
          WorkflowTaskActivity(
            actor: 'سارا محمدی',
            action: 'Create',
            comment: 'درخواست مرخصی ثبت شد.',
            createdOn: current.subtract(const Duration(days: 1, hours: 3)),
            stageTitle: 'ثبت درخواست',
          ),
        ],
        allowReject: true,
        allowReturn: true,
      );
  }
}

/// Five notifications following the demo flow (all start unread; reads are
/// kept on the device, so a mixed read/unread state is one tap away).
List<WorkflowNotification> demoNotifications({DateTime? now}) {
  final current = now ?? DateTime.now();
  return [
    WorkflowNotification(
      id: 'LOCAL-NOTIFICATION-1',
      title: 'کار جدید به شما ارجاع شد',
      message: 'تأیید مرخصی سارا محمدی',
      instance: 'DEMO-WFI-101',
      createdAt: current.subtract(const Duration(hours: 2)),
      localOnly: true,
    ),
    WorkflowNotification(
      id: 'LOCAL-NOTIFICATION-2',
      title: 'درخواست برای اصلاح برگشت داده شد',
      message: 'لطفاً مبلغ تنخواه خرداد را اصلاح کنید.',
      instance: 'DEMO-WFI-102',
      createdAt: current.subtract(const Duration(days: 1)),
      localOnly: true,
    ),
    WorkflowNotification(
      id: 'LOCAL-NOTIFICATION-3',
      title: 'نظر جدید روی درخواست خرید',
      message: 'احمد رضایی: لطفاً پیش‌فاکتور را پیوست کنید.',
      instance: 'DEMO-WFI-002',
      createdAt: current.subtract(const Duration(days: 2)),
      localOnly: true,
    ),
    WorkflowNotification(
      id: 'LOCAL-NOTIFICATION-4',
      title: 'یادآوری مهلت کارتابل',
      message: '۳ کار در انتظار اقدام شماست.',
      instance: '',
      createdAt: current.subtract(const Duration(days: 3)),
      localOnly: true,
    ),
    WorkflowNotification(
      id: 'LOCAL-NOTIFICATION-5',
      title: 'تنخواه تیر تأیید شد',
      message: 'سند حسابداری تنخواه تیر صادر شد.',
      instance: 'DEMO-WFI-008',
      createdAt: current.subtract(const Duration(days: 4)),
      localOnly: true,
    ),
  ];
}
