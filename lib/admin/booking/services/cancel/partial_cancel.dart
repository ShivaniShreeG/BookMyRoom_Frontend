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
import 'partial_cancel_bill.dart';

const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class PartialCancelPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const PartialCancelPage({super.key, required this.booking});

  @override
  State<PartialCancelPage> createState() => PartialCancelPageState();
}

class PartialCancelPageState extends State<PartialCancelPage> {
  Map<String, dynamic>? hallDetails;
  List<Uint8List?> guestIdBytes = [];
  bool bookingSuccess = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool submitting = false;
  Map<String, dynamic>? bookingResponse;
  final TextEditingController _reasonPercentageController = TextEditingController();
  final TextEditingController _cancelPercentageController = TextEditingController();
  final TextEditingController _cancelChargeController = TextEditingController();
  final TextEditingController _refundController = TextEditingController();
  List<dynamic> selectedRooms = [];
  late double originalBaseAmount;
  late int originalRoomCount;
  late int numDays;

  int numGuests = 1;
  List<File?> guestIdProofs = [];

  // final ImagePicker _picker = ImagePicker();
  @override
  void initState() {
    super.initState();
    _fetchHallDetails();
    _fetchCancelInfo();
    _reasonPercentageController.text = "Nill";
    originalBaseAmount = widget.booking['baseamount'] * 1.0;
    originalRoomCount  = widget.booking['specification']['number_of_rooms'];
    numDays            = widget.booking['specification']['number_of_days'];
    selectedRooms = List.from(widget.booking['room_number']); // default selection
  }

  @override
  void dispose() {
    _resetToOriginalState();
    super.dispose();
  }

  void _resetToOriginalState() {
    setState(() {
      // Reset room selection
      selectedRooms = List.from(widget.booking['room_number']);

      // Reset base amount
      widget.booking['baseamount'] = originalBaseAmount;

      // Reset fields
      _reasonPercentageController.text = "Nill";
      _cancelPercentageController.text = "";
      _cancelChargeController.text = "";
      _refundController.text = "";

      // Fetch original cancel info again
      _fetchCancelInfo();
    });
  }

  void _recalculateBaseAmount() {
    double basePerRoom = originalBaseAmount / originalRoomCount;
    double newBaseAmount = basePerRoom * numDays * selectedRooms.length;

    setState(() {
      widget.booking['baseamount'] = newBaseAmount;
    });
  }

  Widget _roomSelector(List rooms) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: rooms.map<Widget>((room) {
        final selected = selectedRooms.contains(room);

        return ChoiceChip(
          label: Text("$room", style: const TextStyle(color: Colors.white)),
          selected: selected,
          selectedColor: royal,
          backgroundColor: royalLight,
          onSelected: (value) {
            setState(() {
              if (value) {
                selectedRooms.add(room);
              } else {
                selectedRooms.remove(room);
              }

              if (selectedRooms.isEmpty) {
                selectedRooms.add(room); // At least one room must stay selected
              }

              // Recalculate base amount
              _recalculateBaseAmount();

              // Fetch cancel info using new base amount
              _fetchCancelInfo();
            });
          },
        );
      }).toList(),
    );
  }

  Future<void> _fetchCancelInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt('lodgeId');
      final bookingId = widget.booking['booking_id'];
      final baseAmount = widget.booking['baseamount'];
      final checkIn = widget.booking['check_in'];

      final url = Uri.parse('$baseUrl/cancels/cancel-price');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': bookingId,
          'baseAmount': baseAmount,
          'checkInDate': checkIn,
          'lodgeId': lodgeId,
        }),
      );

      if (response.statusCode == 200||response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _cancelPercentageController.text = data['cancelPercentage'].toString();
          _cancelChargeController.text = data['cancellationCharge'].toStringAsFixed(2);
          _refundController.text = data['refund'].toStringAsFixed(2);
        });
      } else {
        _showMessage('Failed to fetch cancellation info');
      }
    } catch (e) {
      _showMessage('Error: $e');
    }
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

  Widget _cancelInfoSection(Map<String, dynamic> b) {
    final double baseAmount = b["baseamount"]?.toDouble() ?? 0.0;

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
              Center(
                child: const Text(
                  "ROOM NUMBERS",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Center(
                child: _roomSelector(b['room_number']),   // UPDATED
              ),

              const SizedBox(height: 15),

              _cancelRow("No. of Days", "$numDays"),

              const SizedBox(height: 10),

              _cancelRow("No. of Rooms", "${selectedRooms.length}"),  // UPDATED

              const SizedBox(height: 10),

              _cancelRow("Base Amount", "₹${baseAmount.toStringAsFixed(2)}"), // UPDATED

              const SizedBox(height: 10),

              _editableRow(
                "Reason",
                _reasonPercentageController,
                onChanged: (val) {},
                inputFormatters: [],
              ),

              const SizedBox(height: 10),

              // Cancel %
              _editableRow(
                "Cancel %",
                _cancelPercentageController,
                suffix: "%",
                onChanged: (val) {
                  double perc = double.tryParse(val) ?? 0;

                  final charge = (baseAmount * perc / 100).clamp(0, baseAmount);
                  final refund = (baseAmount - charge).clamp(0, baseAmount);

                  setState(() {
                    _cancelChargeController.text = charge.toStringAsFixed(2);
                    _refundController.text = refund.toStringAsFixed(2);
                  });
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?$')),
                ],
              ),

              const SizedBox(height: 10),

              // Cancellation Charge
              _editableRow(
                "Cancellation Charge",
                _cancelChargeController,
                onChanged: (val) {
                  double charge = double.tryParse(val) ?? 0;

                  final perc = ((charge / baseAmount) * 100).clamp(0, 100);
                  final refund = (baseAmount - charge).clamp(0, baseAmount);

                  setState(() {
                    _cancelPercentageController.text = perc.toStringAsFixed(2);
                    _refundController.text = refund.toStringAsFixed(2);
                  });
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,10}(\.\d{0,2})?$')),
                ],
              ),

              const SizedBox(height: 10),

              // Refund Amount
              _editableRow(
                "Refund Amount",
                _refundController,
                onChanged: (val) {
                  double refund = double.tryParse(val) ?? 0;

                  final charge = (baseAmount - refund).clamp(0, baseAmount);
                  final perc = ((charge / baseAmount) * 100).clamp(0, 100);

                  setState(() {
                    _cancelChargeController.text = charge.toStringAsFixed(2);
                    _cancelPercentageController.text = perc.toStringAsFixed(2);
                  });
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,10}(\.\d{0,2})?$')),
                ],
              ),
            ],
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
                "CANCELLATION INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _bookRooms() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage("Please fill all required fields");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    final userId = prefs.getString("userId");
    final bookingID = widget.booking['booking_id'];

    if (lodgeId == null || userId == null) {
      _showMessage("Lodge ID or User ID not found!");
      return;
    }

    setState(() => submitting = true);

    final url = Uri.parse("$baseUrl/cancels/partial");

    final body = {
      "bookingId": bookingID,
      "lodgeId": lodgeId,
      "userId": userId,

      // MUST MATCH roomNumbers in backend DTO
      "roomNumbers": selectedRooms,

      "reason": _reasonPercentageController.text,

      // NEW BASE AMOUNT FOR SELECTED ROOMS ONLY
      "amountPaid": widget.booking['baseamount'],

      "cancelCharge": double.tryParse(_cancelChargeController.text) ?? 0,
      "refund": double.tryParse(_refundController.text) ?? 0,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    setState(() => submitting = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      _showMessage("Cancellation Successful!");

      setState(() {
        bookingSuccess = true;
        bookingResponse = data;
      });

      _resetToOriginalState();

    } else {
      _showMessage("Cancellation failed: ${response.body}");
    }
  }

  Widget _cancelRow(String label, String value) {
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
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: royal, width: 1),
              color: royal.withOpacity(0.05),
            ),
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: royal),
            ),
          ),
        ),
      ],
    );
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

  Widget _editableRow(
      String label,
      TextEditingController controller, {
        String? prefix,
        String? suffix,
        required Function(String) onChanged,
        List<TextInputFormatter>? inputFormatters,
      }) {
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
            controller: controller,
            keyboardType: prefix == null && suffix == null
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            cursorColor: royal,
            inputFormatters: inputFormatters,
            textAlign: TextAlign.right,
            style: const TextStyle(color: royal),
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: const TextStyle(color: royal, fontWeight: FontWeight.bold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: royal, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: royal, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: royal.withOpacity(0.05),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
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
              Center(
                child: Text("${b['room_name']} - ${b['room_type']}",
                  style: const TextStyle(color: royal,
                    fontSize: 20, fontWeight: FontWeight.bold,),),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),

              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Number of Guests",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      initialValue: numGuests.toString(),
                      readOnly: true,
                      cursorColor: royal,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: royal),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
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
              const SizedBox(height: 10),
              _paymentRow("No. of Rooms", b["specification"]["number_of_rooms"].toString()),
              const SizedBox(height: 10),

              _paymentRow("Base Amount", "₹${b["baseamount"]}"),
              const SizedBox(height: 10),
              _paymentRow("GST", "₹${b["gst"]}"),
              const SizedBox(height: 10),
              _paymentRow("Total Amount", "₹${b["amount"]}"),
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
                "Booking ID: ${b["booking_id"]}",
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
      fillColor: royal.withOpacity(0.05),
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

    // Parse alternate phone
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

    // ---------------- ALIGNED TEXT FOR WHATSAPP ----------------
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

    // -------------------- RETURN UI --------------------
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
          title: const Text("Partially Cancel Booking", style: TextStyle(color: Colors.white)),
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
        body: Padding(
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
                                        builder: (context) => PartialCancelBillPage(
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
                  _cancelInfoSection(b),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: royal),
                      onPressed: submitting ? null : _bookRooms,
                      child: submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Cancel Booking",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _personalInfoSection(b),
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
