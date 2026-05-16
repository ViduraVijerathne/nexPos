import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/dashboard/services/day_session_service.dart';
import '../../features/setup/services/setup_service.dart';

class DaySessionPrintService {
  DaySessionPrintService._();

  static Future<void> printSummary({
    required ShopInfo shopInfo,
    required DrawerSessionSummary summary,
    required double actualCashInHand,
  }) async {
    final document = pw.Document();
    final variance = actualCashInHand - summary.expectedDrawerAmount;

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        margin: const pw.EdgeInsets.all(14),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                shopInfo.shopName.trim().isEmpty
                    ? 'NexPos'
                    : shopInfo.shopName.trim(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Day End Summary',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              _row(
                'Cashier',
                summary.session.cashierName.trim().isEmpty
                    ? 'Admin User'
                    : summary.session.cashierName,
              ),
              _row(
                'Started',
                summary.session.startedAt?.toIso8601String() ?? '-',
              ),
              _row('Invoices', '${summary.invoiceCount}'),
              pw.SizedBox(height: 6),
              pw.Divider(),
              _row(
                'Opening Cash',
                'Rs ${summary.session.openingCash.toStringAsFixed(2)}',
              ),
              _row('Cash Sales', 'Rs ${summary.cashSales.toStringAsFixed(2)}'),
              _row('Card Sales', 'Rs ${summary.cardSales.toStringAsFixed(2)}'),
              _row(
                'Drawer Expenses',
                'Rs ${summary.drawerExpenseTotal.toStringAsFixed(2)}',
              ),
              _row(
                'Total Sales',
                'Rs ${summary.totalSales.toStringAsFixed(2)}',
              ),
              _row(
                'Expected Drawer',
                'Rs ${summary.expectedDrawerAmount.toStringAsFixed(2)}',
                emphasize: true,
              ),
              _row(
                'Cash In Hand',
                'Rs ${actualCashInHand.toStringAsFixed(2)}',
                emphasize: true,
              ),
              _row(
                variance >= 0 ? 'Over' : 'Short',
                'Rs ${variance.abs().toStringAsFixed(2)}',
                emphasize: true,
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Printed from NexPos',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'day_end_summary',
      onLayout: (_) async => document.save(),
    );
  }

  static pw.Widget _row(String label, String value, {bool emphasize = false}) {
    final style = pw.TextStyle(
      fontSize: emphasize ? 11 : 10,
      fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
