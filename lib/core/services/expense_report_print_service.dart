import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/dashboard/models/models.dart';
import '../../features/settings/services/app_settings_service.dart';
import '../../features/setup/services/setup_service.dart';

class ExpenseReportPrintService {
  ExpenseReportPrintService._();

  static Future<void> printReport({
    required ShopInfo shopInfo,
    required ReportHeaderSettings headerSettings,
    required ExpenseReportData report,
  }) async {
    final bytes = await _buildPdf(
      shopInfo: shopInfo,
      headerSettings: headerSettings,
      report: report,
    );
    await Printing.layoutPdf(
      name:
          'expense_report_${_formatDate(report.fromDate)}_${_formatDate(report.toDate)}',
      onLayout: (_) async => bytes,
    );
  }

  static Future<String?> exportReport({
    required ShopInfo shopInfo,
    required ReportHeaderSettings headerSettings,
    required ExpenseReportData report,
  }) async {
    final bytes = await _buildPdf(
      shopInfo: shopInfo,
      headerSettings: headerSettings,
      report: report,
    );
    final targetPath = await FilePicker.saveFile(
      dialogTitle: 'Export Expense Report',
      fileName:
          'expense_report_${_formatDate(report.fromDate)}_${_formatDate(report.toDate)}.pdf',
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
    required ExpenseReportData report,
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
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F3FAFC'),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Period: ${_formatDate(report.fromDate)} to ${_formatDate(report.toDate)}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Total: Rs ${report.totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          _buildExpenseTable(report.expenses),
        ],
      ),
    );
    return document.save();
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
        : 'Expense Report';
    final subtitle = headerSettings.subtitle.trim().isNotEmpty
        ? headerSettings.subtitle.trim()
        : 'Expenses report';

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

  static pw.Widget _buildExpenseTable(List<ExpenseRecord> expenses) {
    if (expenses.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(24),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Center(
          child: pw.Text(
            'No expenses found for the selected range.',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ),
      );
    }

    return pw.TableHelper.fromTextArray(
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
      headers: const ['Date', 'Title', 'Category', 'Method', 'Notes', 'Amount'],
      data: expenses
          .map(
            (expense) => [
              _formatDate(expense.date),
              expense.title,
              expense.category,
              expense.paymentMethod,
              expense.notes.isEmpty ? '-' : expense.notes,
              'Rs ${expense.amount.toStringAsFixed(2)}',
            ],
          )
          .toList(),
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
