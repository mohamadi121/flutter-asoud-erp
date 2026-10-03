import '../../workflows/domain/entities/workflow_definition.dart';

/// Editable form suggestions, not registered requests or approved transactions.
class RequestTemplate {
  const RequestTemplate(this.key, this.info, this.fields);
  final String key;
  final RequestTypeInfo info;
  final List<WorkflowFormFieldDefinition> fields;
}

const requestTemplates = [
  RequestTemplate(
      'leave',
      RequestTypeInfo(
          title: 'درخواست مرخصی',
          shortTitle: 'مرخصی',
          category: 'HR',
          iconKey: 'leave',
          colorHex: '#EF3340',
          description:
              'بررسی مرخصی توسط مسئول تعیین‌شده؛ ثبت این فرم به‌تنهایی مرخصی تأییدشده ایجاد نمی‌کند.'),
      [
        WorkflowFormFieldDefinition(
            key: 'leave_type',
            label: 'نوع مرخصی',
            type: 'Choice',
            required: true,
            options: ['استحقاقی', 'استعلاجی', 'بدون حقوق'],
            showInList: true),
        WorkflowFormFieldDefinition(
            key: 'from_date', label: 'از تاریخ', type: 'Date', required: true),
        WorkflowFormFieldDefinition(
            key: 'to_date', label: 'تا تاریخ', type: 'Date', required: true),
        WorkflowFormFieldDefinition(
            key: 'leave_reason', label: 'توضیحات مرخصی', type: 'Long Text'),
      ]),
  RequestTemplate(
      'mission',
      RequestTypeInfo(
          title: 'درخواست مأموریت',
          shortTitle: 'مأموریت',
          category: 'HR',
          iconKey: 'mission',
          colorHex: '#1769F6',
          description:
              'ثبت مقصد، بازه زمانی و هدف مأموریت برای بررسی مسئول مربوطه.'),
      [
        WorkflowFormFieldDefinition(
            key: 'destination',
            label: 'مقصد مأموریت',
            type: 'Short Text',
            required: true,
            showInList: true),
        WorkflowFormFieldDefinition(
            key: 'from_date',
            label: 'تاریخ شروع',
            type: 'Date',
            required: true),
        WorkflowFormFieldDefinition(
            key: 'to_date', label: 'تاریخ پایان', type: 'Date', required: true),
        WorkflowFormFieldDefinition(
            key: 'mission_purpose',
            label: 'هدف مأموریت',
            type: 'Long Text',
            required: true),
        WorkflowFormFieldDefinition(
            key: 'estimated_cost', label: 'هزینه برآوردی', type: 'Currency'),
      ]),
  RequestTemplate(
      'advance',
      RequestTypeInfo(
          title: 'درخواست مساعده',
          shortTitle: 'مساعده',
          category: 'Finance',
          iconKey: 'loan',
          colorHex: '#16A34A',
          description:
              'درخواست بررسی مساعده؛ ثبت فرم به معنی تأیید پرداخت یا ثبت سند مالی نیست.'),
      [
        WorkflowFormFieldDefinition(
            key: 'requested_amount',
            label: 'مبلغ درخواستی',
            type: 'Currency',
            required: true,
            showInList: true),
        WorkflowFormFieldDefinition(
            key: 'needed_date',
            label: 'تاریخ موردنیاز',
            type: 'Date',
            required: true),
        WorkflowFormFieldDefinition(
            key: 'advance_reason',
            label: 'دلیل درخواست',
            type: 'Long Text',
            required: true),
        WorkflowFormFieldDefinition(
            key: 'repayment_note',
            label: 'پیشنهاد بازپرداخت',
            type: 'Long Text'),
      ]),
  RequestTemplate(
      'purchase',
      RequestTypeInfo(
          title: 'درخواست خرید',
          shortTitle: 'خرید',
          category: 'Purchase',
          iconKey: 'purchase',
          colorHex: '#1769F6',
          description:
              'درخواست تأمین اقلام؛ سفارش خرید و پرداخت نیازمند مراحل و تأییدهای جداگانه هستند.'),
      [
        WorkflowFormFieldDefinition(
            key: 'purchase_items',
            label: 'اقلام موردنیاز',
            type: 'Item Table',
            required: true),
        WorkflowFormFieldDefinition(
            key: 'needed_date',
            label: 'تاریخ نیاز',
            type: 'Date',
            required: true),
        WorkflowFormFieldDefinition(
            key: 'priority',
            label: 'اولویت',
            type: 'Choice',
            required: true,
            options: ['عادی', 'فوری'],
            defaultValue: 'عادی',
            showInList: true),
        WorkflowFormFieldDefinition(
            key: 'purchase_reason',
            label: 'دلیل خرید',
            type: 'Long Text',
            required: true),
        WorkflowFormFieldDefinition(
            key: 'estimated_budget', label: 'بودجه برآوردی', type: 'Currency'),
      ]),
];
