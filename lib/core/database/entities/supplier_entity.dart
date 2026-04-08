import 'package:isar/isar.dart';

part 'supplier_entity.g.dart';

@collection
class SupplierEntity {
  SupplierEntity();

  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String supplierName;

  @Index(caseSensitive: false)
  late String companyName;

  @Index(caseSensitive: false)
  late String contactNumber;

  @Index(caseSensitive: false)
  late String email;

  String? companyContact;
  late String address;
  bool isActive = true;
  late DateTime createdAt;
  DateTime? updatedAt;
}
