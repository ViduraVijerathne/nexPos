import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../data/report_local_repository.dart';
import '../../models/models.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final ReportLocalRepository _repository = const ReportLocalRepository();
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _isLoading = true;
  ReportDashboardData? _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
    _initializePage();
  }

  Future<void> _initializePage() async {
    try {
      await _repository.initialize();
      final data = await _repository.fetchDashboardData(
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error('Failed to load reports: $error');
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

  void _showExportToast(String section) {
    AppToast.success('$section exported successfully');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryTeal),
      );
    }

    final data = _data;
    if (data == null) {
      return const Center(
        child: Text(
          'No report data available',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8492A6),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportsHeader(
            fromDateLabel: data.fromDateLabel,
            toDateLabel: data.toDateLabel,
            onFromTap: _pickFromDate,
            onToTap: _pickToDate,
            onPrintAll: () => _showExportToast('All reports'),
          ),
          const SizedBox(height: 18),
          _ReportSummaryCards(summary: data.summary),
          const SizedBox(height: 22),
          const _SectionBanner(
            title: 'Sales Reports',
            subtitle: 'Track sales performance and payment trends',
            background: Color(0xFF36B4AE),
          ),
          const SizedBox(height: 18),
          _DailySalesSummaryCard(
            points: data.salesPoints,
            onExport: () => _showExportToast('Daily sales summary'),
          ),
          const SizedBox(height: 18),
          _TaxTrendCard(
            points: data.taxPoints,
            onExport: () => _showExportToast('Tax report'),
          ),
          const SizedBox(height: 22),
          const _SectionBanner(
            title: 'Inventory Reports',
            subtitle: 'Monitor stock levels and valuation',
            background: Color(0xFFD88F21),
          ),
          const SizedBox(height: 18),
          _LowStockReportCard(
            rows: data.lowStockRows,
            onExport: () => _showExportToast('Low stock report'),
          ),
          const SizedBox(height: 18),
          _StockValuationCard(
            rows: data.stockValuationRows,
            onExport: () => _showExportToast('Stock valuation report'),
          ),
          const SizedBox(height: 22),
          const _SectionBanner(
            title: 'Customer Reports',
            subtitle: 'Top customers and purchase patterns',
            background: Color(0xFF9B28BE),
          ),
          const SizedBox(height: 18),
          _TopCustomersCard(
            rows: data.topCustomers,
            onExport: () => _showExportToast('Top customers report'),
          ),
        ],
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.fromDateLabel,
    required this.toDateLabel,
    required this.onFromTap,
    required this.onToTap,
    required this.onPrintAll,
  });

  final String fromDateLabel;
  final String toDateLabel;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onPrintAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports & Analytics',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334156),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Comprehensive business reports with real-time data.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8492A6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _DatePickerChip(label: fromDateLabel, onTap: onFromTap),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            'to',
            style: TextStyle(
              color: Color(0xFF8A98AC),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _DatePickerChip(label: toDateLabel, onTap: onToTap),
        const SizedBox(width: 12),
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: onPrintAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF36B4AE),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text(
              'Print All',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportSummaryCards extends StatelessWidget {
  const _ReportSummaryCards({required this.summary});

  final ReportSummaryData summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCardData(
        label: 'Total Revenue',
        value: 'Rs ${summary.totalRevenue.toStringAsFixed(2)}',
        note: '${summary.totalOrders} orders',
      ),
      _SummaryCardData(
        label: 'Tax Collected',
        value: 'Rs ${summary.totalTax.toStringAsFixed(2)}',
        note: 'For selected duration',
      ),
      _SummaryCardData(
        label: 'Avg. Order Value',
        value: 'Rs ${summary.averageOrderValue.toStringAsFixed(2)}',
        note: 'Per transaction',
      ),
      _SummaryCardData(
        label: 'Stock Value',
        value: 'Rs ${summary.stockValue.toStringAsFixed(2)}',
        note: '${summary.activeProducts} active products',
      ),
      _SummaryCardData(
        label: 'Low Stock Items',
        value: '${summary.lowStockItemsCount}',
        note: 'Need attention',
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: _SummaryCard(data: cards[i])),
          if (i != cards.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _SectionBanner extends StatelessWidget {
  const _SectionBanner({
    required this.title,
    required this.subtitle,
    required this.background,
  });

  final String title;
  final String subtitle;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFFF1F5F9),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailySalesSummaryCard extends StatelessWidget {
  const _DailySalesSummaryCard({required this.points, required this.onExport});

  final List<ReportSalesPoint> points;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Sales Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Sales and order trends',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 260, child: _SalesBarChart(points: points)),
        ],
      ),
    );
  }
}

class _TaxTrendCard extends StatelessWidget {
  const _TaxTrendCard({required this.points, required this.onExport});

  final List<ReportSalesPoint> points;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax Collection Trend',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tax collected for the selected duration',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: _TrendLineChart(
              points: points,
              lineColor: const Color(0xFF9B28BE),
              fillColor: const Color(0x229B28BE),
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockReportCard extends StatelessWidget {
  const _LowStockReportCard({required this.rows, required this.onExport});

  final List<ReportLowStockRow> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Low Stock Alert',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Products requiring immediate attention',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 14),
          const _LowStockTableHeader(),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No low stock items found',
                  style: TextStyle(
                    color: Color(0xFF8A97AA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (final row in rows.take(8)) ...[
              _LowStockTableRow(row: row),
              const Divider(height: 1, color: Color(0xFFF0F4F8)),
            ],
        ],
      ),
    );
  }
}

class _StockValuationCard extends StatelessWidget {
  const _StockValuationCard({required this.rows, required this.onExport});

  final List<ReportStockValuationRow> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Valuation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Total inventory value by category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 14),
          const _StockValuationTableHeader(),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No stock valuation data found',
                  style: TextStyle(
                    color: Color(0xFF8A97AA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (final row in rows) ...[
              _StockValuationTableRow(row: row),
              const Divider(height: 1, color: Color(0xFFF0F4F8)),
            ],
        ],
      ),
    );
  }
}

class _TopCustomersCard extends StatelessWidget {
  const _TopCustomersCard({required this.rows, required this.onExport});

  final List<ReportTopCustomerRow> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Customers',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Customers ranked by total purchases',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 14),
          const _TopCustomersTableHeader(),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No customer report data found',
                  style: TextStyle(
                    color: Color(0xFF8A97AA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (final row in rows) ...[
              _TopCustomersTableRow(row: row),
              const Divider(height: 1, color: Color(0xFFF0F4F8)),
            ],
        ],
      ),
    );
  }
}

class _DatePickerChip extends StatelessWidget {
  const _DatePickerChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E9F1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Color(0xFF5D6A7D),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4C5A6D),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A97AA),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.note,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A97AA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF374457),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.download_outlined, size: 16),
      label: const Text(
        'Export',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: child,
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  const _SalesBarChart({required this.points});

  final List<ReportSalesPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.isEmpty
        ? 1.0
        : (points.map((point) => point.value).reduce(math.max) * 1.05).clamp(
            1.0,
            double.infinity,
          );

    return CustomPaint(
      painter: _SalesBarChartPainter(points: points, maxValue: maxValue),
      child: const SizedBox.expand(),
    );
  }
}

class _SalesBarChartPainter extends CustomPainter {
  const _SalesBarChartPainter({required this.points, required this.maxValue});

  final List<ReportSalesPoint> points;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadding = 54.0;
    final bottomPadding = 28.0;
    final topPadding = 10.0;
    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFE7EDF5)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFB8C4D3)
      ..strokeWidth = 1.2;
    final barPaint = Paint()..color = const Color(0xFF42BFBA);
    const textStyle = TextStyle(
      fontSize: 11.5,
      color: Color(0xFF98A5B8),
      fontWeight: FontWeight.w600,
    );

    final yLabels = [
      maxValue,
      maxValue * 0.75,
      maxValue * 0.50,
      maxValue * 0.25,
      0.0,
    ];

    for (var i = 0; i < yLabels.length; i++) {
      final y = topPadding + (chartHeight * i / (yLabels.length - 1));
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final painter = TextPainter(
        text: TextSpan(text: yLabels[i].toStringAsFixed(0), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(leftPadding - painter.width - 8, y - 7));
    }

    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(size.width, topPadding + chartHeight),
      axisPaint,
    );

    if (points.isEmpty) {
      return;
    }

    final slotWidth = chartWidth / points.length;
    final barWidth = math.min(14.0, slotWidth * 0.35);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = leftPadding + (slotWidth * i) + ((slotWidth - barWidth) / 2);
      final barHeight = maxValue <= 0
          ? 0.0
          : (point.value / maxValue) * chartHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          topPadding + chartHeight - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, barPaint);

      final labelPainter = TextPainter(
        text: TextSpan(text: point.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth + 10);
      labelPainter.paint(
        canvas,
        Offset(
          leftPadding +
              (slotWidth * i) +
              ((slotWidth - labelPainter.width) / 2),
          size.height - bottomPadding + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SalesBarChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxValue != maxValue;
  }
}

class _LowStockTableHeader extends StatelessWidget {
  const _LowStockTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 40, child: _HeaderText('Product')),
          Expanded(flex: 22, child: _HeaderText('Current Stock')),
          Expanded(flex: 28, child: _HeaderText('Minimum Required')),
          Expanded(flex: 18, child: _HeaderText('Status')),
        ],
      ),
    );
  }
}

class _LowStockTableRow extends StatelessWidget {
  const _LowStockTableRow({required this.row});

  final ReportLowStockRow row;

  @override
  Widget build(BuildContext context) {
    final isCritical = row.status == 'Critical';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 40,
            child: Text(
              row.product,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 22,
            child: Text(
              '${row.currentStock}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isCritical
                    ? const Color(0xFFD88F21)
                    : const Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              '${row.minimumRequired}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  row.status,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE45A5A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockValuationTableHeader extends StatelessWidget {
  const _StockValuationTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 38, child: _HeaderText('Category')),
          Expanded(flex: 22, child: _HeaderText('Total Items')),
          Expanded(flex: 24, child: _HeaderText('Total Value')),
        ],
      ),
    );
  }
}

class _StockValuationTableRow extends StatelessWidget {
  const _StockValuationTableRow({required this.row});

  final ReportStockValuationRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 38,
            child: Text(
              row.category,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 22,
            child: Text(
              '${row.totalItems}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              'Rs ${row.totalValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF42BFBA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCustomersTableHeader extends StatelessWidget {
  const _TopCustomersTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 14, child: _HeaderText('Rank')),
          Expanded(flex: 36, child: _HeaderText('Customer')),
          Expanded(flex: 18, child: _HeaderText('Orders')),
          Expanded(flex: 24, child: _HeaderText('Total Spent')),
          Expanded(flex: 22, child: _HeaderText('Avg. Order')),
        ],
      ),
    );
  }
}

class _TopCustomersTableRow extends StatelessWidget {
  const _TopCustomersTableRow({required this.row});

  final ReportTopCustomerRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 14,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFF4E6FA),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${row.rank}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF9B28BE),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 36,
            child: Text(
              row.customer,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              '${row.orders}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              'Rs ${row.totalSpent.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB335CF),
              ),
            ),
          ),
          Expanded(
            flex: 22,
            child: Text(
              'Rs ${row.averageOrder.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8D9AB0),
      ),
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;
}
