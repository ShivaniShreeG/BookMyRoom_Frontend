import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/config.dart'; // baseUrl must be defined here
import 'package:flutter/services.dart' show rootBundle;
import '../../../public/main_navigation.dart';

class MonthlyReportPage extends StatefulWidget {
  final int month;
  final int year;
  final Map<String, dynamic> hallDetails;

  const MonthlyReportPage({super.key, required this.month, required this.year,required this.hallDetails,
  });

  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _billings = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _filteredData = [];
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _drawing = [];


  final Color oliveGreen = const Color(0xFF5B6547);
  final Color tan = const Color(0xFFD8C9A9);
  final Color beigeBackground = const Color(0xFFECE5D8);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");

    if (hallId != null) {
      await Future.wait([
        _fetchExpenses(hallId),
        _fetchBillings(hallId),
        _fetchBookings(hallId),
        _fetchIncomes(hallId),
        _fetchDrawing(hallId)
      ]);
      _combineData();
    }

    setState(() => isLoading = false);
  }

  Future<void> _fetchIncomes(int hallId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/income/hall/$hallId"));
      if (response.statusCode == 200) {
        _incomes = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("❌ Error fetching incomes: $e");
    }
  }
  Future<void> _fetchDrawing(int hallId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/drawing/hall/$hallId"));
      if (response.statusCode == 200) {
        _drawing = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("❌ Error fetching drawing: $e");
    }
  }
  Future<void> _fetchExpenses(int hallId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/expenses/$hallId"));
      if (response.statusCode == 200) {
        _expenses = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching expenses: $e");
    }
  }

  Future<void> _fetchBillings(int hallId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/billings/$hallId"));
      if (response.statusCode == 200) {
        _billings = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching billings: $e");
    }
  }

  Future<void> _fetchBookings(int hallId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/bookings/all/$hallId"));
      if (response.statusCode == 200) {
        _bookings = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching bookings: $e");
    }
  }


  void _combineData() {
    List<Map<String, dynamic>> combined = [];
    final month = widget.month;
    final year = widget.year;
    combined.addAll(_incomes.where((inc) {
      final date = DateTime.tryParse(inc["created_at"] ?? "");
      return date != null && date.month == month && date.year == year;

    }).map((inc) => {
      "type": "Income",
      "title": inc["reason"] ?? "Income",
      "amount": inc["amount"] ?? 0,
      "date": inc["created_at"],
    }));
    // Income from billings
    combined.addAll(_billings.where((b) {
      final date = DateTime.tryParse(b["updated_at"] ?? "");
      return date != null && date.month == month && date.year == year;
    }).map((b) => {
      "type": "Income",
      "title": "Billing for Booking ID: ${b["booking_id"] ?? "-"}",
      "amount": b["total"] ?? 0,
      "date": b["updated_at"],
    }));

    // Advance from bookings
    combined.addAll(_bookings.where((bk) {
      final date = DateTime.tryParse(bk["created_at"] ?? "");
      return date != null &&
          date.month == month &&
          date.year == year &&
          (double.tryParse(bk["advance"].toString()) ?? 0) > 0;
    }).map((bk) => {
      "type": "Income",
      "title": "Advance for Booking ID: ${bk["booking_id"] ?? "-"}",
      "amount": bk["advance"] ?? 0,
      "date": bk["created_at"],
    }));

    // Expenses
    combined.addAll(_expenses.where((e) {
      final date = DateTime.tryParse(e["created_at"] ?? "");
      return date != null && date.month == month && date.year == year;
    }).map((e) => {
      "type": "Expense",
      "title": e["reason"] ?? "-",
      "amount": e["amount"] ?? 0,
      "date": e["created_at"],
    }));

    // Sort descending by date
    combined.sort((a, b) {
      DateTime da = DateTime.tryParse(a["date"] ?? "") ?? DateTime.now();
      DateTime db = DateTime.tryParse(b["date"] ?? "") ?? DateTime.now();
      return db.compareTo(da);
    });

    _filteredData = combined;
  }

  Map<String, double> _calculateTotals() {
    double totalIncome = 0;
    double totalExpense = 0;

    for (var item in _filteredData) {
      final amount = double.tryParse(item["amount"].toString()) ?? 0;
      if (item["type"] == "Income") {
        totalIncome += amount;
      } else if (item["type"] == "Expense") {
        totalExpense += amount;
      }
    }

    return {"income": totalIncome, "expense": totalExpense};
  }

  @override
  Widget build(BuildContext context) {
    final pdfFuture = _buildMonthlyPdf();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Monthly Report",
          style: TextStyle(color: tan, fontWeight: FontWeight.bold),
        ),
        backgroundColor: oliveGreen,
        iconTheme: IconThemeData(color: tan),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: tan),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
      ),
      backgroundColor: beigeBackground,
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
          color: oliveGreen,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tan,
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
                  backgroundColor: tan,
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

  Future<Uint8List> _buildMonthlyPdf() async {
    final pdf = pw.Document();
    final tamilFont = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"));
    final tamilFontBold = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"));

    final darkGreen = PdfColor.fromInt(0xFF5B6547);
    final beige = PdfColor.fromInt(0xFFECE5D8);

    final totals = _calculateTotals();
    final selectedMonth = DateTime(widget.year, widget.month);
    final monthLabel = DateFormat('MMMM yyyy').format(selectedMonth);
    final hall = widget.hallDetails;
    // final now = DateTime.now();
    // final formattedNow = DateFormat('MMyyHHmm').format(now); // e.g., 23102025-153045
    // final borderSide = pw.BorderSide(color: PdfColors.black, width: 1);
    Uint8List? hallLogo;
    if (hall['logo'] != null) {
      hallLogo = base64Decode(hall['logo']);
    }
// --- Summary Section ---
    final totalIncome = totals["income"] ?? 0;
    final totalExpense = totals["expense"] ?? 0;

// Calculate total drawing for selected month
    // Calculate total Drawing In and Out for selected month
    final drawingFiltered = _drawing.where((d) {
      final date = DateTime.tryParse(d["created_at"] ?? "");
      return date != null &&
          date.month == widget.month &&
          date.year == widget.year;
    });

    final totalDrawingIn = drawingFiltered
        .where((d) => d["type"].toString().toLowerCase() == "in")
        .fold<double>(0, (sum, d) => sum + (double.tryParse(d["amount"].toString()) ?? 0));

    final totalDrawingOut = drawingFiltered
        .where((d) => d["type"].toString().toLowerCase() == "out")
        .fold<double>(0, (sum, d) => sum + (double.tryParse(d["amount"].toString()) ?? 0));

// ✅ New balance formula

    final combinedData = [
      ..._filteredData.map((tx) => {
        "date": tx["date"],
        "particular": tx["title"],
        "income": tx["type"] == "Income" ? tx["amount"] : 0.0,
        "expense": tx["type"] == "Expense" ? tx["amount"] : 0.0,
        "drawingIn": 0.0,
        "drawingOut": 0.0,
      }),
      ..._drawing.map((d) => {
        "date": d["created_at"],
        "particular":
        "${d["reason"] ?? "-"}",
        "income": 0.0,
        "expense": 0.0,
        "drawingIn": d["type"].toString().toLowerCase() == "in" ? d["amount"] : 0.0,
        "drawingOut": d["type"].toString().toLowerCase() == "out" ? d["amount"] : 0.0,
      }),
    ];

// Sort all by date ascending
    combinedData.sort((a, b) {
      final da = DateTime.tryParse(a["date"] ?? "") ?? DateTime(2000);
      final db = DateTime.tryParse(b["date"] ?? "") ?? DateTime(2000);
      return da.compareTo(db);
    });

    // === Calculate Opening (Previous) Balance ===
    final selectedMonthStart = DateTime(widget.year, widget.month, 1);

    double previousIncome = 0;
    double previousExpense = 0;
    double previousDrawingIn = 0;
    double previousDrawingOut = 0;

// ---- Incomes ----
    for (var inc in _incomes) {
      final date = DateTime.tryParse(inc["created_at"] ?? "");
      if (date != null && date.isBefore(selectedMonthStart)) {
        previousIncome += double.tryParse(inc["amount"].toString()) ?? 0;
      }
    }

// ---- Billings ----
    for (var b in _billings) {
      final date = DateTime.tryParse(b["updated_at"] ?? "");
      if (date != null && date.isBefore(selectedMonthStart)) {
        previousIncome += double.tryParse(b["total"].toString()) ?? 0;
      }
    }

// ---- Bookings (Advance) ----
    for (var bk in _bookings) {
      final date = DateTime.tryParse(bk["created_at"] ?? "");
      if (date != null && date.isBefore(selectedMonthStart)) {
        previousIncome += double.tryParse(bk["advance"].toString()) ?? 0;
      }
    }

// ---- Expenses ----
    for (var e in _expenses) {
      final date = DateTime.tryParse(e["created_at"] ?? "");
      if (date != null && date.isBefore(selectedMonthStart)) {
        previousExpense += double.tryParse(e["amount"].toString()) ?? 0;
      }
    }

// ---- Drawings ----
    for (var d in _drawing) {
      final date = DateTime.tryParse(d["created_at"] ?? "");
      if (date != null && date.isBefore(selectedMonthStart)) {
        final amount = double.tryParse(d["amount"].toString()) ?? 0;
        if (d["type"].toString().toLowerCase() == "in") {
          previousDrawingIn += amount;
        } else if (d["type"].toString().toLowerCase() == "out") {
          previousDrawingOut += amount;
        }
      }
    }

// ✅ Opening balance till previous month
    final openingBalance = previousIncome + previousDrawingIn - previousExpense - previousDrawingOut;
    final balance = openingBalance + totalIncome + totalDrawingIn - totalExpense - totalDrawingOut;

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: tamilFont, bold: tamilFontBold),
        build: (context) => [

          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (hallLogo != null)
                pw.Image(pw.MemoryImage(hallLogo), width: 70, height: 70),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      hall['name']?.toString().toUpperCase() ?? 'HALL NAME',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        font: tamilFontBold,
                        color: darkGreen,
                      ),
                    ),
                    if ((hall['address'] ?? '').toString().isNotEmpty)
                      pw.Text(hall['address'], style: pw.TextStyle(font: tamilFont)),
                    if ((hall['phone'] ?? '').toString().isNotEmpty)
                      pw.Text('Phone: ${hall['phone']}', style: pw.TextStyle(font: tamilFont)),
                    if ((hall['email'] ?? '').toString().isNotEmpty)
                      pw.Text('Email: ${hall['email']}', style: pw.TextStyle(font: tamilFont)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.SizedBox(height: 16),

          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text("MONTHLY REPORT - $monthLabel",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkGreen)),
          ),
          pw.SizedBox(height: 20),

          pw.SizedBox(height: 16),

          if (_filteredData.isEmpty)
            pw.Center(child: pw.Text("No transactions for this month.", style: pw.TextStyle(font: tamilFont,fontSize: 9)))
          else
            pw.Table.fromTextArray(
              headers: ["S.No", "Date", "Particular", "Income", "Expense", "Drawing In", "Drawing Out"],
              headerStyle: pw.TextStyle(
                font: tamilFontBold,
                fontSize: 9,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(color: darkGreen),
              cellStyle: pw.TextStyle(
                font: tamilFont,
                fontSize: 9,
                color: PdfColors.black,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              rowDecoration: pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: pw.BoxDecoration(color: beige),

              data: List.generate(combinedData.length, (index) {
                final item = combinedData[index];
                final date = DateTime.tryParse(item["date"] ?? "");
                String formatAmount(dynamic v) {
                  if (v == null) return "-";
                  final val = double.tryParse(v.toString()) ?? 0.0;
                  return val != 0.0 ? "₹${val.toStringAsFixed(2)}" : "-";
                }

                return [
                  (index + 1).toString(),
                  pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      date != null ? DateFormat('dd-MM-yyyy').format(date) : "-",
                      style: pw.TextStyle(fontSize: 8), // smaller date font
                    ),
                  ),
                  // Particular: normal readable size
                  pw.Text(
                    item["particular"] ?? "-",
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      formatAmount(item["income"]),
                      style: pw.TextStyle(fontSize: 8), // smaller amount font
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      formatAmount(item["expense"]),
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      formatAmount(item["drawingIn"]),
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      formatAmount(item["drawingOut"]),
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
                ];
              }),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1.3), // slightly smaller
                2: const pw.FlexColumnWidth(4.3), // more space for Particular
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(1.6),
                5: const pw.FlexColumnWidth(1.6),
                6: const pw.FlexColumnWidth(1.7),
              },
            ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: pw.Row(
              children: [
                // TOTAL label
                pw.Expanded(
                  flex: 8,
                  child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      "TOTAL",
                      style: pw.TextStyle(
                        font: tamilFontBold,
                        fontSize: 9,
                        color: darkGreen,
                      ),
                    ),
                  ),
                ),

                // Income total
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    "₹${totals["income"]?.toStringAsFixed(2) ?? '0.00'}",
                    style: pw.TextStyle(
                      font: tamilFontBold,
                      color: darkGreen,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),

                // Expense total
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    "₹${totals["expense"]?.toStringAsFixed(2) ?? '0.00'}",
                    style: pw.TextStyle(
                      font: tamilFontBold,
                      color: darkGreen,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),

                // Drawing In total
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    "₹${totalDrawingIn.toStringAsFixed(2) }",
                    style: pw.TextStyle(
                      font: tamilFontBold,
                      color: darkGreen,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),

                // Drawing Out total
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    "₹${totalDrawingOut.toStringAsFixed(2) }",
                    style: pw.TextStyle(
                      font: tamilFontBold,
                      color: darkGreen,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),



          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: darkGreen, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Monthly Summary",
                  style: pw.TextStyle(
                    font: tamilFontBold,
                    fontSize: 10,
                    color: darkGreen,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Previous Balance:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${openingBalance.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Income:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalIncome.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Expense:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalExpense.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Drawing In:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalDrawingIn.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Drawing Out:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalDrawingOut.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),

                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Balance :",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: darkGreen)),
                    pw.Text("₹${balance.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: darkGreen)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 35),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end, // align children to the right
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text(
                    'Signature',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: tamilFontBold,
                      fontSize: 9
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
}
