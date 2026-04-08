import 'package:isar/isar.dart';

part 'grn_entity.g.dart';

@embedded
class GrnItemEmbedded {
  GrnItemEmbedded();

  late String productName;
  String? productBarcode;
  late String stockBarcode;
  late int quantity;
  late double buyingPrice;
  late double sellingPrice;
  double maxDiscount = 0;
  bool inStock = false;

  double get subtotal => quantity * buyingPrice;
}

@embedded
class GrnPaymentEmbedded {
  GrnPaymentEmbedded();

  late DateTime paidAt;
  late double amount;
  late String method;
  late double remainingBalance;
}

@collection
class GrnEntity {
  GrnEntity();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String code;

  @Index(caseSensitive: false)
  late String supplierName;

  @Index()
  int? supplierDbId;

  late DateTime date;
  late double subTotal;
  late double discount;
  late double paidAmount;
  late String paymentMethod;
  List<GrnItemEmbedded> items = <GrnItemEmbedded>[];
  List<GrnPaymentEmbedded> paymentHistory = <GrnPaymentEmbedded>[];
  late DateTime createdAt;
  DateTime? updatedAt;

  double get total => subTotal - discount;
  double get dueAmount => total - paidAmount;
}
