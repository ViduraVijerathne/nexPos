import '../models/models.dart';

abstract class InsightRepository {
  Future<void> initialize();

  Future<InsightDashboardData> fetchDashboardData({
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<void> deactivateExpiredStock(InsightExpiredStockItem item);
}
