import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../public/config.dart';
import 'package:http/http.dart' as http;
import '../../../public/main_navigation.dart';

class UpdateBookingPdfPage extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic> hallDetails;
  final Map<String, dynamic> billingData; // only billingData
  final Map<String, dynamic> rawbilldata; // only billingData

  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;

  const UpdateBookingPdfPage({
    super.key,
    required this.bookingData,
    required this.hallDetails,
    required this.billingData,
    required this.rawbilldata,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });
  Future<Map<String, dynamic>?> fetchAdminDetails(int hallId, int userId) async {
    try {
      final url = Uri.parse('$baseUrl/details/$hallId/admins/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint("Admin Details: $data"); // ✅ print in console
        return data;
      } else {
        debugPrint("Failed to fetch admin details. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching admin details: $e");
    }
    return null;
  }
  @override
  Widget build(BuildContext context) {
    final pdfFuture = _generatePdf();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Billing PDF",
          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: secondaryColor),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: secondaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
      ),
      backgroundColor: backgroundColor,
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
              allowPrinting: false,
              allowSharing: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
            );
          }
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.print),
                label: const Text("Print"),
                onPressed: () {
                  pdfFuture.then((pdfData) {
                    Printing.layoutPdf(onLayout: (format) async => pdfData);
                  });
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.share),
                label: const Text("Share"),
                onPressed: () {
                  pdfFuture.then((pdfData) {
                    Printing.sharePdf(bytes: pdfData, filename: "booking.pdf");
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdf() async {
    final ttf = await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf");
    final ttfBold = await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf");
    final font = pw.Font.ttf(ttf);
    final fontBold = pw.Font.ttf(ttfBold);

    final pdf = pw.Document();

    final darkBlue = PdfColor.fromInt(0xFF556B2F);
    final lightBlue = PdfColor.fromInt(0xFFF5F5DC);
    debugPrint("===== BOOKING DATA =====");
    debugPrint(jsonEncode(bookingData));
    debugPrint("===== HALL DETAILS =====");
    debugPrint(jsonEncode(hallDetails));
    debugPrint("===== BILL DETAILS =====");
    debugPrint(jsonEncode(billingData));

    debugPrint(jsonEncode(rawbilldata));

    Map<String, dynamic>? firstBilling;
    int? userId;
    int? hallId;
    Map<String, dynamic>? adminDetails;

    final billingsList = rawbilldata['billings'];

    if (billingsList is List && billingsList.isNotEmpty) {
      // ✅ Get from billing data if available
      firstBilling = billingsList[0] as Map<String, dynamic>;
      userId = firstBilling['user_id'] as int?;
      hallId = firstBilling['hall_id'] as int?;
      debugPrint("Using hallId/userId from billing data");
    } else {
      // ✅ Fallback: take from bookingData
      debugPrint("⚠️ No billing data found, taking hallId and userId from bookingData");
      userId = bookingData['user_id'] as int?;
      hallId = bookingData['hall_id'] as int?;
    }

    if (hallId != null && userId != null) {
      adminDetails = await fetchAdminDetails(hallId, userId);
      // debugPrint("Booking User Admin Details: $adminDetails");
      // debugPrint("User ID: $userId");
      // debugPrint("Hall ID: $hallId");
    } else {
      debugPrint("⚠️ Missing hallId or userId (even after fallback)");
    }



    // Logo
    Uint8List? hallLogo;
    if (hallDetails['logo'] != null && hallDetails['logo'].isNotEmpty) {
      try {
        hallLogo = base64Decode(hallDetails['logo']);
      } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              // Logo section (optional)
              if (hallLogo != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 16), // space between logo and text
                  child: pw.Image(
                    pw.MemoryImage(hallLogo),
                    width: 70,
                    height: 70,
                  ),
                ),

              // Text section (centered in remaining space)
              pw.Expanded(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      (hallDetails['name']?.toString() ?? 'HALL NAME').toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: darkBlue,
                        font: fontBold,
                      ),
                    ),
                    if ((hallDetails['address'] ?? '').toString().isNotEmpty)
                      pw.Text(
                        hallDetails['address'].toString(),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: font),
                      ),
                    if ((hallDetails['phone'] ?? '').toString().isNotEmpty)
                      pw.Text(
                        'Phone: ${hallDetails['phone']}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: font),
                      ),
                    if ((hallDetails['email'] ?? '').toString().isNotEmpty)
                      pw.Text(
                        'Email: ${hallDetails['email']}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: font),
                      ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 7),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Bill no: ${hallDetails['hall_id'] ?? ''}${bookingData['booking_id'] ?? ''}',
                style: pw.TextStyle(font: fontBold, color: darkBlue),
              ),

              pw.Text(
                  'Generated: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(font: font)),
            ],
          ),
          pw.Divider(thickness: 1.2),
          pw.SizedBox(height: 10),
          _sectionHeader('BOOKING INFORMATION', darkBlue, fontBold),
          _infoTable([
            if ((bookingData['name'] ?? '').toString().isNotEmpty) ['NAME', bookingData['name']],
            if ((bookingData['phone'] ?? '').toString().isNotEmpty) ['PHONE', bookingData['phone']],
            if ((bookingData['email'] ?? '').toString().isNotEmpty)
              ["EMAIL", bookingData['email']],
            if ((bookingData['address'] ?? '').toString().isNotEmpty) ['ADDRESS', bookingData['address']],
            if (bookingData['alternate_phone'] != null &&
                (bookingData['alternate_phone'] as List).isNotEmpty)
              [
                "ALTERNATE PHONE",
                (bookingData['alternate_phone'] as List).join(", ")
              ],
            if ((bookingData['event_type'] ?? '').toString().isNotEmpty) ['EVENT', bookingData['event_type']],
            if ((bookingData['function_date'] ?? '').toString().isNotEmpty)
              ['FUNCTION DATE', DateFormat('dd-MM-yyyy').format(DateTime.parse(bookingData['function_date']).toLocal())],
            if ((bookingData['tamil_date'] ?? '').toString().isNotEmpty ||
                (bookingData['tamil_month'] ?? '').toString().isNotEmpty)
              [
                'TAMIL DATE & MONTH',
                '${bookingData['tamil_date'] ?? ''}, ${bookingData['tamil_month'] ?? ''}',
              ],
            if ((bookingData['alloted_datetime_from'] ?? '').toString().isNotEmpty &&
                (bookingData['alloted_datetime_to'] ?? '').toString().isNotEmpty)
              [
                'ALLOTED TIME',
                bookingData['alloted_datetime_from'], // just use the string
                bookingData['alloted_datetime_to'],   // just use the string
              ],

          ], lightBlue, font),
          pw.SizedBox(height: 2),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left Column - Payment Information
              pw.Container(
                width: PdfPageFormat.a4.availableWidth * 0.80, // 48% of page
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Container(
                      width: double.infinity,
                      color: darkBlue,
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(
                        "PAYMENT INFORMATION",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          font: fontBold,
                          fontSize: 9
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6), // space after header

                    // Rows
                    ...[
                      if (bookingData['rent'] != null) "RENT",
                      if (bookingData['advance'] != null) "ADVANCE",
                      if (bookingData['balance'] != null) "BALANCE",
                    ].map((label) {
                      final isBalance = label == "BALANCE";
                      return pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        margin: const pw.EdgeInsets.only(bottom: 2), // space between rows
                        child: pw.Text(
                          label,
                          style: pw.TextStyle(
                            font: isBalance ? fontBold : font,
                            fontWeight: isBalance ? pw.FontWeight.bold : pw.FontWeight.normal,
                            fontSize: 9
                          ),
                        ),
                      );
                    }).toList(),

                  ],
                ),
              ),

              pw.SizedBox(width: PdfPageFormat.a4.availableWidth * 0.02), // 4% gap

              // Right Column - Amounts
              // Right Column - Amounts
              pw.Container(
                width: PdfPageFormat.a4.availableWidth * 0.25,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Header
                    pw.Container(
                      width: double.infinity,
                      color: darkBlue,
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(
                        "AMOUNT",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          font: fontBold,
                          fontSize: 9
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6), // space after header

                    // Rows
                    ...[
                      if (bookingData['rent'] != null) "Rs.${bookingData['rent']}",
                      if (bookingData['advance'] != null) "Rs.${bookingData['advance']}",
                      if (bookingData['balance'] != null) "Rs.${bookingData['balance']}",
                    ].map((amount) {
                      // Only balance should be bold
                      final isBalance = amount == "Rs.${bookingData['balance']}";
                      return pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        margin: const pw.EdgeInsets.only(bottom: 2), // space between rows
                        child: pw.Text(
                          amount,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            font: isBalance ? fontBold : font, // RENT & ADVANCE normal
                            fontWeight: isBalance ? pw.FontWeight.bold : pw.FontWeight.normal,
                            fontSize: 9
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

            ],
          ),
          // Add this inside your _generatePdf() where you want the billing section
          // pw.NewPage(),
          pw.SizedBox(height: 2),
          if (billingData['charges'] != null &&
              billingData['charges'] is List &&
              billingData['charges'].isNotEmpty)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left Column - Billing Labels
                // Left Column - Billing Labels
                pw.Container(
                  width: PdfPageFormat.a4.availableWidth * 0.80,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: double.infinity,
                        color: darkBlue,
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          "BILLING INFORMATION",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              font: fontBold,
                              fontSize: 9
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      // pw.Container(
                      //   width: double.infinity,
                      //   color: lightBlue,
                      //   padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      //   margin: const pw.EdgeInsets.only(bottom: 6),
                      //   child: pw.Text(
                      //     "BALANCE",
                      //     style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                      //   ),
                      // ),
                      // Charges Labels
                      ...billingData['charges'].reversed.map<pw.Widget>((c) {
                        final reason = c['reason'] ?? '';
                        return pw.Container(
                          width: double.infinity,
                          color: lightBlue,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          margin: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Text(
                            reason.toUpperCase(),
                            style: pw.TextStyle(font: font,fontSize: 9),
                          ),
                        );
                      }).toList(),
                      // Balance

                      // Grand Total
                      pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        margin: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(
                          "TOTAL AMOUNT PAID",
                          style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold,fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: PdfPageFormat.a4.availableWidth * 0.02),
                // Right Column - Billing Amounts
                // Right Column - Billing Amounts
                pw.Container(
                  width: PdfPageFormat.a4.availableWidth * 0.25,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: double.infinity,
                        color: darkBlue,
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          "AMOUNT",
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              font: fontBold,
                              fontSize: 9
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      // Balance
                      // pw.Container(
                      //   width: double.infinity,
                      //   color: lightBlue,
                      //   padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      //   margin: const pw.EdgeInsets.only(bottom: 6),
                      //   child: pw.Text(
                      //     "Rs.${billingData['balance'].toStringAsFixed(2)}",
                      //     textAlign: pw.TextAlign.right,
                      //     style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                      //   ),
                      // ),
                      ...billingData['charges'].reversed.map<pw.Widget>((c) {
                        final amount = c['amount'] ?? 0.0;
                        return pw.Container(
                          width: double.infinity,
                          color: lightBlue,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          margin: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Text(
                            "Rs.${amount.toStringAsFixed(2)}",
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(font: font,fontSize: 9),
                          ),
                        );
                      }).toList(),

                      // Grand Total
                      pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        margin: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(
                          "Rs.${billingData['grandTotal'].toStringAsFixed(2)}",
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold,fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),


          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              "Billing completed successfully.\n Kindly verify the details and retain this receipt for reference.",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: darkBlue,
                font: fontBold,
                fontSize: 9
              ),
            ),
          ),
          pw.SizedBox(height: 35),
          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  // Admin name above the line
                  pw.Text(
                    adminDetails?['name'] ?? 'Manager',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  // Signature line
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text(
                    "Manager",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  // Booking person name (from bookingData) above the line

                  // Signature line
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text(
                    "Booking Person",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _sectionHeader(String title, PdfColor color, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      color: color,
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: pw.Text(title,
          style: pw.TextStyle(
              color: PdfColors.white, fontWeight: pw.FontWeight.bold, font: font,fontSize: 9)),
    );
  }

  pw.Widget _infoTable(List<List<String?>> data, PdfColor shade, pw.Font font) {
    return pw.Center(
      child: pw.Table(
        columnWidths: {
          0: const pw.FixedColumnWidth(100), // first column width
          1: const pw.FixedColumnWidth(300), // second column width (adjust as needed)
        },
        // defaultColumnWidth: const pw.FlexColumnWidth(),
        border: pw.TableBorder.all(color: PdfColors.white), // no visible border

        children: data.map((row) {
          if (row.length == 3) {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Container(
                    color: PdfColors.white,
                    child: pw.Text(row[0] ?? "",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, font: font,fontSize: 9)),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        color: shade,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: pw.Text(row[1] ?? "", style: pw.TextStyle(font: font,fontSize: 9)),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text("to", style: pw.TextStyle(font: font,fontSize: 9)),
                      // pw.Text(
                      //   row[0] == "TAMIL DATE" ? "MONTH" : "TO",
                      //   style: pw.TextStyle(
                      //     font: font, // ✅ white label
                      //     fontWeight: pw.FontWeight.bold,
                      //   ),
                      // ),
                      pw.SizedBox(width: 4),
                      pw.Container(
                        color: shade,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: pw.Text(row[2] ?? "", style: pw.TextStyle(font: font,fontSize: 9)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Container(
                    color: PdfColors.white,
                    child: pw.Text(row[0] ?? "",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font,fontSize: 9)),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Container(
                    color: shade,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: pw.Text(row[1] ?? "", style: pw.TextStyle(font: font,fontSize: 9)),
                  ),
                ),
              ],
            );
          }
        }).toList(),
      ),
    );
  }
}
