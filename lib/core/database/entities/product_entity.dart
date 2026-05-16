import 'package:isar/isar.dart';

part 'product_entity.g.dart';

enum ProductEntityStatus { active, inactive }

@collection
class ProductEntity {
  ProductEntity();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String barcode;

  @Index(caseSensitive: false)
  late String name;

  @Index(caseSensitive: false)
  late String category;

  late String unit;
  late int lowStockQuantity;
  bool isQuickSelling = false;
  @enumerated
  late ProductEntityStatus status;
  late DateTime createdAt;
  DateTime? updatedAt;
}
