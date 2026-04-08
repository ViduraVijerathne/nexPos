import 'package:isar/isar.dart';

import 'entities/entities.dart';

final List<CollectionSchema<dynamic>> appIsarSchemas = [
  CustomerEntitySchema,
  GrnEntitySchema,
  InvoiceEntitySchema,
  ProductEntitySchema,
  StockEntitySchema,
  SupplierEntitySchema,
];
