import '../models/models.dart';

abstract class StockRepository {
  Future<void> initialize();

  Future<StockPageResult> fetchStocks({
    required int page,
    String? barcodeQuery,
    String? productQuery,
    String? grnQuery,
    String? statusFilter,
    int? qtyLessThan,
    int? qtyGreaterThan,
  });

  Future<List<String>> fetchProductSuggestions();

  Future<List<String>> fetchGrnSuggestions();

  Future<StockRecord?> fetchStockDetails(StockRecord stock);

  Future<StockRecord> saveStock(StockRecord stock);

  Future<StockRecord?> deactivateStock(StockRecord stock);
}
