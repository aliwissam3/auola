import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/people.dart';
import '../services/pdf_arabic.dart';
import '../utils/web_deep_link.dart';

/// Shows an employee's quick-login code as a real scannable QR code —
/// on Web this encodes a link that opens the app and logs the employee
/// straight in when scanned with an ordinary phone camera (not just an
/// in-app scanner); elsewhere it falls back to the plain code, which
/// still works with a physical barcode scanner or manual entry. Also
/// offers a button to generate a printable ID card (PDF).
Future<void> showEmployeeBarcodeDialog(BuildContext context, Employee employee) async {
  final code = employee.barcode;
  if (code == null || code.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لا يوجد كود دخول لهذا الموظف بعد — أضِف واحداً من التعديل')),
    );
    return;
  }
  final link = buildLoginLink(code, employeeId: employee.id);

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('بطاقة الموظف — ${employee.name}'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: bw.BarcodeWidget(
                barcode: bw.Barcode.qrCode(),
                data: link,
                width: 220,
                height: 220,
              ),
            ),
            const SizedBox(height: 12),
            Text('الكود: $code', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (link != code) ...[
              const SizedBox(height: 4),
              const Text(
                'مسح هذا الكود بكاميرا الموبايل العادية يفتح المتصفح ويسجل الدخول تلقائياً',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ElevatedButton.icon(
          onPressed: () => printEmployeeCard(employee, code),
          icon: const Icon(Icons.print_outlined),
          label: const Text('طباعة'),
        ),
      ],
    ),
  );
}

/// Builds a small printable ID card (name + phone + QR code) and opens
/// the OS/browser print dialog. Shared by the single-employee dialog
/// above and the all-employees "أكواد الكاشير" screen.
Future<void> printEmployeeCard(Employee employee, String code) async {
  final doc = pw.Document(theme: await arabicPdfTheme());
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6,
      textDirection: pw.TextDirection.rtl,
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('صيدليتي', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(employee.name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            if (employee.phone.isNotEmpty) pw.Text(employee.phone, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: buildLoginLink(code, employeeId: employee.id),
              width: 160,
              height: 160,
            ),
          ],
        ),
      ),
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}
