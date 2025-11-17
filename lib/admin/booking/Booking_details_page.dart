import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';
import '../../public/main_navigation.dart';
import 'pdf/old_billing_pdf.dart';

class BookingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? hallDetails; // add this

  const BookingDetailsPage({
    super.key,
    required this.booking,
    this.hallDetails, // optional
  });

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  Map<String, dynamic>? hallDetails;

  final Color primaryColor = const Color(0xFF5B6547);
  final Color cardColor = const Color(0xFFD8C9A9);
  final Color scaffoldBackground = const Color(0xFFECE5D8);

  @override
  void initState() {
    super.initState();
    // Assign the hallDetails passed from UpcomingEventsPage
    hallDetails = widget.hallDetails;

    // Optional: if hallDetails is null, fetch from server
    if (hallDetails == null && widget.booking['hall_id'] != null) {
      _fetchHallDetails(widget.booking['hall_id']);
    }
  }

  Future<void> _fetchHallDetails(int hallId) async {
    try {
      final url = Uri.parse('$baseUrl/halls/$hallId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          hallDetails = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching hall details: $e");
    }
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha:0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: cardColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha:0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hall['name'] != null) ...[
                  Text(
                    hall['name'].toString().toUpperCase(),
                    style: TextStyle(
                      color: cardColor.withValues(alpha:0.9),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ] else
                  const Text(
                    "HALL NAME",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor.withValues(alpha:0.6), width: 1),
            ),
            child: ClipOval(
              child: hall['logo'] != null
                  ? Image.memory(
                base64Decode(hall['logo']),
                fit: BoxFit.cover,
              )
                  : const Icon(Icons.home_work, color: Colors.white, size: 35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scaffoldBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _plainRowWithTanValue(BuildContext context, String label, {required String value}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: screenWidth * 0.35,
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Container(
            width: screenWidth * 0.38,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              value,
              style: TextStyle(color: primaryColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainRowIfNotEmpty(BuildContext context, String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    if (value is String && value.trim().isEmpty) return const SizedBox.shrink();
    if (value is List && value.isEmpty) return const SizedBox.shrink();

    String displayValue;
    if (value is List) {
      displayValue = value.join(', ');
    } else {
      displayValue = value.toString();
    }

    return _plainRowWithTanValue(context, label, value: displayValue);
  }

  @override
  Widget build(BuildContext context) {
    final billings = widget.booking['billings'] as List<dynamic>? ?? [];

    final DateTime? allotedFrom = widget.booking['alloted_from'] != null
        ? DateTime.parse(widget.booking['alloted_from'])
        : null;

    final DateTime? allotedTo = widget.booking['alloted_to'] != null
        ? DateTime.parse(widget.booking['alloted_to'])
        : null;

    final DateTime? functionDate = widget.booking['function_date'] != null
        ? DateTime.parse(widget.booking['function_date'])
        : null;
    final totalPaid = billings.fold<double>(0, (sum, bill) => sum + ((bill['total'] ?? 0) as num).toDouble());

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: const Text("Booking Details"),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: cardColor),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: cardColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
        titleTextStyle: TextStyle(color: cardColor, fontSize: 23, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hallDetails != null) ...[
              _buildHallCard(hallDetails!),
              const SizedBox(height: 16),
            ],

            _sectionContainer("Customer & Event Info", [
              _plainRowIfNotEmpty(context, "NAME", widget.booking['customer_name']),
              _plainRowIfNotEmpty(context, "PHONE", widget.booking['phone']),
              _plainRowIfNotEmpty(context, "ADDRESS", widget.booking['address']),
              _plainRowIfNotEmpty(context, "EMAIL", widget.booking['email']),
              _plainRowIfNotEmpty(context, "ALTERNATE PHONE", widget.booking['alternate_phone']),
              _plainRowIfNotEmpty(context, "EVENT", widget.booking['event_type']),
              _plainRowIfNotEmpty(
                  context,
                  "FUNCTION DATE",
                  functionDate != null
                      ? DateFormat('dd-MM-yyyy').format(functionDate)
                      : null),
              _plainRowIfNotEmpty(context, "TAMIL DATE", widget.booking['tamil_date']),
              _plainRowIfNotEmpty(context, "TAMIL MONTH", widget.booking['tamil_month']),
              _plainRowIfNotEmpty(
                  context,
                  "ALLOTED FROM",
                  allotedFrom != null
                      ? "${DateFormat('dd-MM-yyyy').format(allotedFrom)}\n${DateFormat('hh:mm a').format(allotedFrom)}"
                      : null),
              _plainRowIfNotEmpty(
                  context,
                  "ALLOTED TO",
                  allotedTo != null
                      ? "${DateFormat('dd-MM-yyyy').format(allotedTo)}\n${DateFormat('hh:mm a').format(allotedTo)}"
                      : null),
              _plainRowIfNotEmpty(
                  context, "RENT", widget.booking['rent'] != null ? "₹${widget.booking['rent']}" : null),
              _plainRowIfNotEmpty(
                  context, "ADVANCE", widget.booking['advance'] != null ? "₹${widget.booking['advance']}" : null),
              _plainRowIfNotEmpty(
                  context, "BALANCE", widget.booking['balance'] != null ? "₹${widget.booking['balance']}" : null),
            ]),

            if (billings.isNotEmpty)
              _sectionContainer(
                "Billings",
                [
                  for (var bill in billings.reversed)
                    if (bill['reason'] != null && bill['reason'] is Map<String, dynamic>)
                      ...((bill['reason'] as Map<String, dynamic>)
                          .entries
                          .where((entry) =>
                      entry.key.toLowerCase() != 'advance') // exclude 'advance'
                          .toList()
                          .reversed
                          .map((entry) {
                        return _plainRowIfNotEmpty(
                          context,
                          entry.key.toUpperCase(),
                          "₹${entry.value}",
                        );
                      })),
                  _plainRowIfNotEmpty(
                    context,
                    "TOTAL AMOUNT PAID",
                    "₹$totalPaid",
                  ),
                ],

    ),
            // Add this at the bottom of your Column in SingleChildScrollView
            Column(
              children: [
                // Existing sections...

                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: cardColor,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Generate Billing PDF"),
                  onPressed: () {
                    final booking = widget.booking;

                    // 🧩 Format booking data
                    final formattedBooking = {
                      'hall_id': booking['hall_id'],
                      'user_id': booking['user_id'],
                      'function_date': booking['function_date'] != null
                          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(booking['function_date']))
                          : null,
                      'alloted_datetime_from': DateFormat('yyyy-MM-dd hh:mm a').format(
                        DateTime.parse(booking['alloted_from']),
                      ),
                      'alloted_datetime_to': DateFormat('yyyy-MM-dd hh:mm a').format(
                        DateTime.parse(booking['alloted_to']),
                      ),
                      'name': booking['customer_name'],
                      'phone': booking['phone'],
                      'alternate_phone': booking['alternate_phone'] ?? [],
                      'email': booking['email'],
                      'address': booking['address'],
                      'rent': (booking['rent'] ?? 0).toDouble(),
                      'advance': (booking['advance'] ?? 0).toDouble(),
                      'balance': (booking['balance'] ?? 0).toDouble(),
                      'event_type': booking['event_type'],
                      'tamil_date': booking['tamil_date'],
                      'tamil_month': booking['tamil_month'],
                      'booking_id': booking['booking_id'],
                    };

                    // 🏛 Format hall details
                    final formattedHall = {
                      'hall_id': hallDetails?['hall_id'],
                      'name': hallDetails?['name'],
                      'phone': hallDetails?['phone'],
                      'email': hallDetails?['email'],
                      'address': hallDetails?['address'],
                      'logo': hallDetails?['logo'],
                    };

                    // 🧾 Prepare billingData for PDF
                    final charges = <Map<String, dynamic>>[];
                    final billings = booking['billings'] as List<dynamic>? ?? [];
                    for (var bill in billings) {
                      if (bill['reason'] != null && bill['reason'] is Map<String, dynamic>) {
                        (bill['reason'] as Map<String, dynamic>).forEach((key, value) {
                          if (key.toLowerCase() != 'advance') {
                            charges.add({'reason': key, 'amount': value});
                          }
                        });
                      }
                    }

                    final grandTotal = charges.fold<double>(
                        0, (sum, c) => sum + ((c['amount'] ?? 0) as num).toDouble());

                    final billingData = {
                      'charges': charges,
                      'balance': (booking['balance'] ?? 0).toDouble(),
                      'grandTotal': grandTotal,
                    };

                    // 🔹 Print data for debugging
                    print("📦 Formatted Booking Data: $formattedBooking");
                    print("🏛 Formatted Hall Details: $formattedHall");
                    print("🧾 Billing Data: $billingData");

                    // ✅ Navigate to PDF page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UpdateBookingPdfPage(
                          bookingData: formattedBooking,
                          rawbilldata:booking,
                          hallDetails: formattedHall,
                          billingData: billingData,
                          primaryColor: primaryColor,
                          secondaryColor: cardColor,
                          backgroundColor: scaffoldBackground,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 60),

              ],
            )


          ],
    ),
      ),
    );
  }
}
