import 'package:isar/isar.dart';

part 'stock_entity.g.dart';

enum StockEntityStatus { active, inactive }

@collection
class StockEntity {
  StockEntity();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String barcode;

  @Index(caseSensitive: false)
  late String productName;

  @Index(caseSensitive: false)
  String? productBarcode;

  @Index(caseSensitive: false)
  String? grnCode;

  late int initialQuantity;
  late int availableQuantity;
  late double buyingPrice;
  late double sellingPrice;
  late double maxDiscount;
  @enumerated
  late StockEntityStatus status;
  DateTime? expiryDate;
  late DateTime createdAt;
  DateTime? updatedAt;
}
