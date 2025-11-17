// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:flutter/services.dart';
// import '../../public/config.dart';
// import '../../utils/alternate_phone formatter.dart';
// import 'pdf/booking_pdf_generator.dart';
// import '../../utils/date_time_range_picker.dart';
// import '../../utils/tamil_date_utils.dart';
// // import 'calendar_page.dart';
// import '../../public/main_navigation.dart';
//
// class BookingPage extends StatefulWidget {
//   final DateTime selectedDate;
//   const BookingPage({super.key, required this.selectedDate});
//
//   @override
//   State<BookingPage> createState() => _BookingPageState();
// }
//
// class _BookingPageState extends State<BookingPage> {
//   final _formKey = GlobalKey<FormState>();
//
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController addressController = TextEditingController();
//   final TextEditingController altPhoneController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController rentController = TextEditingController();
//   final TextEditingController advanceController = TextEditingController();
//   final TextEditingController fromController = TextEditingController();
//   final TextEditingController toController = TextEditingController();
//   final TextEditingController customEventController = TextEditingController();
//   final TextEditingController tamilDateController = TextEditingController();
//   final TextEditingController tamilMonthController = TextEditingController();
//
//   String? selectedEventType;
//   final List<String> eventTypes = [
//     "Marriage",
//     "Engagement",
//     "Reception",
//     "Meeting",
//     "Other"
//   ];
//   final List<String> tamilMonths = [
//     "சித்திரை",
//     "வைகாசி",
//     "ஆனி",
//     "ஆடி",
//     "ஆவணி",
//     "புரட்டாசி",
//     "ஐப்பசி",
//     "கார்த்திகை",
//     "மார்கழி",
//     "தை",
//     "மாசி",
//     "பங்குனி"
//   ];
//
//
//   bool _loading = false;
//   bool _showPdfButton = false;
//   Map<String, dynamic>? _lastBooking;
//   Map<String, dynamic>? _hallDetails;
//   String? selectedTamilMonth;
//   bool overrideTamilMonth = false; // to track if user wants to change month
//
//   List<Map<String, DateTime>> bookedRanges = [];
//   List<DateTime> fullyBookedDates = [];
//
//   final Color oliveGreen = const Color(0xFF5B6547);
//   final Color tan = const Color(0xFFD8C9A9);
//   final Color beigeBackground = const Color(0xFFECE6D1);
//
//   @override
//   void initState() {
//     super.initState();
//     _setDefaultAllotment();
//     _loadRent();
//     _loadBookedRanges();
//     _fetchHallDetails();
//     phoneController.addListener(_onPhoneChanged);
//
//     final tamilData = TamilDateUtils.getTamilDate(widget.selectedDate);
//     tamilDateController.text = tamilData['tamilDate']!;
//     tamilMonthController.text = tamilData['tamilMonth']!;
//     selectedTamilMonth = tamilData['tamilMonth'];
//     tamilMonthController.text = selectedTamilMonth!;
//
//   }
//
//   void _onPhoneChanged() {
//     final phone = phoneController.text;
//     if (phone.length == 10) {
//       _fetchCustomerDetails(phone);
//     }
//   }
//
//   void _setDefaultAllotment() {
//     final fromDefault = DateTime(widget.selectedDate.year,
//         widget.selectedDate.month, widget.selectedDate.day - 1, 17, 0);
//     final toDefault = DateTime(widget.selectedDate.year,
//         widget.selectedDate.month, widget.selectedDate.day, 17, 0);
//     fromController.text =
//         DateFormat('yyyy-MM-dd hh:mm a').format(fromDefault);
//     toController.text = DateFormat('yyyy-MM-dd hh:mm a').format(toDefault);
//   }
//
//   Future<void> _fetchHallDetails() async {
//     final prefs = await SharedPreferences.getInstance();
//     final hallId = prefs.getInt('hallId');
//     if (hallId == null) return;
//     try {
//       final res = await http.get(Uri.parse('$baseUrl/halls/$hallId'));
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         setState(() {
//           _hallDetails = data;
//         });
//       }
//       final instrRes =
//       await http.get(Uri.parse('$baseUrl/instructions/hall/$hallId'));
//       if (instrRes.statusCode == 200) {
//         final instrData = jsonDecode(instrRes.body) as List;
//         final instructions =
//         instrData.map((i) => i['instruction'].toString()).toList();
//
//         setState(() {
//           if (_hallDetails != null) {
//             _hallDetails!['instructions'] = instructions;
//           }
//         });
//       }
//     } catch (e) {
//       debugPrint("Error fetching hall details or instructions: $e");
//     }
//   }
//
//   Future<void> _showValidationDialog(String message) async {
//     showDialog(
//       context: context,
//       builder: (ctx) {
//         return AlertDialog(
//           backgroundColor: beigeBackground,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//             side: BorderSide(color: oliveGreen, width: 1.5),
//           ),
//           title: Text(
//             "Invalid Input",
//             style: TextStyle(
//               color: oliveGreen,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           content: Text(
//             message,
//             style: TextStyle(
//               color: oliveGreen,
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(ctx); // ✅ Close only the dialog
//               },
//               style: TextButton.styleFrom(
//                 backgroundColor: oliveGreen,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//               ),
//               child: Text(
//                 "OK",
//                 style: TextStyle(
//                   color: tan,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Future<void> _loadBookedRanges() async {
//     final prefs = await SharedPreferences.getInstance();
//     final hallId = prefs.getInt('hallId');
//     if (hallId == null) return;
//     try {
//       final res = await http.get(Uri.parse('$baseUrl/bookings/$hallId'));
//       if (res.statusCode == 200) {
//         final List data = jsonDecode(res.body);
//         final Map<String, int> bookingCount = {};
//         List<Map<String, DateTime>> ranges = [];
//         for (var b in data) {
//           final from = DateTime.parse(b['alloted_datetime_from']);
//           final to = DateTime.parse(b['alloted_datetime_to']);
//           ranges.add({"from": from, "to": to});
//           final dayKey = DateFormat('yyyy-MM-dd').format(from);
//           bookingCount[dayKey] = (bookingCount[dayKey] ?? 0) + 1;
//         }
//         final fullyBooked = bookingCount.entries
//             .where((e) => e.value >= 3)
//             .map((e) => DateFormat('yyyy-MM-dd').parse(e.key))
//             .toList();
//
//         setState(() {
//           bookedRanges = ranges;
//           fullyBookedDates = fullyBooked;
//         });
//       }
//     } catch (e) {
//       debugPrint("Error loading booked ranges: $e");
//     }
//   }
//
//   Future<void> _loadRent() async {
//     final prefs = await SharedPreferences.getInstance();
//     final hallId = prefs.getInt('hallId');
//     if (hallId == null) return;
//     final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
//     try {
//       final calRes = await http.get(Uri.parse('$baseUrl/calendar/$hallId'));
//       bool isPeakDay = false;
//       if (calRes.statusCode == 200) {
//         final calData = jsonDecode(calRes.body);
//         final dayEntry = calData[dateStr];
//         if (dayEntry != null &&
//             dayEntry['peakHours'] != null &&
//             dayEntry['peakHours'].isNotEmpty) {
//           isPeakDay = true;
//         }
//       }
//       final defaultRes =
//       await http.get(Uri.parse('$baseUrl/default-values/$hallId'));
//       if (defaultRes.statusCode == 200) {
//         final defaults = jsonDecode(defaultRes.body);
//         Map<String, dynamic>? rentValue;
//         if (isPeakDay) {
//           rentValue = defaults.firstWhere(
//                 (d) => d['reason'].toString().toLowerCase() == 'peak hours',
//             orElse: () => null,
//           );
//         } else {
//           rentValue = defaults.firstWhere(
//                 (d) => d['reason'].toString().toLowerCase() == 'rent',
//             orElse: () => null,
//           );
//         }
//         if (rentValue != null) {
//           rentController.text = rentValue['amount'].toString();
//         }
//       }
//     } catch (e) {
//       debugPrint("Error fetching rent: $e");
//     }
//   }
//
//   Future<void> _submitBooking() async {
//     if (!_formKey.currentState!.validate()) {
//       // Find the first invalid field and show dialog
//       if (phoneController.text.isEmpty || phoneController.text.length != 10) {
//         _showValidationDialog("Please enter a valid 10-digit phone number.");
//         return;
//       }
//
//       if (nameController.text.isEmpty) {
//         _showValidationDialog("Please enter the customer's name.");
//         return;
//       }
//
//       if (addressController.text.isEmpty) {
//         _showValidationDialog("Please enter the address.");
//         return;
//       }
//
//       if (selectedEventType == null || selectedEventType!.isEmpty) {
//         _showValidationDialog("Please select an event type.");
//         return;
//       }
//
//       if (selectedEventType == "Other" && customEventController.text.isEmpty) {
//         _showValidationDialog("Please enter a custom event type.");
//         return;
//       }
//
//       if (emailController.text.isNotEmpty &&
//           !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
//               .hasMatch(emailController.text.trim())) {
//         _showValidationDialog("Please enter a valid email address.");
//         return;
//       }
//
//       if (altPhoneController.text.isNotEmpty) {
//         final rawNumbers = altPhoneController.text
//             .split(RegExp(r'[,\s]+'))
//             .map((e) => e.trim())
//             .where((e) => e.isNotEmpty)
//             .toList();
//
//         for (var num in rawNumbers) {
//           if (num.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(num)) {
//             _showValidationDialog("Invalid alternate phone number: $num");
//             return;
//           }
//         }
//       }
//       return; // Stop submission if invalid
//     }
//     setState(() => _loading = true);
//     final prefs = await SharedPreferences.getInstance();
//     final hallId = prefs.getInt('hallId');
//     final userId = prefs.getInt('userId');
//     if (hallId == null || userId == null) {
//       _showSnackBar("Hall ID or User ID not found");
//       setState(() => _loading = false);
//       return;
//     }
//     final rent = double.tryParse(rentController.text) ?? 0;
//     final advance = double.tryParse(advanceController.text) ?? 0;
//     final balance = rent - advance;
//     List<String> alternatePhones = [];
//     if (altPhoneController.text.isNotEmpty) {
//       final rawNumbers = altPhoneController.text
//           .split(RegExp(r'[,\s]+'))
//           .map((e) => e.trim())
//           .where((e) => e.isNotEmpty)
//           .toList();
//       for (var num in rawNumbers) {
//         if (num.length == 10 && RegExp(r'^[0-9]{10}$').hasMatch(num)) {
//           alternatePhones.add('+91$num');
//         } else {
//           _showSnackBar("Invalid alternate phone number: $num");
//           setState(() => _loading = false);
//           return;
//         }
//       }
//     }
//     final payload = {
//       "hall_id": hallId,
//       "user_id": userId,
//       "function_date": DateFormat('yyyy-MM-dd').format(widget.selectedDate),
//       "alloted_datetime_from": fromController.text,
//       "alloted_datetime_to": toController.text,
//       "name": nameController.text,
//       "phone": phoneController.text.length == 10
//           ? '+91${phoneController.text}'
//           : phoneController.text,
//       "address": addressController.text,
//       "alternate_phone": alternatePhones,
//       "email": emailController.text.isNotEmpty ? emailController.text : null,
//       "rent": rent,
//       "advance": advance,
//       "balance": balance,
//       "event_type": selectedEventType == "Other"
//           ? customEventController.text
//           : selectedEventType,
//       "tamil_date": tamilDateController.text,
//       "tamil_month": tamilMonthController.text,
//     };
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/bookings'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(payload),
//       );
//       if (response.statusCode == 201) {
//         final data = jsonDecode(response.body);
//         _showSnackBar("Booking created successfully!");
//         setState(() {
//           _lastBooking = {
//             ...payload,
//             "booking_id": data['booking_id'] ?? data['id'],
//           };
//           _showPdfButton = true;
//         });
//       } else {
//         final error = jsonDecode(response.body);
//         _showSnackBar("Error: ${error['message']}");
//       }
//     } catch (e) {
//       _showSnackBar("Error: $e");
//     }
//     setState(() => _loading = false);
//   }
//
//   void _showSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           message,
//           style: TextStyle(
//             color: oliveGreen,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         backgroundColor: tan,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//           side: BorderSide(
//             color: oliveGreen, // ✅ Olive green border
//             width: 1, // Border thickness
//           ),
//       ),
//     ),
//     );
//   }
//
//   Widget _sectionContainer(String title, List<Widget> children) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(12),
//       margin: const EdgeInsets.only(bottom: 16),
//       decoration: BoxDecoration(
//         color: beigeBackground,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: oliveGreen, width: 1.5),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 10),
//             decoration: BoxDecoration(
//               color: oliveGreen,
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Center(
//               child: Text(
//                 title,
//                 style: TextStyle(
//                   color: tan,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           ...children,
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     nameController.dispose();
//     phoneController.dispose();
//     addressController.dispose();
//     altPhoneController.dispose();
//     emailController.dispose();
//     rentController.dispose();
//     advanceController.dispose();
//     fromController.dispose();
//     toController.dispose();
//     customEventController.dispose();
//     tamilDateController.dispose();
//     tamilMonthController.dispose();
//     super.dispose();
//   }
//
//   Widget _plainRowWithTanValue(String label, Widget valueWidget) {
//     final screenWidth = MediaQuery.of(context).size.width;
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             width: screenWidth * 0.35, // 35% of screen width
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: beigeBackground,
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Text(
//               label,
//               style: TextStyle(
//                 color: oliveGreen,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 14,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//
//           Container(
//             width: screenWidth * 0.42, // 55% of screen width
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: tan,
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: valueWidget,
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final formattedDate = DateFormat('dd-MM-yyyy').format(widget.selectedDate);
//     return  WillPopScope(
//         onWillPop: () async {
//           Navigator.pop(context, true); // send refresh signal
//           return false; // prevent default pop (we already did it)
//         },child:Scaffold(
//       backgroundColor: beigeBackground,
//       appBar: AppBar(
//         backgroundColor: oliveGreen,
//         iconTheme: IconThemeData(color: tan),
//         title: Text(
//           "Hall Booking",
//           style: TextStyle(color: tan, fontWeight: FontWeight.bold),
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.home, color: tan),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
//               );
//             },
//           ),
//         ],
//       ),
//       body: _loading
//           ? Center(child: CircularProgressIndicator(color: oliveGreen))
//           : SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   width: double.infinity,
//                   padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
//                   margin: const EdgeInsets.only(bottom: 20),
//                   decoration: BoxDecoration(
//                     color: oliveGreen,
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Flexible(
//                         fit: FlexFit.tight,
//                         child: Text(
//                           _hallDetails?['name']?.toUpperCase() ?? "HALL NAME",
//                           style: TextStyle(
//                             color: tan,
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 1.1,
//                             height: 1.2,
//                           ),
//                           maxLines: 2,
//                           softWrap: true,
//                         ),
//                       ),
//                       if (_hallDetails?['logo'] != null && _hallDetails!['logo'].isNotEmpty)
//                         CircleAvatar(
//                           radius: 30,
//                           backgroundColor: tan.withValues(alpha: 0.2),
//                           backgroundImage: MemoryImage(
//                             base64Decode(_hallDetails!['logo']),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 if (_showPdfButton && _lastBooking != null && _hallDetails != null)
//                   Center(
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 90), // some breathing space
//                       child: Column(
//                         mainAxisSize: MainAxisSize.max, // centers tightly around content
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           _sectionContainer("GENERATE BILL", [
//                             Padding(
//                               padding: const EdgeInsets.only(bottom: 12),
//                               child: Text(
//                                 "Generate the bill and view it as a PDF document.",
//                                 style: TextStyle(
//                                   color: oliveGreen,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                             Center(
//                               child: SizedBox(
//                                 width: 220,
//                                 child: ElevatedButton.icon(
//                                   onPressed: () {
//                                     // print("Booking Data: $_lastBooking");
//                                     // print("Hall Details: $_hallDetails");
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (_) => BookingPdfPage(
//                                           bookingData: _lastBooking!,
//                                           hallDetails: _hallDetails!,
//                                           oliveGreen: oliveGreen,
//                                           tan: tan,
//                                           beigeBackground: beigeBackground,
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                   icon: const Icon(Icons.picture_as_pdf, size: 20),
//                                   label: const Text(
//                                     "Generate Bill & View PDF",
//                                     textAlign: TextAlign.center,
//                                     style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
//                                   ),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: oliveGreen,
//                                     foregroundColor: tan,
//                                     padding: const EdgeInsets.symmetric(vertical: 14),
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(10),
//                                     ),
//                                     elevation: 3,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ]),
//                         ],
//                       ),
//                     ),
//                   ),
//                 const SizedBox(height: 20),
//                 if (!_showPdfButton)
//                   Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             margin: const EdgeInsets.only(bottom: 20),
//             decoration: BoxDecoration(
//               color: beigeBackground,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: oliveGreen, width: 1.5),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//
//                 _sectionHeader("PERSONAL INFORMATION"),
//                 const SizedBox(height: 8),
//                 _plainRowWithTanValue(
//                   "PHONE",
//                   TextFormField(
//                     controller: phoneController,
//                     keyboardType: TextInputType.number,
//                     inputFormatters: [
//                       FilteringTextInputFormatter.digitsOnly,
//                       LengthLimitingTextInputFormatter(10),
//                     ],
//                     style: TextStyle(
//                       color: oliveGreen,
//                       fontWeight: FontWeight.w600,
//                       fontSize: 16,
//                     ),
//                     decoration: InputDecoration(
//                       hintText: 'Enter phone number',
//                       hintStyle: TextStyle(color: oliveGreen.withValues(alpha: 0.7)), // same as other fields
//                       border: InputBorder.none,
//                       isDense: true,
//                       contentPadding: EdgeInsets.zero,
//                     ),
//                   ),
//                 ),
//                 _plainRowWithTanValue(
//                   "NAME",
//                   TextFormField(
//                     controller: nameController,
//                     readOnly: _showPdfButton,
//                     style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
//                     decoration: InputDecoration(
//                       border: InputBorder.none,
//                       hintText: "Enter name",
//                       isDense: true,
//                       hintStyle: TextStyle(color: oliveGreen.withValues(alpha:0.7)),
//                       contentPadding: EdgeInsets.zero,
//                     ),
//                     validator: (value) {
//                       if (value == null || value.trim().isEmpty) {
//                         return "Name is required";
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//                 _plainRowWithTanValue(
//                   "ADDRESS",
//                   TextFormField(
//                     controller: addressController,
//                     readOnly: _showPdfButton,
//                     style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
//                     decoration: InputDecoration(
//                       border: InputBorder.none,
//                       hintText: "Enter address",
//                       isDense: true,
//                       contentPadding: EdgeInsets.zero,
//                       hintStyle: TextStyle(color: oliveGreen.withValues(alpha:0.7)),
//                     ),
//                     validator: (value) {
//                       if (value == null || value.trim().isEmpty) {
//                         return "Address is required";
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//                 if (altPhoneController.text.isNotEmpty || !_showPdfButton)
//                   // _plainRowWithTanValue(
//                   //   "ALTERNATE PHONE",
//                   //   TextFormField(
//                   //     controller: altPhoneController,
//                   //     keyboardType: TextInputType.phone,
//                   //     inputFormatters: [AlternatePhoneFormatter()],
//                   //     readOnly: _showPdfButton,
//                   //     style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
//                   //     decoration: InputDecoration(
//                   //       border: InputBorder.none,
//                   //       hintText: "Enter alternate phones (comma separated)",
//                   //       hintStyle: TextStyle(color: oliveGreen.withValues(alpha:0.7)),
//                   //       isDense: true,
//                   //       contentPadding: EdgeInsets.zero,
//                   //     ),
//                   //     validator: (value) {
//                   //       return null;
//                   //     },
//                   //   ),
//                   // ),
//                // ],
//             ),
//           ),
//                 if (!_showPdfButton)
//                   const SizedBox(height: 18),
//                 if (!_showPdfButton)
//                   Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             margin: const EdgeInsets.only(bottom: 20),
//             decoration: BoxDecoration(
//               color: beigeBackground,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: oliveGreen, width: 1.5),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _sectionHeader("BOOKING INFORMATION"),
//                 const SizedBox(height: 12),
//                   _plainRowWithTanValue(
//                     "BOOKING DATE",
//                     Container(
//                       alignment: Alignment.center, // <-- center horizontally & vertically
//                       child: Text(
//                         formattedDate,
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           color: oliveGreen,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                   ),
//
//                 const SizedBox(height: 20),
//                 // Event Type Dropdown Row
//                 _plainRowWithTanValue(
//                   "EVENT TYPE",
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: tan.withValues(alpha:0.2),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: _showPdfButton
//                         ? Text(
//                       selectedEventType ?? "",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: oliveGreen, fontSize: 16, fontWeight: FontWeight.w600),
//                     )
//                         : DropdownButtonFormField<String>(
//                       initialValue: selectedEventType,
//                       isExpanded: true,
//                       items: eventTypes
//                           .map((e) => DropdownMenuItem(
//                         value: e,
//                         child: Center(
//                           child: Text(
//                             e,
//                             style: TextStyle(color: oliveGreen, fontSize: 16),
//                           ),
//                         ),
//                       ))
//                           .toList(),
//                       onChanged: (val) {
//                         setState(() {
//                           selectedEventType = val;
//                           if (val != "Other") customEventController.text = "";
//                         });
//                       },
//                       hint: Center(
//                         child: Text(
//                           "Select a..",
//                           style: TextStyle(color: oliveGreen.withValues(alpha:0.7)),
//                         ),
//                       ),
//                       decoration: const InputDecoration(
//                         border: InputBorder.none,
//                         isDense: true,
//                         contentPadding: EdgeInsets.zero,
//                       ),
//                       dropdownColor: beigeBackground,
//                       validator: (val) {
//                         if (val == null || val.isEmpty) return "Please select an event type";
//                         return null;
//                       },
//                     ),
//                   ),
//                 ),
//                 if (selectedEventType == "Other")
//                   _plainRowWithTanValue(
//                     "CUSTOM EVENT",
//                     TextFormField(
//                       controller: customEventController,
//                       style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
//                       decoration: InputDecoration(
//                         border: InputBorder.none,
//                         hintText: "Enter custom event",
//                         hintStyle: TextStyle(color: oliveGreen.withValues(alpha:0.7)),
//                         filled: true,
//                         fillColor: tan.withValues(alpha:0.2),
//                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                       ),
//                     ),
//                   ),
//                 _plainRowWithTanValue(
//                   "TAMIL DATE",
//                   TextFormField(
//                     controller: tamilDateController,
//                     style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
//                     readOnly: _showPdfButton,
//                     decoration: InputDecoration(
//                       border: InputBorder.none,
//                       hintText: "Enter Tamil date (optional)",
//                       hintStyle: TextStyle(color: oliveGreen.withValues(alpha:0.7)),
//                       filled: true,
//                       fillColor: tan.withValues(alpha:0.2),
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                     ),
//                   ),
//                 ),
//                 _plainRowWithTanValue(
//                   "TAMIL MONTH",
//                   _showPdfButton
//                       ? Text(
//                     selectedTamilMonth ?? "",
//                     style: TextStyle(
//                       color: oliveGreen,
//                       fontWeight: FontWeight.w600,
//                       fontSize: 16,
//                     ),
//                     textAlign: TextAlign.center,
//                     overflow: TextOverflow.ellipsis, // ✅ prevent overflow
//                   )
//                       : Wrap( // ✅ ensures the dropdown fits
//                     children:[ DropdownButtonFormField<String>(
//
//                       initialValue: selectedTamilMonth,
//                       isExpanded: true,
//                       items: tamilMonths
//                           .map((month) => DropdownMenuItem(
//                         value: month,
//                         child: Text(
//                           month,
//                           style: TextStyle(color: oliveGreen, fontSize: 16),
//                           overflow: TextOverflow.ellipsis, // ✅ prevent overflow
//                         ),
//                       ))
//                           .toList(),
//                       onChanged: (val) {
//                         setState(() {
//                           selectedTamilMonth = val;
//                           tamilMonthController.text = val ?? "";
//                           overrideTamilMonth = true;
//                         });
//                       },
//                       hint: Text(
//                         "Select Tamil month",
//                         style: TextStyle(color: oliveGreen.withValues(alpha:0.7)),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       decoration: InputDecoration(
//                         border: InputBorder.none,
//                         isDense: true,
//                         contentPadding: EdgeInsets.zero,
//                         filled: true,
//                         fillColor: tan.withValues(alpha:0.2),
//                       ),
//                       dropdownColor: beigeBackground,
//                     ),
//                   ]),
//                 ),
//
//                 _plainRowWithTanValue(
//                   "ALLOTED FROM",
//                   GestureDetector(
//                     onTap: _pickFrom,
//                     child: Container(
//                       width: double.infinity,
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         mainAxisAlignment: MainAxisAlignment.center, // center vertically
//                         crossAxisAlignment: CrossAxisAlignment.center, // center horizontally
//                         children: [
//                           Text(
//                             DateFormat('dd-MM-yyyy').format(
//                               DateFormat('yyyy-MM-dd hh:mm a').parse(fromController.text),
//                             ),
//                             style: TextStyle(
//                               color: oliveGreen,
//                               fontWeight: FontWeight.w700,
//                               fontSize: 16,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             DateFormat('hh:mm a').format(
//                               DateFormat('yyyy-MM-dd hh:mm a').parse(fromController.text),
//                             ),
//                             style: TextStyle(
//                               color: oliveGreen,
//                               fontWeight: FontWeight.w700,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 _plainRowWithTanValue(
//                   "ALLOTED TO",
//                   GestureDetector(
//                     onTap: _pickTo,
//                     child: Container(
//                       width: double.infinity,
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         mainAxisAlignment: MainAxisAlignment.center, // center vertically
//                         crossAxisAlignment: CrossAxisAlignment.center, // center horizontally
//                         children: [
//                           Text(
//                             DateFormat('dd-MM-yyyy').format(
//                               DateFormat('yyyy-MM-dd hh:mm a').parse(toController.text),
//                             ),
//                             style: TextStyle(
//                               color: oliveGreen,
//                               fontWeight: FontWeight.w700,
//                               fontSize: 16,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             DateFormat('hh:mm a').format(
//                               DateFormat('yyyy-MM-dd hh:mm a').parse(toController.text),
//                             ),
//                             style: TextStyle(
//                               color: oliveGreen,
//                               fontWeight: FontWeight.w700,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//           ],
//             ),
//           ),
//                 if (!_showPdfButton)
//                   const SizedBox(height: 12),
//                 if (!_showPdfButton)
//                   Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             margin: const EdgeInsets.only(bottom: 20),
//             decoration: BoxDecoration(
//               color: beigeBackground,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: oliveGreen, width: 1.5),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _sectionHeader("PAYMENT DETAILS"),
//                 const SizedBox(height: 8),
//                 _plainRowWithTanValue(
//                   "RENT",
//                   TextFormField(
//                     controller: rentController,
//                     keyboardType: TextInputType.number,
//                     readOnly: _showPdfButton,
//                     style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
//                     decoration: InputDecoration(
//                       border: InputBorder.none,
//                       hintText: "Enter rent amount",
//                       hintStyle: TextStyle(color: oliveGreen.withValues(alpha:0.7)),
//                       isDense: true,
//                       contentPadding: EdgeInsets.zero,
//                     ),
//                     validator: (value) {
//                       if (value == null || value.trim().isEmpty) {
//                         return "Rent amount is required";
//                       } else if (double.tryParse(value.trim()) == null) {
//                         return "Enter a valid number";
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//                 _plainRowWithTanValue(
//                   "ADVANCE",
//                   TextFormField(
//                     controller: advanceController,
//                     keyboardType: TextInputType.number,
//                     readOnly: _showPdfButton,
//                     style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
//                     decoration: InputDecoration(
//                       border: InputBorder.none,
//                       hintText: "Enter advance amount",
//                       hintStyle: TextStyle(color: oliveGreen.withValues(alpha:0.7)),
//                       isDense: true,
//                       contentPadding: EdgeInsets.zero,
//                     ),
//                     validator: (value) {
//                       if (value == null || value.trim().isEmpty) {
//                         return "Advance amount is required";
//                       } else if (double.tryParse(value.trim()) == null) {
//                         return "Enter a valid number";
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//                 ],
//             ),
//           ),
//                 if (!_showPdfButton)
//                   const SizedBox(height: 24),
//
//                 if (_showPdfButton)
//                   const SizedBox(height: 12),
//                 if (!_showPdfButton)
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton.icon(
//                     onPressed: _showPdfButton
//                         ? null
//                         : () async {
//                       final name = nameController.text.trim();
//                       final advanceAmount = advanceController.text.trim();
//
//                       if (name.isEmpty) {
//                         _showSnackBar("Please enter the name");
//                         return;
//                       }
//                       if (advanceAmount.isEmpty) {
//                         _showSnackBar("Please enter the advance amount");
//                         return;
//                       }
//
//                       // Step 1: Choose Payment Method
//                       final paymentMethod = await showDialog<String>(
//                         context: context,
//                         builder: (context) => AlertDialog(
//                           alignment: Alignment.center,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                           backgroundColor: beigeBackground,
//                           titlePadding: const EdgeInsets.only(top: 15), // tighter spacing
//                           title: Center(
//                             child: Text(
//                               "Choose Payment Method",
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: oliveGreen,
//                                 fontSize: 18,
//                               ),
//                             ),
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                           content: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               ElevatedButton.icon(
//                                 icon: const Icon(Icons.money, size: 18),
//                                 onPressed: () => Navigator.pop(context, 'Cash'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: tan,
//                                   foregroundColor: oliveGreen,
//                                   minimumSize: const Size(85, 36),
//                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                                 label: const Text(
//                                   "Cash",
//                                   style: TextStyle(fontSize: 14),
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               ElevatedButton.icon(
//                                 icon: const Icon(Icons.account_balance_wallet, size: 18),
//                                 onPressed: () => Navigator.pop(context, 'Online'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: oliveGreen,
//                                   foregroundColor: tan,
//                                   minimumSize: const Size(85, 36),
//                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                                 label: const Text(
//                                   "Online",
//                                   style: TextStyle(fontSize: 14),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                       final rent = double.tryParse(rentController.text) ?? 0;
//                       final advance = double.tryParse(advanceAmount.toString()) ?? 0;
//                       final balance = rent - advance;
//                       // print("Balance: ₹${balance.toInt()}");
//
//
//                       if (paymentMethod == null) return;
//
//                       // Step 2: Confirm Payment
//                       await showDialog(
//                         context: context,
//                         builder: (context) => AlertDialog(
//                           alignment: Alignment.center,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                           backgroundColor: beigeBackground,
//                           titlePadding: const EdgeInsets.only(top: 15),
//                           title: Center(
//                             child: Text(
//                               "Confirm Payment",
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: oliveGreen,
//                                 fontSize: 18,
//                               ),
//                             ),
//                           ),
//                           content: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             _infoRow("Name", name, oliveGreen),
//                             _infoRow("Function Date", formattedDate, oliveGreen),
//                             _infoRow("Tamil Date", "${tamilDateController.text}, ${tamilMonthController.text}", oliveGreen),
//                             _infoRow("Rent", "₹$rent", oliveGreen),
//                             _infoRow("Advance", "₹$advanceAmount", oliveGreen),
//                             _infoRow("Balance", "₹${balance.toStringAsFixed(0)}", oliveGreen),
//                             _infoRow("Method", paymentMethod, oliveGreen),
//                             const SizedBox(height: 10),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                             children: [
//                               // Cancel Button
//                               ElevatedButton.icon(
//                                 icon: const Icon(Icons.cancel_outlined, size: 16),
//                                 onPressed: () {
//                                   Navigator.pop(context); // 👈 just closes the dialog
//                                 },
//                                 label: const Text(
//                                   "Cancel",
//                                   // style: TextStyle(fontSize: 15),
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: tan,
//                                   foregroundColor: oliveGreen,
//                                   minimumSize: const Size(70, 30), // 👈 smaller button width & height
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(width: 5),
//                               ElevatedButton.icon(
//                               icon: const Icon(Icons.check_circle_outline, size: 16),
//                               onPressed: () {
//                                 Navigator.pop(context);
//                                 // print("Payment confirmed: $paymentMethod - ₹$advanceAmount by $name");
//                                 _submitBooking();
//                               },
//                               label: const Text(
//                                 "Confirm",
//                                 // style: TextStyle(fontSize: 15),
//                               ),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: oliveGreen,
//                                 foregroundColor: tan,
//                                 minimumSize: const Size(70,30), // 👈 smaller button width & height
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                           ],
//                           ),
//                         ),
//                       );
//                     },
//                     icon: const Icon(Icons.check_circle_outline),
//                     label: const Text("Submit Booking"),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: oliveGreen,
//                       foregroundColor: tan,
//                       minimumSize: const Size.fromHeight(48),
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                     ),
//                   ),
//                 ),
//
//                 const SizedBox(height: 38),
//               ],
//             ),
//           ),
//     ),
//     ),);
//   }
//
//   Widget _infoRow(String label, String value, Color textColor) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Expanded(
//             flex: 5,
//             child: Text(
//               "$label:",
//               textAlign: TextAlign.right,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 color: textColor,
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             flex: 5,
//             child: Text(
//               value,
//               textAlign: TextAlign.left,
//               style: TextStyle(color: textColor),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _sectionHeader(String title) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
//       margin: const EdgeInsets.only(bottom: 8),
//       decoration: BoxDecoration(
//         color: oliveGreen,
//         borderRadius: BorderRadius.circular(6),
//         boxShadow: [
//           BoxShadow(color: oliveGreen.withValues(alpha:0.12), blurRadius: 4, offset: const Offset(0, 2)),
//         ],
//       ),
//       child: Text(
//         title,
//         style: TextStyle(color: tan, fontWeight: FontWeight.bold),
//       ),
//     );
//   }
//
//   Future<void> _fetchCustomerDetails(String phone) async {
//     final prefs = await SharedPreferences.getInstance();
//     final hallId = prefs.getInt('hallId');
//     if (hallId == null) return;
//
//     final formattedPhone = phone.startsWith('+91') ? phone : '+91$phone';
//
//     try {
//       final res = await http.get(Uri.parse('$baseUrl/bookings/$hallId/customer/$formattedPhone'));
//
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         setState(() {
//           nameController.text = data['name'] ?? '';
//           addressController.text = data['address'] ?? '';
//           altPhoneController.text =
//               (data['alternate_phone'] as List<dynamic>?)
//                   ?.map((e) => (e as String).replaceFirst('+91', ''))
//                   .join(', ') ??
//                   '';
//           emailController.text = data['email'] ?? '';
//         });
//       }
//     } catch (e) {
//       debugPrint("Error fetching customer details: $e");
//     }
//   }
//
//   Future<void> _pickFrom() async {
//     final picked = await DateTimeRangePicker.pickSingle(
//       context: context,
//       selectedDate: widget.selectedDate,
//       fullyBookedDates: fullyBookedDates,
//       bookedRanges: bookedRanges,
//       isFrom: true,
//       currentValue: DateFormat('yyyy-MM-dd hh:mm a').parse(fromController.text),
//       oliveGreen: oliveGreen,
//       tan: tan,
//     );
//
//     if (picked != null) {
//       setState(() {
//         fromController.text = DateFormat('yyyy-MM-dd hh:mm a').format(picked);
//       });
//     }
//   }
//
//   Future<void> _pickTo() async {
//     final picked = await DateTimeRangePicker.pickSingle(
//       context: context,
//       selectedDate: widget.selectedDate,
//       fullyBookedDates: fullyBookedDates,
//       bookedRanges: bookedRanges,
//       isFrom: false,
//       currentValue: DateFormat('yyyy-MM-dd hh:mm a').parse(toController.text),
//       oliveGreen: oliveGreen,
//       tan: tan,
//     );
//
//     if (picked != null) {
//       setState(() {
//         toController.text = DateFormat('yyyy-MM-dd hh:mm a').format(picked);
//       });
//     }
//   }
//
// }
