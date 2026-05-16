import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/dashboard/models/models.dart';
import '../../features/settings/services/app_settings_service.dart';
import '../../features/setup/services/setup_service.dart';

enum ReportExportSection {
  sales('sales_report', 'Sales Report'),
  tax('tax_collector_report', 'Tax Collector Report'),
  inventory('inventory_report', 'Inventory Report'),
  customers('customer_report', 'Customer Report'),
  expenses('expenses_report', 'Expenses Report'),
  all('all_reports', 'All Reports');

  const ReportExportSection(this.filePrefix, this.title);

  final String filePrefix;
  final String title;
}

class ReportPrintService {
  ReportPrintService._();

  static Future<void> printReport({
    required ShopInfo shopInfo,
    required ReportHeaderSettings headerSettings,
    required ReportDashboardData report,
    required ReportExportSection section,
  }) async {
    final bytes = await _buildPdf(
      shopInfo: shopInfo,
      headerSettings: headerSettings,
      report: report,
      section: section,
    );
    await Printing.layoutPdf(
      name:
          '${section.filePrefix}_${_formatDate(report.fromDate)}_${_formatDate(report.toDate)}',
      onLayout: (_) async => bytes,
    );
  }

  static Future<String?> exportReport({
    required ShopInfo shopInfo,
    required ReportHeaderSettings headerSettings,
    required ReportDashboardData report,
    required ReportExportSection section,
  }) async {
    final bytes = await _buildPdf(
      shopInfo: shopInfo,
      headerSettings: headerSettings,
      report: report,
      section: section,
    );
    final targetPath = await FilePicker.saveFile(
      dialogTitle: 'Export ${section.title}',
      fileName:
          '${section.filePrefix}_${_formatDate(report.fromDate)}_${_formatDate(report.toDate)}.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (targetPath == null || targetPath.trim().isEmpty) {
      return null;
    }
    final file = File(targetPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<Uint8List> _buildPdf({
    required ShopInfo shopInfo,
    required ReportHeaderSettings headerSettings,
    required ReportDashboardData report,
    required ReportExportSection section,
  }) async {
    final document = pw.Document();
    final logoBytes = await _loadLogo(shopInfo.logoPath);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _buildHeader(
            shopInfo: shopInfo,
            headerSettings: headerSettings,
            logoBytes: logoBytes,
          ),
          pw.SizedBox(height: 12),
          _buildMeta(section: section, report: report),
          pw.SizedBox(height: 16),
          ..._buildSection(section: section, report: report),
        ],
      ),
    );

    return document.save();
  }

  static List<pw.Widget> _buildSection({
    required ReportExportSection section,
    required ReportDashboardData report,
  }) {
    switch (section) {
      case ReportExportSection.sales:
        return _buildSalesSection(report);
      case ReportExportSection.tax:
        return _buildTaxSection(report);
      case ReportExportSection.inventory:
        return _buildInventorySection(report);
      case ReportExportSection.customers:
        return _buildCustomerSection(report);
      case ReportExportSection.expenses:
        return _buildExpensesSection(report);
      case ReportExportSection.all:
        return [
          ..._buildSalesSection(report),
          pw.SizedBox(height: 16),
          ..._buildTaxSection(report),
          pw.SizedBox(height: 16),
          ..._buildInventorySection(report),
          pw.SizedBox(height: 16),
          ..._buildCustomerSection(report),
          pw.SizedBox(height: 16),
          ..._buildExpensesSection(report),
        ];
    }
  }

  static List<pw.Widget> _buildSalesSection(ReportDashboardData report) {
    return [
      _sectionTitle('Sales Report'),
      _summaryBox(<String, String>{
        'Total Revenue': 'Rs ${report.summary.totalRevenue.toStringAsFixed(2)}',
        'Orders': '${report.summary.totalOrders}',
        'Period': report.salesPeriod.label,
      }),
      pw.SizedBox(height: 12),
      _table(
        headers: const ['Time', 'Sales Amount'],
        rows: report.salesPoints
            .map(
              (point) => [point.label, 'Rs ${point.value.toStringAsFixed(2)}'],
            )
            .toList(),
      ),
      pw.SizedBox(height: 12),
      _table(
        headers: const ['Product', 'Qty', 'Sales'],
        rows: report.productSales
            .map(
              (row) => [
                row.product,
                '${row.quantity}',
                'Rs ${row.totalSales.toStringAsFixed(2)}',
              ],
            )
            .toList(),
      ),
      pw.SizedBox(height: 12),
      _table(
        headers: const ['Category', 'Qty', 'Sales'],
        rows: report.categorySales
            .map(
              (row) => [
                row.category,
                '${row.quantity}',
                'Rs ${row.totalSales.toStringAsFixed(2)}',
              ],
            )
            .toList(),
      ),
    ];
  }

  static List<pw.Widget> _buildTaxSection(ReportDashboardData report) {
    return [
      _sectionTitle('Tax Collector Report'),
      _summaryBox(<String, String>{
        'Tax Collected': 'Rs ${report.summary.totalTax.toStringAsFixed(2)}',
        'Period': report.salesPeriod.label,
      }),
      pw.SizedBox(height: 12),
      _table(
        headers: const ['Time', 'Tax Amount'],
        rows: report.taxPoints
            .map(
              (point) => [point.label, 'Rs ${point.value.toStringAsFixed(2)}'],
            )
            .toList(),
      ),
    ];
  }

  static List<pw.Widget> _buildInventorySection(ReportDashboardData report) {
    return [
      _sectionTitle('Inventory Reports'),
      _table(
        headers: const ['Product', 'Current Stock', 'Min Required', 'Status'],
        rows: report.lowStockRows
            .map(
              (row) => [
                row.product,
                '${row.currentStock}',
                '${row.minimumRequired}',
                row.status,
              ],
            )
            .toList(),
      ),
      pw.SizedBox(height: 12),
      _table(
        headers: const ['Category', 'Total Items', 'Total Value'],
        rows: report.stockValuationRows
            .map(
              (row) => [
                row.category,
                '${row.totalItems}',
                'Rs ${row.totalValue.toStringAsFixed(2)}',
              ],
            )
            .toList(),
      ),
    ];
  }

  static List<pw.Widget> _buildCustomerSection(ReportDashboardData report) {
    return [
      _sectionTitle('Customer Reports'),
      _table(
        headers: const [
          'Rank',
          'Customer',
          'Orders',
          'Total Spent',
          'Avg Order',
        ],
        rows: report.topCustomers
            .map(
              (row) => [
                '${row.rank}',
                row.customer,
                '${row.orders}',
                'Rs ${row.totalSpent.toStringAsFixed(2)}',
                'Rs ${row.averageOrder.toStringAsFixed(2)}',
              ],
            )
            .toList(),
      ),
    ];
  }

  static List<pw.Widget> _buildExpensesSection(ReportDashboardData report) {
    return [
      _sectionTitle('Expenses Report'),
      _summaryBox(<String, String>{
        'Total Expenses': 'Rs ${report.totalExpenseAmount.toStringAsFixed(2)}',
        'Records': '${report.expenses.length}',
      }),
      pw.SizedBox(height: 12),
      _table(
        headers: const ['Date', 'Title', 'Category', 'Method', 'Amount'],
        rows: report.expenses
            .map(
              (expense) => [
                _formatDate(expense.date),
                expense.title,
                expense.category,
                expense.paymentMethod,
                'Rs ${expense.amount.toStringAsFixed(2)}',
              ],
            )
            .toList(),
      ),
    ];
  }

  static pw.Widget _buildHeader({
    required ShopInfo shopInfo,
    required ReportHeaderSettings headerSettings,
    required Uint8List? logoBytes,
  }) {
    final title = headerSettings.title.trim().isNotEmpty
        ? headerSettings.title.trim()
        : shopInfo.shopName.trim().isNotEmpty
        ? shopInfo.shopName.trim()
        : 'Report';
    final subtitle = headerSettings.subtitle.trim().isNotEmpty
        ? headerSettings.subtitle.trim()
        : 'Business report';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (headerSettings.showLogo && logoBytes != null) ...[
          pw.Center(
            child: pw.Image(
              pw.MemoryImage(logoBytes),
              width: 52,
              height: 52,
              fit: pw.BoxFit.cover,
            ),
          ),
          pw.SizedBox(height: 8),
        ],
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            [
              if (shopInfo.address.trim().isNotEmpty) shopInfo.address.trim(),
              if (shopInfo.contactNumber.trim().isNotEmpty)
                shopInfo.contactNumber.trim(),
              if (shopInfo.contactEmail.trim().isNotEmpty)
                shopInfo.contactEmail.trim(),
            ].join(' | '),
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildMeta({
    required ReportExportSection section,
    required ReportDashboardData report,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F3FAFC'),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Report: ${section.title}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Period: ${report.fromDateLabel} to ${report.toDateLabel}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _summaryBox(Map<String, String> items) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        children: items.entries
            .map(
              (entry) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        entry.key,
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Text(
                      entry.value,
                      style: const pw.TextStyle(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Center(
          child: pw.Text(
            'No data found for the selected range.',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF2DAAA5),
      ),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  static Future<Uint8List?> _loadLogo(String path) async {
    if (path.trim().isEmpty) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
