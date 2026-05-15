import 'package:isar/isar.dart';

part 'invoice_entity.g.dart';

enum InvoiceEntityStatus { paid, pending, overdue }

@embedded
class InvoiceLineItemEmbedded {
  InvoiceLineItemEmbedded();

  late String name;
  int quantity = 0;
  double unitPrice = 0;

  double get subtotal => quantity * unitPrice;
}

@collection
class InvoiceEntity {
  InvoiceEntity();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String invoiceNumber;

  @Index(caseSensitive: false)
  late String customerName;

  @Index(caseSensitive: false)
  String? customerCode;

  @Index()
  int? customerDbId;

  late DateTime issuedAt;
  double discountAmount = 0;
  late double totalAmount;
  @enumerated
  late InvoiceEntityStatus status;
  late String paymentMethod;
  late String cashierName;
  List<InvoiceLineItemEmbedded> items = <InvoiceLineItemEmbedded>[];
  late DateTime createdAt;
  DateTime? updatedAt;

  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.subtotal);
  double get tax => totalAmount - (subtotal - discountAmount);
}
