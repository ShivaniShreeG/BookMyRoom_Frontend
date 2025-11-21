import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bill.dart';

const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class BillingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BillingDetailsPage({super.key, required this.booking});

  @override
  State<BillingDetailsPage> createState() => BillingDetailsPageState();
}

class BillingDetailsPageState extends State<BillingDetailsPage> {
  Map<String, dynamic>? hallDetails;
  bool bookingSuccess = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool submitting = false;
  Map<String, dynamic>? bookingResponse;
  List<TextEditingController> _chargeControllers = [];

  late final int bookingId;
  List<Map<String, dynamic>> charges = [];
  bool isLoadingCharges = true;

  @override
  void initState() {
    super.initState();
    bookingId = widget.booking['booking_id']; // extract bookingId from previous page
    _fetchHallDetails();
    _fetchCharges(); // call as Future<void>
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchCharges() async {
    setState(() => isLoadingCharges = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt('lodgeId');

      if (lodgeId == null) {
        _showMessage('Lodge ID not found');
        return;
      }

      final url = Uri.parse('$baseUrl/billings/charges/$bookingId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
            charges = List<Map<String, dynamic>>.from(data['charges'] ?? []);
            _chargeControllers = charges
                .map((c) => TextEditingController(text: c['amount'].toString()))
                .toList();
        });
      } else {
        _showMessage('Failed to fetch charges');
      }
    } catch (e) {
      _showMessage('Error fetching charges: $e');
    } finally {
      setState(() => isLoadingCharges = false);
    }
  }

  Widget _billingInfoSection() {
    double balance = widget.booking['Balance'] != null
        ? double.tryParse(widget.booking['Balance'].toString()) ?? 0
        : 0;
    double deposit = widget.booking['deposite'] != null
        ? double.tryParse(widget.booking['deposite'].toString()) ?? 0
        : 0;

    double chargesTotal = charges.fold(0, (sum, c) {
      double amt = double.tryParse(c['amount'].toString()) ?? 0;
      return sum + amt;
    });

    double total = balance + chargesTotal;
    double balancePayment = total - deposit;

    List<Widget> rows = [];

    // Balance
    if (balance != 0) {
      rows.add(_billTextField("Balance", balance.toStringAsFixed(2)));
    }

    // Charges
    for (int i = 0; i < charges.length; i++) {
      final c = charges[i];
      final amount = c['amount'].toString();
      rows.add(
        GestureDetector(
          onTap: () => _showChargeDialog(existingCharge: c, index: i),
          child: _billTextField(c['reason'] ?? 'No Reason', amount),
        ),
      );
    }

    // Total
    rows.add(_billTextField("Total", total.toStringAsFixed(2), isTotal: true));

    // Deposit
    if (deposit != 0) {
      rows.add(_billTextField("Deposit", deposit.toStringAsFixed(2)));
      rows.add(
        _billTextField(
          "Balance Payment",
          balancePayment.abs().toStringAsFixed(2),
          isTotal: true,
          valueColor: balancePayment >= 0 ? Colors.green : Colors.red,
        ),
      );
    }

    // Centered Add Button
    rows.add(
      Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: royal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 120),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text("Add"),
          onPressed: () => _showChargeDialog(),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          ),
        ),
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "BILLING INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _billTextField(String label, String value,
      {bool isTotal = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8), // uniform vertical spacing
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: royal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: TextFormField(
              readOnly: true,
              initialValue: value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? royal,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
              decoration: _inputDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChargeDialog({Map<String, dynamic>? existingCharge, int? index}) async {
    final _reasonController =
    TextEditingController(text: existingCharge != null ? existingCharge['reason'] : '');
    final _amountController = TextEditingController(
        text: existingCharge != null ? existingCharge['amount'].toString() : '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingCharge != null ? "Edit Charge" : "Add Charge"),
        titleTextStyle: TextStyle(
          color: royal,           // set your desired color here
          fontSize: 20,                // optional: font size
          fontWeight: FontWeight.bold, // optional: font weight
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: TextStyle(color: royal),
              controller: _reasonController,
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 8),
            TextField(
              style: TextStyle(color: royal),
              controller: _amountController,
              decoration: _inputDecoration(),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: royal, // background color
              foregroundColor: Colors.white, // text color
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: royal, // background color
              foregroundColor: Colors.white, // text color
            ),
            onPressed: () {
              final reason = _reasonController.text.trim();
              final amount = double.tryParse(_amountController.text.trim()) ?? 0;

              if (reason.isEmpty) {
                _showMessage("Reason cannot be empty");
                return;
              }

              setState(() {
                if (existingCharge != null && index != null) {
                  // Edit existing charge
                  charges[index] = {"reason": reason, "amount": amount};
                  _chargeControllers[index].text = amount.toString();
                } else {
                  // Add new charge
                  charges.add({"reason": reason, "amount": amount});
                  _chargeControllers.add(TextEditingController(text: amount.toString()));
                }
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _paymentInfoSection(Map<String, dynamic> b) {
    bool _hasValue(dynamic val) => val != null && val.toString().trim().isNotEmpty;
    bool isPaid = !_hasValue(b["Balance"]) || b["Balance"].toString() == "0";

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Number of Days
              // if (_hasValue(b["specification"]["number_of_days"])) ...[
              _paymentRow("No. of Days", b["specification"]["number_of_days"].toString()),
              const SizedBox(height: 10),
              // ],

              // Number of Rooms
              // if (_hasValue(b["specification"]["number_of_rooms"])) ...[
              _paymentRow("No. of Rooms", b["specification"]["number_of_rooms"].toString()),
              const SizedBox(height: 10),
              // ],

              _paymentRow("Base Amount", "₹${b["baseamount"]}"),
              const SizedBox(height: 10),

              _paymentRow("GST", "₹${b["gst"]}"),
              const SizedBox(height: 10),
              // Amount
              // if (_hasValue(b["amount"])) ...[
              _paymentRow("Total Amount", "₹${b["amount"]}"),
              const SizedBox(height: 10),
              // ],

              // Advance
              // if (_hasValue(b["advance"])) ...[
              //   _infoTextField("Advance", "₹${b["advance"]}"),
              //   const SizedBox(height: 10),
              // ],

              // Advance or Paid
              _paymentRow(
                isPaid ? "Amount Paid" : "Advance",
                "₹${b["advance"]}",
              ),
              const SizedBox(height: 10),

              // Balance
              _paymentRow("Balance", "₹${b["Balance"]}"),
              const SizedBox(height: 10),
              _paymentRow("Deposite", "₹${b["deposite"]}")
// Deposit field
//               Row(
//                 children: [
//                   const Expanded(
//                     flex: 2,
//                     child: Text(
//                       "Deposit:",
//                       style: TextStyle(fontWeight: FontWeight.bold, color: royal),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     flex: 4,
//                     child: TextFormField(
//                       controller: _depositController,
//                       keyboardType: TextInputType.number,
//                       textAlign: TextAlign.right,
//                       style: const TextStyle(color: royal),
//                       decoration: _inputDecoration().copyWith(
//                         hintText: "Enter deposit amount", // <-- Hint text
//                         hintStyle: TextStyle(color: royal.withOpacity(0.5)),
//                       ),
//                       onTap: () {
//                         if (_depositController.text == "0") {
//                           _depositController.clear();
//                         }
//                       },
//                     ),
//                   ),
//                 ],
//               ),
            ],
          ),
        ),

        // Floating header
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "PAYMENT INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _personalInfoSection(Map<String, dynamic> b) {
    bool _hasValue(dynamic val) => val != null && val.toString().trim().isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Name (always show)
              _infoTextField("Name", b["name"]),

              // Phone (always show)
              const SizedBox(height: 10),
              _infoTextField("Phone", b["phone"]),

              // Alternate Phone (only if exists)
              if (_hasValue(b["alternate_phone"])) ...[
                const SizedBox(height: 10),
                _infoTextField("Alt Phone", b["alternate_phone"]),
              ],

              // Email (only if exists)
              if (_hasValue(b["email"])) ...[
                const SizedBox(height: 10),
                _infoTextField("Email", b["email"]),
              ],

              // Address (only if exists)
              if (_hasValue(b["address"])) ...[
                const SizedBox(height: 10),
                _infoTextField("Address", b["address"]),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),

        // Floating header
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child:  Text(
                "PERSONAL INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _fetchHallDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt("lodgeId");

      final url = Uri.parse('$baseUrl/lodges/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        hallDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching hall details: $e");
    } finally {
      setState(() {});
    }
  }

  Future<void> _bookRooms() async {
    setState(() => submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt('lodgeId');
      final userId = prefs.getString('userId');
      final bookingID = bookingId;

      if (lodgeId == null || userId == null) {
        _showMessage("LodgeId or UserId not found");
        return;
      }

      // Get Balance and add it as a charge
      double balance = double.tryParse(widget.booking['Balance']?.toString() ?? '0') ?? 0;
      if (balance != 0) {
        charges.add({"reason": "Balance", "amount": balance});
      }

      // Convert list of charges -> JSON { reason: amount }
      Map<String, dynamic> reasonJson = {
        for (var c in charges)
          c['reason'].toString(): double.tryParse(c['amount'].toString()) ?? 0
      };

      // Total calculation
      double chargesTotal =
      reasonJson.values.fold(0, (sum, value) => sum + (value as num));

      double deposit = double.tryParse(widget.booking['deposite']?.toString() ?? '0') ?? 0;
      deposit = (deposit == 0) ? 0 : deposit;

      double? balancePayment = chargesTotal - deposit;
      balancePayment = (balancePayment == 0) ? null : balancePayment;

      final body = {
        "lodge_id": lodgeId,
        "user_id": userId,
        "booking_id": bookingID,
        "reason": reasonJson.isNotEmpty ? reasonJson : null,
        "total": chargesTotal > 0 ? chargesTotal : null,
        "balancePayment": (balancePayment != null && balancePayment != 0)
            ? balancePayment
            : 0,
      };
      print(body);
      final url = Uri.parse("$baseUrl/billings");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        _showMessage("Billing saved successfully!");

        setState(() {
          bookingSuccess = true;
          bookingResponse = data;
        });
      } else {
        _showMessage("Failed: ${response.body}");
      }
    } catch (e) {
      _showMessage("Error: $e");
    } finally {
      setState(() => submitting = false);
    }
  }

  Widget _paymentRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            "$label:",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: royal,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: TextFormField(
            readOnly: true,
            initialValue: value,
            textAlign: TextAlign.right, // Right-align the value
            style: const TextStyle(color: royal),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }

  String formatDate(String dt) {
    try {
      final dateTime = DateTime.parse(dt);
      return DateFormat('dd MMM yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return dt;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: royal)),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: royal, width: 2),
        ),
      ),
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: royal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: royal, width: 1.5),
      ),
      child: Row(
        children: [
          ClipOval(
            child: hall['logo'] != null
                ? Image.memory(
              base64Decode(hall['logo']),
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            )
                : Container(
              width: 70,
              height: 70,
              color: Colors.white,
              child: const Icon(Icons.home_work_rounded,
                  color: royal, size: 35),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hall['name']?.toString().toUpperCase() ?? "LODGE NAME",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String formatTo12Hour(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.year} "
        "${(dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')} "
        "${dt.hour >= 12 ? "PM" : "AM"}";
  }

  Widget _bookingInfoSection(Map<String, dynamic> b) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Room type & name centered
              Center(
                child: Text(
                  "${b['room_name']} - ${b['room_type']}",
                  style: const TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Number of guest",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      style: TextStyle(color: royal),
                      readOnly: true,
                      initialValue: b["numberofguest"].toString(),
                      decoration: _inputDecoration(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              // Check-In row
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Check-In",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      style: TextStyle(color: royal),
                      readOnly: true,
                      initialValue: formatTo12Hour(DateTime.parse(b['check_in'])),
                      decoration: _inputDecoration(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Check-Out row
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Check-Out",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      style: TextStyle(color: royal),
                      readOnly: true,
                      initialValue: formatTo12Hour(DateTime.parse(b['check_out'])),
                      decoration: _inputDecoration(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Center(
                child: Text(
                  "ROOM NUMBERS",
                  style: const TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Room Number Chips
              Center(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: b['room_number']
                      .map<Widget>(
                        (n) => Chip(
                      label: Text(
                        "$n",
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: royal,
                    ),
                  )
                      .toList(),
                ),
              ),
            ],
          ),
        ),

        // Floating centered header
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "BOOKING INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoTextField(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            "$label:",
            style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: TextFormField(
            readOnly: true,
            initialValue: value,
            style: const TextStyle(color: royal),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: royal.withValues(alpha: 0.05),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }

  Widget bookingDetailsCard({
    required Map<String, dynamic> booking,
    required Color royal,
  }) {

    String formatTo12Hour(DateTime dt) {
      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-"
          "${dt.year} "
          "${(dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0')}:"
          "${dt.minute.toString().padLeft(2, '0')} "
          "${dt.hour >= 12 ? "PM" : "AM"}";
    }

    String formatDateTime(String? dateTimeStr) {
      if (dateTimeStr == null) return 'N/A';
      try {
        final dt = DateTime.parse(dateTimeStr);
        return formatTo12Hour(dt);
      } catch (e) {
        return 'Invalid date';
      }
    }

    final roomNumbers = booking['room_number'] as List<dynamic>?;
    final idProofs = booking['id_proof'] as List<dynamic>?;

    List<String> alternatePhones = [];
    if (booking['alternate_phone'] != null &&
        booking['alternate_phone'].toString().isNotEmpty) {
      try {
        final alt = jsonDecode(booking['alternate_phone'].toString());
        if (alt is List) alternatePhones = alt.map((e) => e.toString()).toList();
      } catch (_) {
        alternatePhones =
            booking['alternate_phone'].toString().split(',').map((e) => e.trim()).toList();
      }
    }

    String generateShareText() {
      String s(dynamic v) => v?.toString() ?? "N/A";

      String formatLine(String label, dynamic value) {
        return "${label.padRight(13)} : ${s(value)}";
      }

      final buffer = StringBuffer();

      buffer.writeln("```"); // Start monospace block

      // BOOKING CONFIRMATION HEADER
      buffer.writeln("   Booking Confirmation");
      buffer.writeln("---------------------------");

      // HALL / LODGE NAME
      // buffer.writeln("${hallDetails?['name'] ?? 'Lodge / Hotel'}");
      buffer.writeln("This is your official booking confirmation message from ${hallDetails?['name']}.");
      buffer.writeln("");

      // Booking ID
      buffer.writeln(formatLine("Booking ID", booking['booking_id']));
      buffer.writeln("⚠️ Keep your Booking ID for future reference.");
      buffer.writeln("");
      buffer.writeln("        Booking Details");
      buffer.writeln(formatLine("Name", booking['name']));
      buffer.writeln(formatLine("Phone", booking['phone']));

      // if (alternatePhones.isNotEmpty)
      //   buffer.writeln(formatLine("Alt Phone", alternatePhones.join(', ')));
      //
      // if (booking['email'] != null)
      //   buffer.writeln(formatLine("Email", booking['email']));
      //
      // if (booking['address'] != null)
      //   buffer.writeln(formatLine("Address", booking['address']));

      buffer.writeln("");

      // BOOKING INFO
      // buffer.writeln("         *Booking Info*");
      buffer.writeln(formatLine("Check-in", formatDateTime(booking['check_in'])));
      buffer.writeln(formatLine("Check-out", formatDateTime(booking['check_out'])));

      // Room + Type in one line
      if (booking['room_name'] != null || booking['room_type'] != null) {
        String roomInfo =
        "${booking['room_name'] ?? ''} ${booking['room_type'] ?? ''}".trim();
        buffer.writeln(formatLine("Room Type", roomInfo));
      }

      if (roomNumbers != null && roomNumbers.isNotEmpty)
        buffer.writeln(formatLine("Room Number", roomNumbers.join(', ')));

      // if (booking['numberofguest'] != null)
      //   buffer.writeln(formatLine("Guests", booking['numberofguest']));
      //
      // if (idProofs != null && idProofs.isNotEmpty)
      //   buffer.writeln(formatLine("ID Proofs", idProofs.join(', ')));
      // PAYMENT DETAILS FIRST (as you requested)
      buffer.writeln("       Payment Details");

      if (booking['baseamount'] != null)
        buffer.writeln(formatLine("Base Amount", booking['baseamount']));

      if (booking['gst'] != null)
        buffer.writeln(formatLine("GST", booking['gst']));

      if (booking['amount'] != null)
        buffer.writeln(formatLine("Total Amount", booking['amount']));

      if (booking['advance'] != null)
        buffer.writeln(formatLine("Advance", booking['advance']));

      if (booking['deposite'] != null)
        buffer.writeln(formatLine("Deposite", booking['deposite']));

      // TOTAL PAID = ADVANCE + DEPOSITE
      double adv = double.tryParse(booking['advance']?.toString() ?? "0") ?? 0;
      double dep = double.tryParse(booking['deposite']?.toString() ?? "0") ?? 0;
      double totalPaid = adv + dep;

      if (dep > 0)
        buffer.writeln(formatLine("Total Paid", totalPaid));

      if (booking['Balance'] != null)
        buffer.writeln(formatLine("Balance", booking['Balance']));

      buffer.writeln("");

      buffer.writeln("----------------------------------");
      buffer.writeln("Thank you for choosing us! 😊");
      buffer.writeln("```"); // End monospace block

      return buffer.toString();
    }

    Future<void> shareViaWhatsApp() async {
      if (booking['phone'] == null || booking['phone'].toString().isEmpty) return;

      final text = Uri.encodeComponent(generateShareText());
      final phoneNumber = booking['phone'].toString().replaceAll(' ', '');
      final url = 'https://wa.me/$phoneNumber?text=$text';

      if (await canLaunch(url)) {
        await launch(url);
      } else {
        debugPrint("Cannot launch WhatsApp");
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: royal, width: 2),
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: royal.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // PERSONAL INFO
                if (booking['name'] != null || booking['phone'] != null)
                  Column(
                    children: [
                      if (booking['name'] != null)
                        buildLabelValue("Name", booking['name'],royal),
                      if (booking['phone'] != null)
                        buildLabelValue("Phone", booking['phone'],royal),
                      if (booking['address'] != null)
                        buildLabelValue("Address", booking['address'],royal),
                      if (alternatePhones.isNotEmpty)
                        buildLabelValue("Alt Phone", alternatePhones.join(', '),royal),
                      if (booking['email'] != null)
                        buildLabelValue("Email", booking['email'],royal),
                    ],
                  ),

                const SizedBox(height: 15),
                Divider(color: royal, thickness: 1),
                const SizedBox(height: 10),

                // BOOKING INFO
                Column(
                  children: [
                    if (booking['check_in'] != null)
                      buildLabelValue("Check-in", formatDateTime(booking['check_in']),royal),
                    if (booking['check_out'] != null)
                      buildLabelValue("Check-out", formatDateTime(booking['check_out']),royal),
                    if (booking['room_name'] != null || booking['room_type'] != null)
                      buildLabelValue(
                          "Room",
                          "${booking['room_name'] ?? ''} ${booking['room_type'] ?? ''}".trim(),royal
                      ),
                    if (roomNumbers != null && roomNumbers.isNotEmpty)
                      buildLabelValue("Room Number", roomNumbers.join(', '),royal),
                    if (booking['numberofguest'] != null)
                      buildLabelValue("Guests", booking['numberofguest'].toString(),royal),
                    if (idProofs != null && idProofs.isNotEmpty)
                      buildLabelValue("ID Proofs", idProofs.join(', '),royal),
                  ],
                ),

                const SizedBox(height: 15),
                Divider(color: royal, thickness: 1),
                const SizedBox(height: 10),

                // PAYMENT INFO
                Column(
                  children: [
                    if (booking['baseamount'] != null)
                      buildLabelValue("Base Amount", booking['baseamount'].toString(),royal),
                    if (booking['gst'] != null)
                      buildLabelValue("GST", booking['gst'].toString(),royal),
                    if (booking['amount'] != null)
                      buildLabelValue("Total Amount", booking['amount'].toString(),royal),
                    if (booking['advance'] != null)
                      buildLabelValue("Advance", booking['advance'].toString(),royal),
                    if (booking['deposite'] != null)
                      buildLabelValue("Deposite", booking['deposite'].toString(),royal),
                    if (booking['deposite'] != null)
                      buildLabelValue("Total Paid",  (
                          (booking['advance'] != null ? double.tryParse(booking['advance'].toString()) ?? 0 : 0) +
                              (booking['deposite'] != null ? double.tryParse(booking['deposite'].toString()) ?? 0 : 0)
                      ).toString() ,royal),
                    if (booking['Balance'] != null)
                      buildLabelValue("Balance", booking['Balance'].toString(),royal),
                  ],
                ),


                const SizedBox(height: 20),

                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: royal),
                    onPressed: shareViaWhatsApp,
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text(
                      "Share via WhatsApp",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // FLOATING BOOKING ID
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Booking ID: ${booking['booking_id'] ?? 'N/A'}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildLabelValue(String label, String value, Color royal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(94),
          1: FixedColumnWidth(5),
          2: FlexColumnWidth(),
        },
        children: [
          TableRow(
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: royal)),
              Text(":", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: royal)),
              Text(value, style: TextStyle(fontSize: 15, color: royal)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    bool isPageLoading = hallDetails == null || isLoadingCharges;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, res) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: royal,
          title: const Text("Billing", style: TextStyle(color: Colors.white)),
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
        body: isPageLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: bookingSuccess
                ? SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  if (hallDetails != null) _buildHallCard(hallDetails!),
                  const SizedBox(height: 40),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                            decoration: BoxDecoration(
                              border: Border.all(color: royal, width: 2),
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 20),
                                const Text(
                                  "Generate bill for cancellation.\nView it as PDF and download.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: royal,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: royal,
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BillPage(
                                          bookingDetails: widget.booking,
                                          serverData: bookingResponse, // ⬅ NEW
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Generate Bill",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Floating header
                        Positioned(
                          top: -20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                              decoration: BoxDecoration(
                                color: royal,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "GENERATE BILL",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ) : SingleChildScrollView(
              padding: const EdgeInsets.all(2),
              child: Column(
                children: [
                  if (hallDetails != null) _buildHallCard(hallDetails!),
                  const SizedBox(height: 40),
                  _personalInfoSection(b),
                  const SizedBox(height: 30),
                  _bookingInfoSection(b),
                  const SizedBox(height: 30),
                  _paymentInfoSection(b),
                  const SizedBox(height: 30),
                  _billingInfoSection(),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: royal),
                      onPressed: submitting ? null : _bookRooms,
                      child: submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Confirm Billing",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (bookingSuccess) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
            (route) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }
}
