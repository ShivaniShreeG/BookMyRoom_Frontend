import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../../../public/config.dart';
import 'package:printing/printing.dart';
import '../../../../public/main_navigation.dart';

const Color royal = Color(0xFF19527A);

class BillPage extends StatelessWidget {
  final Map<String, dynamic> bookingDetails;
  final Map<String, dynamic>? serverData;

  const BillPage({
    super.key,
    required this.bookingDetails,
    required this.serverData,
  });

  @override
  Widget build(BuildContext context) {
    final pdfFuture = _generatePdf(bookingDetails, serverData);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Bill", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
      ),

      body: FutureBuilder<Uint8List>(
        future: pdfFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return PdfPreview(
            build: (format) => snapshot.data!,
            allowPrinting: false,
            allowSharing: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
          );
        },
      ),

      bottomNavigationBar: FutureBuilder<Uint8List>(
        future: pdfFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final pdfData = snapshot.data!;

          return SafeArea(
            child: Container(
              color: royal,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text("Print"),
                    onPressed: () {
                      Printing.layoutPdf(onLayout: (_) async => pdfData);
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.share),
                    label: const Text("Share"),
                    onPressed: () {
                      Printing.sharePdf(
                          bytes: pdfData, filename: "cancel_bill.pdf");
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

    Future<Uint8List> _generatePdf(
        Map<String, dynamic> bookingDetails,
        Map<String, dynamic>? serverData,
        ) async {
      final pdf = pw.Document();

      final font = pw.Font.ttf(
          await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"));
      final fontBold = pw.Font.ttf(
          await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"));

      final royalColor = PdfColor.fromInt(0xFF19527A);
      final greyBox = PdfColor.fromInt(0xFFEFEFEF);

      final balancePayment =
          (serverData?['balancePayment'] as num?)?.toDouble() ?? 0.0;

      final billStatus = balancePayment == 0
          ? "Paid in Full"
          : balancePayment > 0
          ? "Amount Due"
          : "Refund";

      final billAmount = balancePayment.abs();

      final rooms = (bookingDetails['room_number'] as List).join(', ');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),

          build: (context) => [
            pw.Center(
              child: pw.Text(
                "Booking Invoice",
                style: pw.TextStyle(
                  color: royalColor,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Divider(thickness: 2, color: royalColor),
            pw.SizedBox(height: 10),

            /// Booking Details
            pw.Text("Booking Details",
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),

            _row("Booking ID", bookingDetails['booking_id'].toString(), greyBox),
            _row("Customer Name", bookingDetails['name'] ?? "-", greyBox),
            _row("Phone", bookingDetails['phone'] ?? "-", greyBox),
            _row("Room Numbers", rooms, greyBox),
            _row("Room Type", bookingDetails['room_type'] ?? "-", greyBox),
            _row("Base Amount", "₹${bookingDetails['baseamount']}", greyBox),
            _row("GST", "₹${bookingDetails['gst']}", greyBox),
            _row("Grand Total", "₹${bookingDetails['amount']}", greyBox),
            _row("Advance Paid", "₹${bookingDetails['advance']}", greyBox),

            pw.SizedBox(height: 20),

            /// Payment Section
            pw.Text("Payment Summary",
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),

            _row("Advance", "₹${bookingDetails['advance']}", greyBox),
            _row(billStatus, "₹${billAmount.toStringAsFixed(2)}", greyBox),
          ],
        ),
      );

      return pdf.save();
    }


  pw.Widget _row(String label, String value, PdfColor color) {
    return pw.Container(
      color: color,
      padding: const pw.EdgeInsets.all(6),
      margin: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
