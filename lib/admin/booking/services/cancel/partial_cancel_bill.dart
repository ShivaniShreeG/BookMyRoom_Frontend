import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../public/main_navigation.dart';

const Color royal = Color(0xFF19527A);

class PartialCancelBillPage extends StatelessWidget {
  final Map<String, dynamic> bookingDetails;
  final Map<String, dynamic>? serverData;

  const PartialCancelBillPage({
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
        title: const Text("Cancel Bill", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MainNavigation(initialIndex: 0),
                ),
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
                        bytes: pdfData,
                        filename: "partial_cancel_bill.pdf",
                      );
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
      Map<String, dynamic> booking,
      Map<String, dynamic>? server,
      ) async {
    final pdf = pw.Document();

    final font = pw.Font.ttf(
        await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"));
    final fontBold = pw.Font.ttf(
        await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"));

    final royalColor = PdfColor.fromInt(0xFF19527A);
    final greyBox = PdfColor.fromInt(0xFFEFEFEF);

    print("Booking: $booking");
    print("Serverdata: $server");

    // ======= Extract Correct Data =======

    // Updated booking info from server
    final updatedBooking = server?['booking'] ?? booking;

    // Remaining rooms after partial cancel
    final rooms = (updatedBooking['room_number'] as List).join(', ');

    // Cancellation record
    final cancel = server?['cancel'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),

        build: (context) => [

          pw.Center(
            child: pw.Text(
              "Partial Cancellation Invoice",
              style: pw.TextStyle(
                color: royalColor,
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Divider(thickness: 2, color: royalColor),
          pw.SizedBox(height: 10),

          // =====================================================
          // Booking Details
          // =====================================================

          pw.Text("Booking Details",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),

          _row("Booking ID", updatedBooking['booking_id'].toString(), greyBox),
          _row("Name", updatedBooking['name'], greyBox),
          _row("Phone", updatedBooking['phone'], greyBox),
          _row("Room Numbers", rooms, greyBox),
          _row("Room Type", updatedBooking['room_type'], greyBox),
          _row("Base Amount", "₹${updatedBooking['baseamount']}", greyBox),
          _row("GST", "₹${updatedBooking['gst']}", greyBox),
          _row("Total Amount", "₹${updatedBooking['amount']}", greyBox),
          _row("Advance Paid", "₹${updatedBooking['advance']}", greyBox),
          _row("Balance", "₹${updatedBooking['Balance']}", greyBox),

          pw.SizedBox(height: 20),

          // =====================================================
          // Cancellation Details
          // =====================================================

          pw.Text("Cancellation Details",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),

          _row("Cancelled Rooms",
              cancel?['room_number']?.join(", ") ?? "-", greyBox),

          _row("Reason", cancel?['reason'] ?? "-", greyBox),

          _row("Amount Paid", "₹${cancel?['amount_paid'] ?? 0}", greyBox),

          _row("Cancellation Charge",
              "₹${cancel?['cancel_charge'] ?? 0}", greyBox),

          _row("Refund Amount", "₹${cancel?['refund'] ?? 0}", greyBox),

          _row("Cancelled At",
              cancel?['created_at']?.toString() ?? "-", greyBox),
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
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
