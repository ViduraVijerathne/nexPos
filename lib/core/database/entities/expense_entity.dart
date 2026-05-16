import 'package:isar/isar.dart';

part 'expense_entity.g.dart';

enum ExpenseEntityStatus { active, inactive }

@collection
class ExpenseEntity {
  ExpenseEntity();

  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String title;

  @Index(caseSensitive: false)
  late String category;

  late double amount;
  late DateTime expenseDate;
  late String paymentMethod;
  bool paidFromDrawer = false;
  late String notes;
  @enumerated
  late ExpenseEntityStatus status;
  late DateTime createdAt;
  DateTime? updatedAt;
}
