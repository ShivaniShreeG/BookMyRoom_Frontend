import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../public/main_navigation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

const Color royal = Color(0xFF19527A);

class BillPage extends StatelessWidget {
  final Map<String, dynamic> bookingDetails;

  const BillPage({super.key, required this.bookingDetails});

  @override
  Widget build(BuildContext context) {
    final pdfFuture = _generatePdf(bookingDetails);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Pre-Booking Bill", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
      ),

      body: FutureBuilder<Uint8List>(
        future: pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error generating PDF: ${snapshot.error}"));
          } else {
            final pdfData = snapshot.data!;
            return PdfPreview(
              build: (format) => pdfData,
              allowPrinting: false, // Use your buttons for printing/sharing
              allowSharing: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
            );
          }
        },
      ),

      bottomNavigationBar: FutureBuilder<Uint8List>(
        future: pdfFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final pdfData = snapshot.data!;
          final phoneNumber = bookingDetails['phone'] ?? "";

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
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text("Print"),
                    onPressed: () {
                      Printing.layoutPdf(onLayout: (format) async => pdfData);
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.share),
                    label: const Text("Share"),
                    onPressed: () {
                      Printing.sharePdf(bytes: pdfData, filename: "booking_invoice.pdf");
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.send),
                    label: const Text("WhatsApp"),
                    onPressed: () async {
                      try {
                        // Save PDF to temporary directory
                        final tempDir = await getTemporaryDirectory();
                        final file = File('${tempDir.path}/booking_invoice.pdf');
                        await file.writeAsBytes(pdfData); // pdfData comes from FutureBuilder

                        // Share via WhatsApp
                        await Share.shareXFiles(
                          [XFile(file.path)],
                          text: "Please find your booking invoice attached.",
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Cannot share PDF: $e")),
                        );
                      }
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

  Future<Uint8List> _generatePdf(Map<String, dynamic> bookingDetails) async {
    final pdf = pw.Document();

    // Load custom fonts from assets
    final ttf = await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf");
    final ttfBold = await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf");
    final font = pw.Font.ttf(ttf);
    final fontBold = pw.Font.ttf(ttfBold);

    final royalColor = PdfColor.fromInt(0xFF19527A);
    final lightGrey = PdfColor.fromInt(0xFFEFEFEF);

    final rooms = (bookingDetails['room_number'] as List).join(', ');
    final numDays = bookingDetails['specification']['number_of_days'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          // Header
          pw.Center(
            child: pw.Text("Booking Invoice",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: royalColor,
                  font: fontBold,
                )),
          ),
          pw.Divider(thickness: 2, color: royalColor),
          pw.SizedBox(height: 10),

          ...[
            ["Name", bookingDetails['name']],
            ["Phone", bookingDetails['phone']],
            ["Email", bookingDetails['email'] ?? "-"],
            ["Address", bookingDetails['address'] ?? "-"],
            ["Lodge ID", bookingDetails['lodge_id'].toString()],
            ["Room Type", bookingDetails['room_type']],
            ["Room Name", bookingDetails['room_name']],
            ["Room Numbers", rooms],
            ["Number of Days", numDays.toString()],
            ["Base Amount", "₹${bookingDetails['baseamount']}"],
            ["GST", "₹${bookingDetails['gst']}"],
            ["Total", "₹${bookingDetails['amount']}"],
            ["Advance Paid", "₹${bookingDetails['advance']}"],
            ["Balance", "₹${bookingDetails['balance']}"],
          ].map((row) => pw.Container(
            color: lightGrey,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            margin: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              children: [
                pw.Expanded(child: pw.Text(row[0]!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font))),
                pw.Expanded(child: pw.Text(row[1]!, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font))),
              ],
            ),
          )),
        ],
      ),
    );

    return pdf.save();
  }
}
