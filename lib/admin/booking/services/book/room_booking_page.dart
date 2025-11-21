import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import '../../../../utils/alternate_phone formatter.dart';
import 'package:url_launcher/url_launcher.dart';

const Color royal = Color(0xFF19527A);

class RoomBookingPage extends StatefulWidget {
  final String roomType;
  final String roomName;
  final DateTime checkIn;
  final DateTime checkOut;
  final List<String> availableRooms;

  const RoomBookingPage({
    super.key,
    required this.roomType,
    required this.roomName,
    required this.checkIn,
    required this.checkOut,
    required this.availableRooms,
  });

  @override
  State<RoomBookingPage> createState() => _RoomBookingPageState();
}

class _RoomBookingPageState extends State<RoomBookingPage> {
  bool submitting = false;
  bool loadingPrice = true;
  final TextEditingController advanceController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController altPhoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();
  final TextEditingController depositController = TextEditingController(text: "0");
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  double balance = 0;
  double deposit = 0.0;

  Map<String, dynamic>? pricingData;
  List<String> selectedRoomNumbers = [];
  Map<String, dynamic>? hallDetails;
  List<Uint8List?> guestIdBytes = [];

  String pricingType = "NORMAL";
  double? overriddenBaseAmount;
  Map<String, dynamic>? bookingResponse;
  bool bookingSuccess = false;

  int numGuests = 1;
  List<File?> guestIdProofs = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    selectedRoomNumbers = widget.availableRooms;
    guestIdProofs = List.generate(numGuests, (_) => null);
    _fetchPricing();
    _fetchHallDetails();
    phoneController.addListener(_onPhoneChanged);
    guestIdBytes = List.generate(numGuests, (_) => null);
    phoneController.text = '+91';
    phoneController.selection = TextSelection.fromPosition(
      TextPosition(offset: phoneController.text.length),
    );
  }

  void _onPhoneChanged() {
    final phone = phoneController.text.trim();
    // Only fetch if exactly 10 digits entered
    if (phone.length == 13) {
      _fetchBookingByPhone(phone);
    }
  }

  @override
  void dispose() {
    phoneController.removeListener(_onPhoneChanged);
    phoneController.dispose();
    super.dispose();
  }

  void _updateGuests(int count) {
    setState(() {
      numGuests = count;

      // Resize guestIdBytes
      if (guestIdBytes.length < count) {
        guestIdBytes.addAll(
          List.generate(count - guestIdBytes.length, (_) => null),
        );
      } else if (guestIdBytes.length > count) {
        guestIdBytes.removeRange(count, guestIdBytes.length);
      }

      // Resize guestIdProofs (THIS WAS MISSING)
      if (guestIdProofs.length < count) {
        guestIdProofs.addAll(
          List.generate(count - guestIdProofs.length, (_) => null),
        );
      } else if (guestIdProofs.length > count) {
        guestIdProofs.removeRange(count, guestIdProofs.length);
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:  TextStyle(
            color: royal,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: royal,width: 2)
        ),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
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


// -------------------- TABLE ALIGNMENT BUILDER --------------------
  Widget buildLabelValue(String label, String value) {
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15,color: royal)),
              const Text(":", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,color: royal)),
              Text(value, style: const TextStyle(fontSize: 15,color: royal)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(int index) async {
    try {
      // Safety check
      if (index >= guestIdBytes.length || index >= guestIdProofs.length) {
        _showMessage("Guest list not ready yet. Try again.");
        return;
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1920,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        setState(() {
          guestIdBytes[index] = bytes;                 // for preview
          guestIdProofs[index] = File(pickedFile.path); // for upload
        });
      }

    } catch (e) {
      _showMessage("Error picking image: $e");
    }
  }

  Future<void> _fetchPricing({String? newPricingType}) async {
    setState(() {
      loadingPrice = true;
      pricingData = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt("lodgeId");
      if (lodgeId == null) throw Exception("Lodge ID not found");

      final body = {
        "lodge_id": lodgeId,
        "room_type": widget.roomType,
        "room_name": widget.roomName,
        "check_in": widget.checkIn.toIso8601String(),
        "check_out": widget.checkOut.toIso8601String(),
        "room_count": selectedRoomNumbers.length,
      };

      if (newPricingType != null) body["pricing_type"] = newPricingType;

      final url = newPricingType != null
          ? Uri.parse("$baseUrl/calendar/update-pricing")
          : Uri.parse("$baseUrl/calendar/calculate-pricing");

      final response = await http.post(
        url,
        body: jsonEncode(body),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          pricingType = data["status"];
          pricingData = {
            "room_count": data["room_count"],
            "base_amount": data["base_amount_per_room"],
            "total_base": data["total_base_amount"],
            "gst": data["gst_amount"],
            "gst_rate": data["gst_rate"],
            "grand_total": data["total_amount"],
            "num_days": data["num_days"],
            "type": data["status"],
          };
          overriddenBaseAmount = data["base_amount_per_room"].toDouble();
        });
        _recalculatePricing();

      } else {
        _showMessage("Pricing error: ${response.body}");
      }
    } catch (e) {
      _showMessage("Error fetching pricing: $e");
    } finally {
      setState(() => loadingPrice = false);
    }
  }

  // Widget _guestsSection() {
  //   return Stack(
  //     clipBehavior: Clip.none,
  //     children: [
  //       Container(
  //         decoration: BoxDecoration(
  //           border: Border.all(color: royal, width: 1.5),
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
  //         child: Column(
  //           children: [
  //             const SizedBox(height: 10),
  //             // Number of Guests
  //             Row(
  //               children: [
  //                 const Expanded(
  //                   flex: 2,
  //                   child: Text(
  //                     "Number of Guests",
  //                     style: TextStyle(fontWeight: FontWeight.bold, color: royal),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 10),
  //                 Expanded(
  //                   flex: 3,
  //                   child: TextFormField(
  //                     initialValue: numGuests.toString(),
  //                     keyboardType: TextInputType.number,
  //                     cursorColor: royal,
  //                     style: TextStyle(color: royal),
  //                     decoration: InputDecoration(
  //                       border: OutlineInputBorder(
  //                         borderRadius: BorderRadius.circular(8),
  //                       ),
  //                       enabledBorder: OutlineInputBorder(
  //                         borderSide: BorderSide(color: royal, width: 1),
  //                         borderRadius: BorderRadius.circular(12),
  //                       ),
  //                       focusedBorder: OutlineInputBorder(
  //                         borderSide: BorderSide(color: royal, width: 2),
  //                         borderRadius: BorderRadius.circular(12),
  //                       ),
  //                       filled: true,
  //                       fillColor: royal.withValues(alpha: 0.05),
  //                       isDense: true,
  //                       contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
  //                     ),
  //
  //                     onChanged: (val) {
  //                       final count = int.tryParse(val) ?? 1;
  //                       if (count > 0) _updateGuests(count);
  //                     },
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 15),
  //             // Guest ID uploads
  //             Column(
  //               children: List.generate(numGuests, (index) {
  //                 return Padding(
  //                   padding: const EdgeInsets.symmetric(vertical: 5),
  //                   child: Row(
  //                     children: [
  //                       Flexible(
  //                         flex: 2,
  //                         child: GestureDetector(
  //                           onTap: () {
  //                             final bytes = guestIdBytes[index];
  //                             if (bytes != null) {
  //                               showDialog(
  //                                 context: context,
  //                                 builder: (_) => Dialog(
  //                                   child: ClipRRect(
  //                                     borderRadius: BorderRadius.circular(8),
  //                                     child: SizedBox(
  //                                       width: 300,
  //                                       height: 400,
  //                                       child: Image.memory(
  //                                         bytes,
  //                                         fit: BoxFit.contain,
  //                                       ),
  //                                     ),
  //                                   ),
  //                                 ),
  //                               );
  //                             } else {
  //                               _showMessage("No image selected for Guest ${index + 1}");
  //                             }
  //                           },
  //                           child: Row(
  //                             children: [
  //                               Text(
  //                                 "Guest ${index + 1} ID",
  //                                 style: const TextStyle(
  //                                     fontWeight: FontWeight.bold, color: royal),
  //                               ),
  //                               if (guestIdBytes[index] != null) ...[
  //                                 const SizedBox(width: 5),
  //                                 const Icon(Icons.preview, size: 18, color: royal),
  //                               ],
  //                             ],
  //                           ),
  //                         ),
  //                       ),
  //                       const SizedBox(width: 10),
  //                       Flexible(
  //                         flex: 3,
  //                         child: ElevatedButton(
  //                           style: ElevatedButton.styleFrom(
  //                             backgroundColor: royal,
  //                             foregroundColor: Colors.white,
  //                             minimumSize: const Size(170, 36),
  //                           ),
  //                           onPressed: () => _pickImage(index),
  //                           child: Text(
  //                             guestIdBytes[index] != null ? "Selected" : "Upload",
  //                           ),
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 );
  //               }),
  //             ),
  //           ],
  //         ),
  //       ),
  //       Positioned(
  //         top: -12,
  //         left: 0,
  //         right: 0,
  //         child: Align(
  //           alignment: Alignment.topCenter,
  //           child: Container(
  //             padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
  //             decoration: BoxDecoration(
  //               color: royal,
  //               borderRadius: BorderRadius.circular(6),
  //             ),
  //             child: const Text(
  //               "GUESTS",
  //               style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _guestsSection() {
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
            children: [
              const SizedBox(height: 10),

              // ---------------- NUMBER OF GUESTS ----------------
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
                    flex: 3,
                    child: TextFormField(
                      initialValue: numGuests.toString(),
                      keyboardType: TextInputType.number,
                      cursorColor: royal,
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
                      onChanged: (val) {
                        int newCount = int.tryParse(val) ?? 1;
                        if (newCount < 1) newCount = 1;

                        setState(() {
                          numGuests = newCount;

                          // --- If guest list is longer than new number, trim it ---
                          if (guestIdProofs.length > newCount) {
                            guestIdProofs = guestIdProofs.sublist(0, newCount);
                            guestIdBytes = guestIdBytes.sublist(0, newCount);
                          }

                          // (If the user increases guest count, do nothing —
                          // they must use + button to add new entries.)
                        });
                      },
                    ),
                  ),
                ],
              ),


              const SizedBox(height: 10),

              // ---------------- GUEST UPLOAD LIST ----------------
              Column(
                children: List.generate(guestIdProofs.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        // Guest Label with preview
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              final bytes = guestIdBytes[index];
                              if (bytes != null) {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 300,
                                        height: 400,
                                        child: Image.memory(bytes, fit: BoxFit.contain),
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                _showMessage("No image selected for Guest ${index + 1}");
                              }
                            },
                            child: Row(
                              children: [
                                Text(
                                  "Guest ${index + 1} ID",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: royal),
                                ),
                                if (guestIdBytes[index] != null) ...[
                                  const SizedBox(width: 5),
                                  const Icon(Icons.preview, size: 18, color: royal),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Upload button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: royal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(170, 36),
                            ),
                            onPressed: () => _pickImage(index),
                            child: Text(
                              guestIdBytes[index] != null ? "Selected" : "Upload",
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),


              const SizedBox(height: 12),

              // ---------------- ADD GUEST UPLOAD BUTTON ----------------
              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: guestIdProofs.length < numGuests
                      ? () {
                    setState(() {
                      guestIdBytes.add(null);
                      guestIdProofs.add(null);
                    });
                  }
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Guest ID"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    foregroundColor: Colors.white,
                  ),
                ),
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
                "GUESTS",
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
    if (selectedRoomNumbers.isEmpty) {
      _showMessage("Select at least one room.");
      return;
    }

    final validProofs = guestIdProofs.where((file) => file != null).toList();

    if (validProofs.isEmpty) {
      _showMessage("Please upload at least one guest ID proof.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    final userId = prefs.getString("userId");

    if (lodgeId == null || userId == null) {
      _showMessage("Lodge ID or User ID not found!");
      return;
    }

    setState(() => submitting = true);

    final roomCount = selectedRoomNumbers.length;
    final numDays = pricingData?["num_days"] ?? 1;
    final baseAmount = pricingData?["total_base"] ?? 0.0;
    final gstAmount = pricingData?["gst"] ?? 0.0;
    final grandTotal = pricingData?["grand_total"] ?? 0.0;
    final advance = double.tryParse(advanceController.text) ?? 0.0;
    final balanceAmount = grandTotal - advance;
    final deposite = double.tryParse(depositController.text) ?? 0.0;
    // Use MultipartRequest
    final uri = Uri.parse("$baseUrl/booking/create");
    var request = http.MultipartRequest('POST', uri);

    // Add form fields
    request.fields.addAll({
      "lodge_id": lodgeId.toString(),
      "user_id": userId,
      "name": nameController.text,
      "phone": phoneController.text,
      "alternate_phone": altPhoneController.text,
      "email": emailController.text,
      "address": addressController.text,
      "numberofguest": numGuests.toString(),
      "specification": jsonEncode({
        "number_of_days": numDays,
        "number_of_rooms": roomCount,
      }),
      "check_in": widget.checkIn.toIso8601String(),
      "check_out": widget.checkOut.toIso8601String(),
      "baseamount": baseAmount.toString(),
      "gst": gstAmount.toString(),
      "amount": grandTotal.toString(),
      "advance": advance.toString(),
      "balance": balanceAmount.toString(),
      "room_name": widget.roomName,
      "room_type": widget.roomType,
      "room_number": jsonEncode(selectedRoomNumbers),
      "deposite":deposite.toString(),
    });

    for (int i = 0; i < validProofs.length; i++) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'id_proofs',
          validProofs[i]!.path,
        ),
      );
    }

    // Debug print
    // print("Submitting booking with fields:");
    request.fields.forEach((key, value) {
      // print("$key: $value");
    });
    // print("Files:");
    // for (var f in request.files) {
    //   print(f.filename);
    // }

    // Send request
    final streamedResponse = await request.send();
    final respBody = await streamedResponse.stream.bytesToString();
    dynamic responseJson;

    try {
      responseJson = jsonDecode(respBody);
    } catch (e) {
      responseJson = {"message": respBody};
    }

    setState(() => submitting = false);

    if (streamedResponse.statusCode == 200 ||streamedResponse.statusCode == 201) {
      _showMessage(responseJson['message'] ?? 'Booking Successful!');
      if(!mounted) return;
      setState(() {
        bookingSuccess = true;
        bookingResponse = responseJson['booking']; // <-- store only booking object
      });
    } else {
      _showMessage("Booking failed: ${responseJson['message'] ?? respBody}");
    }
  }

  Widget bookingDetailsCard({
    required Map<String, dynamic> booking,
    required Color royal,
  }) {
    // Date formatting helper
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

      if (roomNumbers != null && roomNumbers.isNotEmpty) buffer.writeln(formatLine("Room Number", roomNumbers.join(', ')));

      // if (booking['numberofguest'] != null)
      //   buffer.writeln(formatLine("Guests", booking['numberofguest']));
      //
      // if (idProofs != null && idProofs.isNotEmpty)
      //   buffer.writeln(formatLine("ID Proofs", idProofs.join(', ')));
      // PAYMENT DETAILS FIRST (as you requested)
      buffer.writeln("       Payment Details");

      if (booking['baseamount'] != null) buffer.writeln(formatLine("Base Amount", booking['baseamount']));

      if (booking['gst'] != null) buffer.writeln(formatLine("GST", booking['gst']));

      if (booking['amount'] != null) buffer.writeln(formatLine("Total Amount", booking['amount']));

      if (booking['advance'] != null) buffer.writeln(formatLine("Advance", booking['advance']));

      if (booking['deposite'] != null) buffer.writeln(formatLine("Deposite", booking['deposite']));

      // TOTAL PAID = ADVANCE + DEPOSITE
      double adv = double.tryParse(booking['advance']?.toString() ?? "0") ?? 0;
      double dep = double.tryParse(booking['deposite']?.toString() ?? "0") ?? 0;
      double totalPaid = adv + dep;

      if (dep > 0) buffer.writeln(formatLine("Total Paid", totalPaid));

      if (booking['Balance'] != null) buffer.writeln(formatLine("Balance", booking['Balance']));

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
                        buildLabelValue("Name", booking['name']),
                      if (booking['phone'] != null)
                        buildLabelValue("Phone", booking['phone']),
                      if (booking['address'] != null)
                        buildLabelValue("Address", booking['address']),
                      if (alternatePhones.isNotEmpty)
                        buildLabelValue("Alt Phone", alternatePhones.join(', ')),
                      if (booking['email'] != null)
                        buildLabelValue("Email", booking['email']),
                    ],
                  ),

                const SizedBox(height: 15),
                Divider(color: royal, thickness: 1),
                const SizedBox(height: 10),

                // BOOKING INFO
                Column(
                  children: [
                    if (booking['check_in'] != null)
                      buildLabelValue("Check-in", formatDateTime(booking['check_in'])),
                    if (booking['check_out'] != null)
                      buildLabelValue("Check-out", formatDateTime(booking['check_out'])),
                    if (booking['room_name'] != null || booking['room_type'] != null)
                      buildLabelValue(
                        "Room",
                        "${booking['room_name'] ?? ''} ${booking['room_type'] ?? ''}".trim(),
                      ),
                    if (roomNumbers != null && roomNumbers.isNotEmpty)
                      buildLabelValue("Room Number", roomNumbers.join(', ')),
                    if (booking['numberofguest'] != null)
                      buildLabelValue("Guests", booking['numberofguest'].toString()),
                    if (idProofs != null && idProofs.isNotEmpty)
                      buildLabelValue("ID Proofs", idProofs.join(', ')),
                  ],
                ),

                const SizedBox(height: 15),
                Divider(color: royal, thickness: 1),
                const SizedBox(height: 10),

                // PAYMENT INFO
                Column(
                  children: [
                    if (booking['baseamount'] != null)
                      buildLabelValue("Base Amount", booking['baseamount'].toString()),
                    if (booking['gst'] != null)
                      buildLabelValue("GST", booking['gst'].toString()),
                    if (booking['amount'] != null)
                      buildLabelValue("Total Amount", booking['amount'].toString()),
                    if (booking['advance'] != null)
                      buildLabelValue("Advance", booking['advance'].toString()),
                    if (booking['deposite'] != null)
                      buildLabelValue("Deposite", booking['deposite'].toString()),
                    if (booking['deposite'] != null)
                      buildLabelValue("Total Paid",  (
                          (booking['advance'] != null ? double.tryParse(booking['advance'].toString()) ?? 0 : 0) +
                              (booking['deposite'] != null ? double.tryParse(booking['deposite'].toString()) ?? 0 : 0)
                      ).toString() ),
                    if (booking['Balance'] != null)
                      buildLabelValue("Balance", booking['Balance'].toString()),
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

  Widget _priceDetailsSection() {
    final numDays = pricingData?["num_days"] ?? 1;

    Widget pricingField({
      required String label,
      required String value,
      bool bold = false,
      bool readOnly = true,
      TextEditingController? controller,
    }) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight:FontWeight.bold,
                color: royal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: TextFormField(
              readOnly: readOnly,
              controller: controller ?? TextEditingController(text: value),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: royal,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: royal.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: royal, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: royal, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: royal, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main container
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

              // Pricing details
              loadingPrice
                  ? const Center(child: CircularProgressIndicator())
                  : pricingData == null
                  ? const Text("Failed to load pricing")
                  : Column(
                children: [
                  Row(
              children: [
              const Expanded(
              flex: 2,
                child: Text(
                  "Pricing Type",
                  style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: pricingType,
                  isExpanded: true,

                  decoration: InputDecoration(
                    filled: true,
                    fillColor: royal.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: royal, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: royal, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: royal, width: 2),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),

                  // 🔵 Your royal dropdown arrow
                  icon: Icon(Icons.arrow_drop_down, color: royal, size: 28),

                  dropdownColor: Colors.white,

                  style: const TextStyle(
                    color: royal,
                    fontWeight: FontWeight.w500,
                  ),

                  items: ["NORMAL", "PEAK_HOUR"].map(
                        (type) {
                      return DropdownMenuItem(
                        value: type,

                        // LEFT aligned text
                        alignment: Alignment.centerLeft,

                        child: Text(
                          type,
                          textAlign: TextAlign.left,
                        ),
                      );
                    },
                  ).toList(),

                  onChanged: (value) {
                    if (value != null) {
                      _fetchPricing(newPricingType: value);
                      _recalculatePricing();
                    }
                  },
                ),
              ),
            ],
          ),
                  const SizedBox(height: 10),
                  pricingField(label: "Room Count", value: "${selectedRoomNumbers.length}"),
                  const SizedBox(height: 10),
                  pricingField(label: "Number of Days", value: "$numDays"),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                          flex: 2,
                          child: Text(
                            "Base Amount\n(per room)",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: royal),
                          )),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: overriddenBaseAmount?.toStringAsFixed(2) ??
                              pricingData!["base_amount"].toStringAsFixed(2),
                          style: TextStyle(color: royal),
                          cursorColor: royal,
                          textAlign: TextAlign.right,
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: royal.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: royal, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: royal, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: royal, width: 2),
                            ),
                          ),
                          onChanged: (val) {
                            final value = double.tryParse(val);
                            if (value != null) {
                              overriddenBaseAmount = value;
                              _recalculatePricing();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  pricingField(label: "Total Base", value: "₹${pricingData!["total_base"]}"),
                  const SizedBox(height: 10),
                  pricingField(
                   label: "GST (${pricingData!["gst_rate"] ?? 18}%)",
                   value: "₹${pricingData!["gst"]}",
                  ),
                  const SizedBox(height: 10),
                  pricingField(
                  label: "Grand Total",
                  value: "₹${pricingData!["grand_total"]}",
                  bold: true,
                  ),
                ],
              ),

              const SizedBox(height: 15),
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Advance Payment",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: advanceController,
                      cursorColor: royal,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: royal),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Advance amount is required";
                        if (double.tryParse(val) == null) return "Enter a valid amount";
                        return null;
                      },

                      decoration: InputDecoration(
                        hintText: 'Enter advance amount',
                        hintStyle: TextStyle(color: royal),
                        filled: true,
                        fillColor: royal.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: royal, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: royal, width: 1)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: royal, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        double entered = double.tryParse(val) ?? 0.0;
                        double maxAdvance = pricingData?["grand_total"] ?? 0.0;

                        if (entered > maxAdvance) {
                          entered = maxAdvance;
                          advanceController.text = entered.toStringAsFixed(2);
                          advanceController.selection = TextSelection.fromPosition(
                              TextPosition(offset: advanceController.text.length));
                        }

                        _recalculatePricing();
                      },
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
                      "Deposit",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: depositController,
                      cursorColor: royal,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: royal),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Enter deposit amount',
                        hintStyle: const TextStyle(color: royal),
                        filled: true,
                        fillColor: royal.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: royal, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: royal, width: 1)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: royal, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        // double entered = double.tryParse(val) ?? 0.0;
                        // Prevent deposit > grand total
                        _recalculatePricing();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if ((double.tryParse(depositController.text) ?? 0) > 0)
                Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text(
                        "Total Amount Paid",
                        style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        readOnly: true,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: royal),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: royal.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: royal, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: royal, width: 1)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: royal, width: 2),
                          ),
                        ),
                        controller: TextEditingController(
                          text: ( (double.tryParse(advanceController.text) ?? 0.0)
                              + (double.tryParse(depositController.text) ?? 0.0) )
                              .toStringAsFixed(2),
                        ),
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
                      "Balance",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      readOnly: true,
                      style: TextStyle(color: royal),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: royal.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: royal, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: royal, width: 1)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: royal, width: 2),
                        ),
                      ),
                        controller: balanceController,
                    ),
                  ),
                ],
              ),
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
                "PRICE DETAILS",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _personalInfoSection() {
    return Stack(
      clipBehavior: Clip.none, // allow header to overflow
      children: [
        // Main container
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildRow(
                "Phone",
                phoneController,
                keyboardType: TextInputType.number,
                maxLength: 13, // +91 + 10 digits
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Phone is required";
                  // validate +countrycode and 10 digits
                  if (!RegExp(r'^\+\d{1,4}\d{10}$').hasMatch(val)) {
                    return "Include country code and exactly 10 digits";
                  }
                  return null;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\+]')), // allow digits and +
                  LengthLimitingTextInputFormatter(13),
                ],
                hideCounter: true,
              ),
              const SizedBox(height: 10),
              _buildRow("Name", nameController, validator: (val) {
                if (val == null || val.trim().isEmpty) return "Name is required";
                return null;
              }),
              const SizedBox(height: 10),
              _buildRow(
                "Alternate Phone",
                altPhoneController,
                keyboardType: TextInputType.number,
                inputFormatters: [AlternatePhoneFormatter()],
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    final numbers = val.split(',');
                    for (var n in numbers) {
                      if (n.length != 10) return "Each phone must be 10 digits";
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _buildRow("Address", addressController, validator: (val) {
                if (val == null || val.trim().isEmpty) return "Address is required";
                return null;
              }),
              const SizedBox(height: 10),
              _buildRow(
                "Email",
                emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}').hasMatch(val)) {
                      return "Enter valid email";
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),

        // Floating centered header
        Positioned(
          top: -12, // overlap border
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
                "PERSONAL INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bookingInfoSection() {
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
                  "${widget.roomType} - ${widget.roomName}",
                  style: const TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                      initialValue: formatTo12Hour(widget.checkIn),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
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
                      initialValue: formatTo12Hour(widget.checkOut),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // Room type & name centered
              Center(
                child: Text(
                  "Room Numbers",
                  style: const TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Selected Rooms centered
              Center(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: selectedRoomNumbers
                      .map((n) => Chip(
                    label: Text(n, style: const TextStyle(color: Colors.white)),
                    backgroundColor: royal,
                  ))
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

  void _recalculatePricing() {
    if (pricingData == null) return;

    final roomCount = selectedRoomNumbers.length;
    final numDays = pricingData!["num_days"] ?? 1;
    final baseAmount = overriddenBaseAmount ?? pricingData!["base_amount"];
    final totalBase = baseAmount * roomCount * numDays;
    final gstRate = pricingData!["gst_rate"] ?? 18;
    final gstAmount = double.parse((totalBase * gstRate / 100).toStringAsFixed(2));
    final grandTotal = double.parse((totalBase + gstAmount).toStringAsFixed(2));

    final advance = double.tryParse(advanceController.text) ?? 0.0;

    setState(() {
      pricingData!["base_amount"] = baseAmount;
      pricingData!["total_base"] = totalBase;
      pricingData!["gst"] = gstAmount;
      pricingData!["grand_total"] = grandTotal;

      balance = grandTotal - advance;

      // 🔥 Very important — update controller here
      balanceController.text = balance.toStringAsFixed(2);
    });
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: royal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: royal, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: royal.withValues(alpha:0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              color: Colors.white, // 👈 soft teal background
              child: const Icon(
                Icons.home_work_rounded,
                color: royal,
                size: 35,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                hall['name']?.toString().toUpperCase() ?? "LODGE NAME",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
      String label,
      TextEditingController controller, {
        TextInputType keyboardType = TextInputType.text,
        int? maxLength,
        String? Function(String?)? validator,
        bool hideCounter = false,
        List<TextInputFormatter>? inputFormatters,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text(label, style: const TextStyle(color: royal,fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            cursorColor: royal,
            style: TextStyle(color: royal),
            validator: validator,
            decoration: _inputDecoration(
              label: label,
              counterText: hideCounter ? '' : null, // hide counter if true
            ),
          ),
        ),
      ],
    );
  }


  Future<void> _fetchBookingByPhone(String phone) async {
    if (phone.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt("lodgeId");
      if (lodgeId == null) return;

      final url = Uri.parse("$baseUrl/booking/latest/$lodgeId/$phone");

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data != null) {
          setState(() {
            nameController.text = data["name"] ?? "";
            addressController.text = data["address"] ?? "";
            altPhoneController.text = data["alternate_phone"] ?? "";
            emailController.text = data["email"] ?? "";
          });
        }
      }
    } catch (e) {
      _showMessage("Error fetching previous booking: $e");
    }
  }

  InputDecoration _inputDecoration({required String label, String? counterText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: royal),
      filled: true,
      fillColor: royal.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide:
        const BorderSide(color: Colors.redAccent, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide:
        const BorderSide(color: Colors.redAccent, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      counterText: counterText, // here
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false, // prevent default pop
        onPopInvokedWithResult: (didPop, res) {
          if (!didPop) {
            _handleBackNavigation();
          }
        },
        child: Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Room Booking", style: TextStyle(color: Colors.white)),
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
          child: bookingSuccess && bookingResponse != null
              ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hallDetails != null) _buildHallCard(hallDetails!),
                const SizedBox(height: 20),

                bookingDetailsCard(booking: bookingResponse!, royal: royal),
                const SizedBox(height: 70),
              ],
            ),
          )
          :SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hallDetails != null)
                _buildHallCard(hallDetails!),
              const SizedBox(height: 40),
              _personalInfoSection(),
              const SizedBox(height: 40),
              _bookingInfoSection(),
              const SizedBox(height: 40),
              _guestsSection(),
              const SizedBox(height: 40),
              _priceDetailsSection(),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: royal),
                  onPressed: submitting ? null : _bookRooms,
                  child: submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Confirm Booking", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 70),
            ],
          ),
        ),
      ),
      ),
    )
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
