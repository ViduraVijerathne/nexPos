import 'package:isar/isar.dart';

part 'customer_entity.g.dart';

@collection
class CustomerEntity {
  CustomerEntity();

  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String name;

  @Index(caseSensitive: false)
  late String email;

  @Index(caseSensitive: false)
  late String phone;

  late String address;
  late DateTime joinDate;
  late DateTime createdAt;
  DateTime? updatedAt;
}
