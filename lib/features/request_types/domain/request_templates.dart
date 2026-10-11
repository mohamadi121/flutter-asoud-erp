import '../../workflows/domain/entities/workflow_definition.dart';

/// Editable form suggestions, not registered requests or approved transactions.
/// `leave` and `purchase` are system templates of the server (`template_key`),
/// so the builder does not suggest them.
class RequestTemplate {
  const RequestTemplate(this.key, this.info, this.fields);
  final String key;
  final RequestTypeInfo info;
  final List<WorkflowFormFieldDefinition> fields;
}

const requestTemplates = [
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
          colorHex: '#0B6B3A',
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
];
