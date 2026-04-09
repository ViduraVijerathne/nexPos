import '../models/models.dart';

abstract class ProductRepository {
  Future<void> initialize();

  Future<ProductPageResult> fetchProducts({
    required int page,
    String? nameQuery,
    String? categoryQuery,
    String? barcodeQuery,
  });

  Future<List<String>> fetchCategorySuggestions(String query);

  Future<bool> categoryExists(String categoryName);

  Future<String> createCategory(String categoryName);

  Future<ProductRecord?> fetchProductByName(String productName);

  Future<ProductRecord> saveProduct(ProductRecord product);
}
