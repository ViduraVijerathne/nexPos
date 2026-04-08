import 'package:isar/isar.dart';

part 'category_entity.g.dart';

@collection
class CategoryEntity {
  CategoryEntity();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true, caseSensitive: false)
  late String name;

  late DateTime createdAt;
  DateTime? updatedAt;
}
