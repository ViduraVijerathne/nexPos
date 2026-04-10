import '../models/models.dart';

abstract class ReportRepository {
  Future<void> initialize();

  Future<ReportDashboardData> fetchDashboardData({
    required DateTime fromDate,
    required DateTime toDate,
  });
}
