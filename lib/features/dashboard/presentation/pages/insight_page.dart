import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../data/insight_remote_repository.dart';
import '../../data/insight_repository.dart';
import '../../data/insight_repository_factory.dart';
import '../../models/models.dart';

class InsightPage extends StatefulWidget {
  const InsightPage({super.key});

  @override
  State<InsightPage> createState() => _InsightPageState();
}

class _InsightPageState extends State<InsightPage> {
  InsightRepository? _repository;
  bool _isLoading = true;
  bool _isDeactivatingExpiredStock = false;
  String? _deactivatingExpiredStockKey;
  InsightDashboardData? _dashboardData;
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    _toDate = DateTime.now();
    _fromDate = _toDate.subtract(const Duration(days: 6));
    _initializePage();
  }

  Future<void> _initializePage() async {
    try {
      final repository = _repository ?? await InsightRepositoryFactory.create();
      await repository.initialize();
      final dashboardData = await repository.fetchDashboardData(
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _dashboardData = dashboardData;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error(
        'Failed to load business insights: ${_readableError(error)}',
      );
    }
  }

  Future<void> _pickFromDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _fromDate = selected;
      if (_fromDate.isAfter(_toDate)) {
        _toDate = _fromDate;
      }
      _isLoading = true;
    });
    await _initializePage();
  }

  Future<void> _pickToDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _toDate = selected;
      if (_toDate.isBefore(_fromDate)) {
        _fromDate = _toDate;
      }
      _isLoading = true;
    });
    await _initializePage();
  }

  Future<void> _deactivateExpiredStock(InsightExpiredStockItem item) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('Insight service is still loading. Please try again.');
      return;
    }

    try {
      setState(() {
        _isDeactivatingExpiredStock = true;
        _deactivatingExpiredStockKey = item.cloudId ?? '${item.id}';
      });
      await repository.deactivateExpiredStock(item);
      await _initializePage();
      AppToast.success('${item.name} removed from active inventory');
    } catch (error) {
      AppToast.error('Failed to deactivate stock: ${_readableError(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isDeactivatingExpiredStock = false;
          _deactivatingExpiredStockKey = null;
        });
      }
    }
  }

  String _readableError(Object error) {
    if (error is InsightRemoteRepositoryException) {
      return error.message;
    }
    return '$error';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _InsightPageSkeleton();
    }

    final dashboardData = _dashboardData;
    if (dashboardData == null) {
      return const Center(
        child: Text(
          'No insight data available',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8492A6),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 12.0 : 18.0;
        final verticalSpacing = constraints.maxWidth < 640 ? 14.0 : 18.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InsightHeader(),
              SizedBox(height: verticalSpacing),
              _InsightMetrics(data: dashboardData),
              SizedBox(height: verticalSpacing),
              _SalesPerformanceCard(
                data: dashboardData,
                onFromTap: _pickFromDate,
                onToTap: _pickToDate,
              ),
              SizedBox(height: verticalSpacing),
              _DashboardBottomPanels(data: dashboardData),
              SizedBox(height: verticalSpacing),
              _ExpiredStocksCard(
                items: dashboardData.expiredStockItems,
                onDeactivate: _deactivateExpiredStock,
                deactivatingItemKey: _deactivatingExpiredStockKey,
                isDeactivating: _isDeactivatingExpiredStock,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightHeader extends StatelessWidget {
  const _InsightHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Insights',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334156),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Overview of your business performance and key metrics.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8492A6),
          ),
        ),
      ],
    );
  }
}

class _InsightMetrics extends StatelessWidget {
  const _InsightMetrics({required this.data});

  final InsightDashboardData data;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        title: 'Total Sales',
        value: 'Rs ${data.totalSales.toStringAsFixed(2)}',
        note: data.salesGrowthNote,
        icon: Icons.attach_money_rounded,
        iconColor: const Color(0xFF30B7B0),
        iconBackground: const Color(0xFFE8FBF7),
        noteColor: const Color(0xFF58C7BC),
        gradientStart: const Color(0xFFF1FFFC),
        gradientEnd: const Color(0xFFDDF7F2),
      ),
      _MetricData(
        title: 'Total Purchase',
        value: 'Rs ${data.totalPurchase.toStringAsFixed(2)}',
        note: data.purchasesNote,
        icon: Icons.local_shipping_outlined,
        iconColor: const Color(0xFFF0AA3B),
        iconBackground: const Color(0xFFFFF4E3),
        noteColor: const Color(0xFF8E9BB0),
        gradientStart: const Color(0xFFFFFAF0),
        gradientEnd: const Color(0xFFFFEFD2),
      ),
      _MetricData(
        title: 'Total Expenses',
        value: 'Rs ${data.totalExpenses.toStringAsFixed(2)}',
        note: data.expensesNote,
        icon: Icons.receipt_long_outlined,
        iconColor: const Color(0xFFE66A6A),
        iconBackground: const Color(0xFFFFECEC),
        noteColor: const Color(0xFFE66A6A),
        gradientStart: const Color(0xFFFFF5F5),
        gradientEnd: const Color(0xFFFFE3E3),
      ),
      _MetricData(
        title: 'Total Orders',
        value: '${data.totalOrders}',
        note: data.ordersGrowthNote,
        icon: Icons.shopping_cart_outlined,
        iconColor: const Color(0xFF58A7F5),
        iconBackground: const Color(0xFFEAF5FF),
        noteColor: const Color(0xFF4F97F1),
        gradientStart: const Color(0xFFF4FAFF),
        gradientEnd: const Color(0xFFE1F0FF),
      ),
      _MetricData(
        title: 'Active Products',
        value: '${data.activeProducts}',
        note: data.productsNote,
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFFF0AA3B),
        iconBackground: const Color(0xFFFFF4E3),
        noteColor: const Color(0xFF8E9BB0),
        gradientStart: const Color(0xFFFFFAF0),
        gradientEnd: const Color(0xFFFFEFD9),
      ),
      _MetricData(
        title: 'Total Customers',
        value: '${data.totalCustomers}',
        note: data.customersNote,
        icon: Icons.people_outline_rounded,
        iconColor: const Color(0xFFC06AE9),
        iconBackground: const Color(0xFFF9EBFF),
        noteColor: const Color(0xFFC06AE9),
        gradientStart: const Color(0xFFFCF6FF),
        gradientEnd: const Color(0xFFF2E3FF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1440
            ? 6
            : constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final totalSpacing = 12.0 * (columns - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth.clamp(220.0, 320.0),
                child: _InsightMetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _SalesPerformanceCard extends StatelessWidget {
  const _SalesPerformanceCard({
    required this.data,
    required this.onFromTap,
    required this.onToTap,
  });

  final InsightDashboardData data;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.primaryTeal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;

        return _DashboardCard(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 14 : 20,
            18,
            isCompact ? 14 : 20,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                const Text(
                  'Sales Performance',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374457),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DateRangeChip(data.chartDateFromLabel, onTap: onFromTap),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        'to',
                        style: TextStyle(
                          color: Color(0xFF8A98AC),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _DateRangeChip(data.chartDateToLabel, onTap: onToTap),
                  ],
                ),
              ] else
                Row(
                  children: [
                    const Text(
                      'Sales Performance',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    const Spacer(),
                    _DateRangeChip(data.chartDateFromLabel, onTap: onFromTap),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'to',
                        style: TextStyle(
                          color: Color(0xFF8A98AC),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _DateRangeChip(data.chartDateToLabel, onTap: onToTap),
                  ],
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: isCompact ? 220 : 254,
                child: _SalesChart(points: data.salesPoints),
              ),
              const SizedBox(height: 8),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 15,
                      color: accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sales (Rs)',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardBottomPanels extends StatelessWidget {
  const _DashboardBottomPanels({required this.data});

  final InsightDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              _StockAllocationCard(items: data.categoryAllocation),
              const SizedBox(height: 18),
              _LowStockAlertCard(alerts: data.lowStockItems),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: _StockAllocationCard(items: data.categoryAllocation),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 11,
              child: _LowStockAlertCard(alerts: data.lowStockItems),
            ),
          ],
        );
      },
    );
  }
}

class _StockAllocationCard extends StatelessWidget {
  const _StockAllocationCard({required this.items});

  final List<InsightCategoryAllocation> items;

  @override
  Widget build(BuildContext context) {
    final chartItems = items.isEmpty
        ? const <_CategoryStockData>[
            _CategoryStockData('No Data', 100, Color(0xFFCBD5E1)),
          ]
        : [
            for (var i = 0; i < items.length; i++)
              _CategoryStockData(
                items[i].label,
                items[i].percentage,
                _allocationColors[i % _allocationColors.length],
              ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;

        return _DashboardCard(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 14 : 20,
            18,
            isCompact ? 14 : 20,
            18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stock Allocation by Category',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374457),
                ),
              ),
              const SizedBox(height: 22),
              if (isCompact) ...[
                Center(
                  child: SizedBox(
                    width: 188,
                    height: 188,
                    child: _CategoryDonutChart(items: chartItems),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    for (final item in chartItems) ...[
                      _CategoryLegendRow(item: item),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ] else
                Row(
                  children: [
                    SizedBox(
                      width: 188,
                      height: 188,
                      child: _CategoryDonutChart(items: chartItems),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        children: [
                          for (final item in chartItems) ...[
                            _CategoryLegendRow(item: item),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LowStockAlertCard extends StatelessWidget {
  const _LowStockAlertCard({required this.alerts});

  final List<InsightLowStockItem> alerts;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.warning_amber_rounded,
                size: 22,
                color: Color(0xFFF2B047),
              ),
              SizedBox(width: 10),
              Text(
                'Low Stock Alert',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374457),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF3E7CF)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No low stock alerts right now',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8E9BB0),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF3E7CF)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < alerts.length; i++) ...[
                    _LowStockRow(item: alerts[i]),
                    if (i != alerts.length - 1)
                      const Divider(height: 1, color: Color(0xFFF5F1E7)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpiredStocksCard extends StatelessWidget {
  const _ExpiredStocksCard({
    required this.items,
    required this.onDeactivate,
    required this.deactivatingItemKey,
    required this.isDeactivating,
  });

  final List<InsightExpiredStockItem> items;
  final ValueChanged<InsightExpiredStockItem> onDeactivate;
  final String? deactivatingItemKey;
  final bool isDeactivating;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.event_busy_outlined,
                size: 22,
                color: Color(0xFFE45A5A),
              ),
              SizedBox(width: 10),
              Text(
                'Expired Stocks',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374457),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF1D5D5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No expired active stocks found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8E9BB0),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF1D5D5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _ExpiredStockRow(
                      item: items[i],
                      isLoading:
                          isDeactivating &&
                          deactivatingItemKey ==
                              (items[i].cloudId ?? '${items[i].id}'),
                      onDeactivate: () => onDeactivate(items[i]),
                    ),
                    if (i != items.length - 1)
                      const Divider(height: 1, color: Color(0xFFF6E9E9)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightMetricCard extends StatelessWidget {
  const _InsightMetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [metric.gradientStart, metric.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.lerp(metric.gradientEnd, metric.iconColor, 0.18)!,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: metric.iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(metric.icon, color: metric.iconColor, size: 23),
          ),
          const SizedBox(height: 14),
          Text(
            metric.title,
            style: const TextStyle(
              color: Color(0xFF7F8EA3),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            metric.value,
            style: const TextStyle(
              color: Color(0xFF334156),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            metric.note,
            style: TextStyle(
              color: metric.noteColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3E9F1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: Color(0xFF5D6A7D),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4C5A6D),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.points});

  final List<InsightSalesPoint> points;

  int _labelStep(double chartWidth) {
    if (points.length <= 1) {
      return 1;
    }

    const minLabelWidth = 56.0;
    final maxVisibleLabels = math.max(2, (chartWidth / minLabelWidth).floor());
    return math.max(1, (points.length / maxVisibleLabels).ceil());
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.primaryTeal;
    final accentFillColor = Color.lerp(
      Colors.white,
      AppColors.primaryLight,
      0.88,
    )!;
    final gridColor = Color.lerp(const Color(0xFFE7EDF5), accentColor, 0.08)!;
    final axisColor = Color.lerp(const Color(0xFFB8C4D3), accentColor, 0.16)!;
    final maxValue = points.isEmpty
        ? 1.0
        : points
                  .map((point) => point.value)
                  .reduce(math.max)
                  .clamp(1.0, double.infinity) *
              1.1;
    final yLabels = [
      _compactAmount(maxValue),
      _compactAmount(maxValue * 0.75),
      _compactAmount(maxValue * 0.5),
      _compactAmount(maxValue * 0.25),
      '0',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < yLabels.length; i++) ...[
                SizedBox(
                  height: i == yLabels.length - 1 ? 23 : 47,
                  child: Text(
                    yLabels[i],
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF98A5B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labelStep = _labelStep(constraints.maxWidth);

              return Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      painter: _SalesChartPainter(
                        points,
                        maxValue,
                        lineColor: accentColor,
                        pointColor: accentColor,
                        fillColor: accentFillColor,
                        gridColor: gridColor,
                        axisColor: axisColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (var index = 0; index < points.length; index++)
                        Expanded(
                          child: Align(
                            alignment: index == 0
                                ? Alignment.centerLeft
                                : index == points.length - 1
                                ? Alignment.centerRight
                                : Alignment.center,
                            child:
                                index == 0 ||
                                    index == points.length - 1 ||
                                    index % labelStep == 0
                                ? Text(
                                    points[index].label,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF98A5B8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _compactAmount(double value) {
    if (value >= 1000) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(0);
  }
}

class _CategoryDonutChart extends StatelessWidget {
  const _CategoryDonutChart({required this.items});

  final List<_CategoryStockData> items;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CategoryDonutPainter(items),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              '100%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334156),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Stock Share',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF95A2B5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({required this.item});

  final _CategoryStockData item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.label,
            style: const TextStyle(
              color: Color(0xFF55647A),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${item.percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Color(0xFF8E9BB0),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item});

  final InsightLowStockItem item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Color(0xFF4C5A6D),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.status,
                      style: TextStyle(
                        color: item.status == 'Out of Stock'
                            ? const Color(0xFFEA5A5A)
                            : const Color(0xFFF0AE42),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Color(0xFF4C5A6D),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.status,
                      style: TextStyle(
                        color: item.status == 'Out of Stock'
                            ? const Color(0xFFEA5A5A)
                            : const Color(0xFFF0AE42),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ExpiredStockRow extends StatelessWidget {
  const _ExpiredStockRow({
    required this.item,
    required this.onDeactivate,
    required this.isLoading,
  });

  final InsightExpiredStockItem item;
  final VoidCallback onDeactivate;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        final actionButton = TextButton(
          onPressed: isLoading ? null : onDeactivate,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE45A5A),
            backgroundColor: const Color(0xFFFFEEEE),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE45A5A),
                  ),
                )
              : const Text(
                  'Deactivate',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Color(0xFF4C5A6D),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.barcode,
                      style: const TextStyle(
                        color: Color(0xFF8E9BB0),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.expiryDate,
                      style: const TextStyle(
                        color: Color(0xFFE45A5A),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    actionButton,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 34,
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Color(0xFF4C5A6D),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 24,
                      child: Text(
                        item.barcode,
                        style: const TextStyle(
                          color: Color(0xFF8E9BB0),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 18,
                      child: Text(
                        item.expiryDate,
                        style: const TextStyle(
                          color: Color(0xFFE45A5A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 24,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: actionButton,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _InsightPageSkeleton extends StatelessWidget {
  const _InsightPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        final columns = constraints.maxWidth >= 1440
            ? 6
            : constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final totalSpacing = 12.0 * (columns - 1);
        final metricWidth = (constraints.maxWidth - totalSpacing) / columns;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InsightHeader(),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List<Widget>.generate(
                  6,
                  (index) => SizedBox(
                    width: metricWidth.clamp(220.0, 420.0),
                    child: Container(
                      height: 132,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: isCompact ? 300 : 340,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 18),
              if (constraints.maxWidth < 980) ...[
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 260,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Container(
                        height: 260,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  const _SalesChartPainter(
    this.points,
    this.maxValue, {
    required this.lineColor,
    required this.pointColor,
    required this.fillColor,
    required this.gridColor,
    required this.axisColor,
  });

  final List<InsightSalesPoint> points;
  final double maxValue;
  final Color lineColor;
  final Color pointColor;
  final Color fillColor;
  final Color gridColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.16)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final pointPaint = Paint()..color = pointColor;
    final pointOuterPaint = Paint()..color = Colors.white;
    final verticalGridPaint = Paint()
      ..color = fillColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    final chartHeight = size.height - 10;
    final stepX = points.length == 1
        ? size.width
        : size.width / (points.length - 1);

    for (var i = 0; i < 5; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < points.length; i++) {
      final x = stepX * i;
      canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), verticalGridPaint);
    }

    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      axisPaint,
    );
    canvas.drawLine(const Offset(0, 0), Offset(0, chartHeight), axisPaint);

    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = stepX * i;
      final y = chartHeight - ((points[i].value / maxValue) * chartHeight);
      offsets.add(Offset(x, y));
    }

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 0; i < offsets.length - 1; i++) {
      final current = offsets[i];
      final next = offsets[i + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(offsets.last.dx, chartHeight)
      ..lineTo(offsets.first.dx, chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.08),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    for (final offset in offsets) {
      canvas.drawCircle(offset, 5.2, pointOuterPaint);
      canvas.drawCircle(offset, 3.8, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor;
  }
}

class _CategoryDonutPainter extends CustomPainter {
  const _CategoryDonutPainter(this.items);

  final List<_CategoryStockData> items;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius - 8);
    const strokeWidth = 18.0;
    var startAngle = -math.pi / 2;

    for (final item in items) {
      final sweepAngle = (item.percentage / 100) * math.pi * 2;
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + 0.03;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.note,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.noteColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final String title;
  final String value;
  final String note;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color noteColor;
  final Color gradientStart;
  final Color gradientEnd;
}

class _CategoryStockData {
  const _CategoryStockData(this.label, this.percentage, this.color);

  final String label;
  final double percentage;
  final Color color;
}

const List<Color> _allocationColors = <Color>[
  Color(0xFF36B4AE),
  Color(0xFF64A7F7),
  Color(0xFFF0B34F),
  Color(0xFFC875EF),
  Color(0xFF98A6BA),
];
