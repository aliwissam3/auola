import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/people.dart';
import '../models/sales.dart';
import 'pdf_arabic.dart';

/// Builds and opens the OS/browser print dialog for a thermal-receipt-
/// style PDF of a completed sale — item lines, total, payment type, and
/// a QR code encoding the invoice id (for the "استبدال" lookup flow).
Future<void> printReceipt(SaleInvoice invoice, {Customer? customer}) async {
  final doc = pw.Document(theme: await arabicPdfTheme());
  final width = 80 * PdfPageFormat.mm;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(width, double.infinity, marginAll: 4 * PdfPageFormat.mm),
      textDirection: pw.TextDirection.rtl,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text('صيدليتي', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${invoice.createdAt.year}/${invoice.createdAt.month}/${invoice.createdAt.day} '
            '${invoice.createdAt.hour.toString().padLeft(2, '0')}:${invoice.createdAt.minute.toString().padLeft(2, '0')}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (customer != null) pw.Text('الزبون: ${customer.name}', style: const pw.TextStyle(fontSize: 9)),
          pw.Divider(),
          ...invoice.items.map(
            (it) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text('${it.name} ×${it.quantity.toStringAsFixed(0)}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Text(it.lineTotal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('الإجمالي', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('${invoice.total.toStringAsFixed(0)} د.ع',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Text('طريقة الدفع: ${invoice.paymentType.labelAr}', style: const pw.TextStyle(fontSize: 9)),
          if (invoice.paymentType == PaymentType.credit)
            pw.Text('المدفوع الآن: ${invoice.paidAmount.toStringAsFixed(0)} د.ع',
                style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: invoice.id,
              width: 70,
              height: 70,
            ),
          ),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}
