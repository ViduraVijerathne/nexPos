import '../models/models.dart';

abstract class LabelPrinterRepository {
  Future<void> initialize();

  Future<LabelPrinterPageResult> fetchItems({
    required LabelPrinterSource source,
    required int page,
    String? searchQuery,
  });
}
