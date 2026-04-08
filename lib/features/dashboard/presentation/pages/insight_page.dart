import 'dart:math' as math;

import 'package:flutter/material.dart';

class InsightPage extends StatelessWidget {
  const InsightPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsightHeader(),
          SizedBox(height: 18),
          _InsightMetrics(),
          SizedBox(height: 18),
          _SalesPerformanceCard(),
          SizedBox(height: 18),
          _DashboardBottomPanels(),
        ],
      ),
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
  const _InsightMetrics();

  static const _metrics = [
    _MetricData(
      title: 'Total Sales',
      value: '\$31338.60',
      note: '+100.0% from last month',
      icon: Icons.attach_money_rounded,
      iconColor: Color(0xFF30B7B0),
      iconBackground: Color(0xFFE8FBF7),
      noteColor: Color(0xFF58C7BC),
    ),
    _MetricData(
      title: 'Total Orders',
      value: '18',
      note: '+100.0% from last month',
      icon: Icons.shopping_cart_outlined,
      iconColor: Color(0xFF58A7F5),
      iconBackground: Color(0xFFEAF5FF),
      noteColor: Color(0xFF4F97F1),
    ),
    _MetricData(
      title: 'Active Products',
      value: '11',
      note: 'Across 8 categories',
      icon: Icons.inventory_2_outlined,
      iconColor: Color(0xFFF0AA3B),
      iconBackground: Color(0xFFFFF4E3),
      noteColor: Color(0xFF8E9BB0),
    ),
    _MetricData(
      title: 'Total Customers',
      value: '12',
      note: '+15.3% new customers',
      icon: Icons.people_outline_rounded,
      iconColor: Color(0xFFC06AE9),
      iconBackground: Color(0xFFF9EBFF),
      noteColor: Color(0xFFC06AE9),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in _metrics)
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
  const _SalesPerformanceCard();

  @override
  Widget build(BuildContext context) {
    const points = [
      _ChartPoint('Apr 02', 0),
      _ChartPoint('Apr 03', 0),
      _ChartPoint('Apr 04', 0),
      _ChartPoint('Apr 05', 0),
      _ChartPoint('Apr 06', 27000),
      _ChartPoint('Apr 07', 5000),
      _ChartPoint('Apr 08', 0),
    ];

    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Sales Performance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374457),
                ),
              ),
              Spacer(),
              _DateRangeChip('Apr 02, 2026'),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'to',
                  style: TextStyle(
                    color: Color(0xFF8A98AC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _DateRangeChip('Apr 08, 2026'),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 254, child: _SalesChart(points: points)),
          const SizedBox(height: 8),
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.show_chart_rounded,
                  size: 15,
                  color: Color(0xFF43C2BE),
                ),
                SizedBox(width: 4),
                Text(
                  'Sales (\$)',
                  style: TextStyle(
                    color: Color(0xFF43C2BE),
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
  }
}

class _DashboardBottomPanels extends StatelessWidget {
  const _DashboardBottomPanels();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 11, child: _StockAllocationCard()),
        SizedBox(width: 18),
        Expanded(flex: 11, child: _LowStockAlertCard()),
      ],
    );
  }
}

class _StockAllocationCard extends StatelessWidget {
  const _StockAllocationCard();

  static const _items = [
    _CategoryStockData('Cream Crackers', 38, Color(0xFF36B4AE)),
    _CategoryStockData('Beverages', 24, Color(0xFF64A7F7)),
    _CategoryStockData('Biscuits', 18, Color(0xFFF0B34F)),
    _CategoryStockData('Snacks', 12, Color(0xFFC875EF)),
    _CategoryStockData('Other', 8, Color(0xFF98A6BA)),
  ];

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
          Row(
            children: [
              const SizedBox(
                width: 188,
                height: 188,
                child: _CategoryDonutChart(items: _items),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: [
                    for (final item in _items) ...[
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
  }
}

class _LowStockAlertCard extends StatelessWidget {
  const _LowStockAlertCard();

  static const _alerts = [
    _LowStockItem('manchee super cream cracker', 'Low Stock'),
    _LowStockItem('cream cracker large pack', 'Running Low'),
    _LowStockItem('orange crush 500ml', 'Low Stock'),
    _LowStockItem('chocolate wafer bites', 'Running Low'),
  ];

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
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF3E7CF)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _alerts.length; i++) ...[
                  _LowStockRow(item: _alerts[i]),
                  if (i != _alerts.length - 1)
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

class _InsightMetricCard extends StatelessWidget {
  const _InsightMetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
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
              color: Color(0xFF93A0B2),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            metric.value,
            style: const TextStyle(
              color: Color(0xFF39475B),
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
  const _DateRangeChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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

  final List<_ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    const yLabels = ['28000', '21000', '14000', '7000', '0'];

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
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _SalesChartPainter(points),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final point in points)
                    Text(
                      point.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF98A5B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
          '${item.percentage}%',
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

  final _LowStockItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
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
            style: const TextStyle(
              color: Color(0xFFF0AE42),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  const _SalesChartPainter(this.points);

  final List<_ChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE7EDF5)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFB8C4D3)
      ..strokeWidth = 1.2;
    final linePaint = Paint()
      ..color = const Color(0xFF45C1BC)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = const Color(0xFF45C1BC);

    final chartHeight = size.height - 10;
    final maxValue = 28000.0;
    final stepX = size.width / (points.length - 1);

    for (var i = 0; i < 5; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < points.length; i++) {
      final x = stepX * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, chartHeight),
        Paint()
          ..color = const Color(0xFFE9EEF6)
          ..strokeWidth = 1,
      );
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

    canvas.drawPath(path, linePaint);

    for (final offset in offsets) {
      canvas.drawCircle(offset, 3.8, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.points != points;
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
  });

  final String title;
  final String value;
  final String note;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color noteColor;
}

class _ChartPoint {
  const _ChartPoint(this.label, this.value);

  final String label;
  final double value;
}

class _CategoryStockData {
  const _CategoryStockData(this.label, this.percentage, this.color);

  final String label;
  final int percentage;
  final Color color;
}

class _LowStockItem {
  const _LowStockItem(this.name, this.status);

  final String name;
  final String status;
}
