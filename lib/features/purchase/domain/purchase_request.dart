import 'package:equatable/equatable.dart';

class PurchaseItemOption extends Equatable {
  const PurchaseItemOption(
      {required this.code, required this.name, required this.uom});
  final String code, name, uom;
  @override
  List<Object> get props => [code, name, uom];
}

class PurchaseRequestOptions extends Equatable {
  const PurchaseRequestOptions(
      {this.items = const [], this.warehouses = const []});
  final List<PurchaseItemOption> items;
  final List<String> warehouses;
  @override
  List<Object> get props => [items, warehouses];
}

class PurchaseRequestLine extends Equatable {
  const PurchaseRequestLine({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    this.uom = '',
    this.warehouse = '',
  });
  final String itemCode, itemName, uom, warehouse;
  final double qty;
  Map<String, dynamic> toMap() => {
        'item_code': itemCode,
        'qty': qty,
        if (uom.isNotEmpty) 'uom': uom,
        if (warehouse.isNotEmpty) 'warehouse': warehouse,
      };
  @override
  List<Object> get props => [itemCode, itemName, qty, uom, warehouse];
}

class PurchaseRequestResult extends Equatable {
  const PurchaseRequestResult({
    required this.name,
    required this.workflowInstance,
    required this.localOnly,
  });
  final String name, workflowInstance;
  final bool localOnly;
  @override
  List<Object> get props => [name, workflowInstance, localOnly];
}

class PurchaseRequestSummary extends Equatable {
  const PurchaseRequestSummary({
    required this.name,
    required this.status,
    required this.scheduleDate,
    this.workflowInstance = '',
    this.localOnly = false,
  });
  final String name, status, workflowInstance;
  final DateTime? scheduleDate;
  final bool localOnly;
  @override
  List<Object?> get props =>
      [name, status, workflowInstance, scheduleDate, localOnly];
}
