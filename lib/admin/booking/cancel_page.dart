import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
import 'pdf/cancel_pdf_generator.dart';
import '../../utils/hall_header.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';

class CancelBookingPage extends StatefulWidget {
  final int hallId;
  final int bookingId;
  final int userId;

  const CancelBookingPage({
    super.key,
    required this.hallId,
    required this.bookingId,
    required this.userId,
  });

  @override
  State<CancelBookingPage> createState() => _CancelBookingPageState();
}

class _CancelBookingPageState extends State<CancelBookingPage> {
  bool _loading = true;
  bool _canceled = false;
  Map<String, dynamic>? booking;
  Map<String, dynamic>? _cancelData;
  Map<String, dynamic>? _hallDetails;

  final TextEditingController reasonController = TextEditingController();
  final TextEditingController percentController = TextEditingController();
  final TextEditingController chargeController = TextEditingController();

  final Color primaryColor = const Color(0xFF5B6547);
  final Color tanColor = const Color(0xFFD8C9A9);
  final Color scaffoldBackground = const Color(0xFFECE5D8);

  double rentAmount = 0; // base for cancel calculation
  bool _updatingPercent = false;
  bool _updatingCharge = false;
  double get _calculatedRefund {
    final advance = double.tryParse(booking?['advance']?.toString() ?? '0') ?? 0;
    double cancelCharge = double.tryParse(chargeController.text) ?? 0;

    // ✅ Ensure cancel charge never exceeds advance
    if (cancelCharge > advance) cancelCharge = advance;

    final refund = advance - cancelCharge;
    return refund < 0 ? 0 : refund;
  }

  // double get _calculatedRefund {
  //   final advance = double.tryParse(booking?['advance']?.toString() ?? '0') ?? 0;
  //   double cancelCharge = double.tryParse(
  //       _cancelData?['cancel_charge']?.toString() ??
  //           chargeController.text
  //   ) ?? 0;
  //
  //   // ✅ Cap cancel charge to advance amount
  //   if (cancelCharge > advance) {
  //     cancelCharge = advance;
  //     // Update chargeController to reflect the capped value
  //     chargeController.text = cancelCharge.toStringAsFixed(2);
  //   }
  //
  //   final refund = advance - cancelCharge;
  //   return refund < 0 ? 0 : refund;
  // }

  // double get _calculatedRefund {
  //   final advance = double.tryParse(booking?['advance']?.toString() ?? '0') ?? 0;
  //   final cancelCharge = double.tryParse(
  //       _cancelData?['cancel_charge']?.toString() ??
  //           chargeController.text
  //   ) ?? 0;
  //   final refund = advance - cancelCharge;
  //   return refund < 0 ? 0 : refund;
  // }

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
    percentController.addListener(_onPercentChanged);
    chargeController.addListener(_onChargeChanged);
  }

  void _onPercentChanged() {
    if (_updatingPercent || rentAmount == 0 || _canceled) return;
    double? percent = double.tryParse(percentController.text);
    if (percent == null) return;
    if (percent > 100) percent = 100;

    _updatingCharge = true;
    double charge = rentAmount * percent / 100;

    // ✅ Cap charge to advance
    final advance = double.tryParse(booking?['advance']?.toString() ?? '0') ?? 0;
    if (charge > advance) charge = advance;

    chargeController.text = charge.toStringAsFixed(2);
    _updatingCharge = false;
    setState(() {}); // refresh refund
  }

  void _onChargeChanged() {
    if (_updatingCharge || rentAmount == 0 || _canceled) return;
    double charge = double.tryParse(chargeController.text) ?? 0;

    // ✅ Cap charge to advance
    final advance = double.tryParse(booking?['advance']?.toString() ?? '0') ?? 0;
    if (charge > advance) charge = advance;

    _updatingPercent = true;
    percentController.text = ((charge / rentAmount) * 100).toStringAsFixed(2);

    chargeController.text = charge.toStringAsFixed(2); // reflect cap
    _updatingPercent = false;
    setState(() {}); // refresh refund
  }

  // void _onPercentChanged() {
  //   if (_updatingPercent || rentAmount == 0 || _canceled) return;
  //   double? percent = double.tryParse(percentController.text);
  //   if (percent == null) return;
  //   if (percent > 100) percent = 100;
  //
  //   _updatingCharge = true;
  //   double charge = rentAmount * percent / 100;
  //   if (charge > rentAmount) charge = rentAmount;
  //   chargeController.text = charge.toStringAsFixed(2);
  //   _updatingCharge = false;
  // }
  //
  // void _onChargeChanged() {
  //   if (_updatingCharge || rentAmount == 0 || _canceled) return;
  //   double charge = double.tryParse(chargeController.text) ?? 0;
  //   if (charge > rentAmount) charge = rentAmount;
  //
  //   _updatingPercent = true;
  //   percentController.text = ((charge / rentAmount) * 100).toStringAsFixed(2);
  //   _updatingPercent = false;
  // }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: tanColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _loadBookingDetails() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/cancels/${widget.hallId}/${widget.bookingId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print("📘 Booking Data:\n${jsonEncode(data)}\n");
        setState(() {
          booking = data;
          rentAmount = double.tryParse(booking!['rent'].toString()) ?? 0;
        });
        reasonController.text = "Nil";

        // Fetch default cancel percent
        final defaultRes = await http.get(Uri.parse('$baseUrl/default-values/${widget.hallId}'));
        if (defaultRes.statusCode == 200) {
          final defaults = jsonDecode(defaultRes.body) as List<dynamic>;
          final cancelDefault = defaults.firstWhere(
                (d) => d['reason'].toString().toLowerCase() == 'cancel',
            orElse: () => null,
          );
          if (cancelDefault != null) {
            final defaultPercent = double.tryParse(cancelDefault['amount'].toString()) ?? 0;
            percentController.text =
                defaultPercent.clamp(0, 100).toStringAsFixed(defaultPercent % 1 == 0 ? 0 : 2);

            double defaultCharge = (rentAmount * defaultPercent / 100);
            if (defaultCharge > rentAmount) defaultCharge = rentAmount;
            chargeController.text =
                defaultCharge.toStringAsFixed(defaultCharge % 1 == 0 ? 0 : 2);
          }
        }
      }

      // Fetch hall details
      final hallRes = await http.get(Uri.parse('$baseUrl/halls/${widget.hallId}'));
      if (hallRes.statusCode == 200) {
        setState(() {
          _hallDetails = jsonDecode(hallRes.body);
        });
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmCancel() async {
    if (reasonController.text.isEmpty) {
      _showSnackBar("Please enter a reason");
      return;
    }

    setState(() => _loading = true);
    try {
      double cancelCharge = double.tryParse(chargeController.text) ?? 0;
      if (cancelCharge > rentAmount) cancelCharge = rentAmount;

      final payload = {
        "hall_id": widget.hallId,
        "booking_id": widget.bookingId,
        "user_id": widget.userId,
        "reason": reasonController.text,
        "cancel_charge": cancelCharge,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/cancels'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _cancelData = data;
          _canceled = true;
        });
        _showSnackBar("Booking cancelled successfully!");
      }
    } finally {
      setState(() => _loading = false);
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
            color: tanColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _plainRowWithTanValue(String label, {Widget? child, String? value}) {
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
            width: screenWidth * 0.42,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tanColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: child ??
                Text(
                  value ?? "—",
                  style: TextStyle(color: primaryColor),
                  textAlign: TextAlign.center,
                ),
          ),
        ],
      ),
    );
  }

  // Widget _sectionContainer(String title, List<Widget> children) {
  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.all(12),
  //     margin: const EdgeInsets.only(bottom: 16),
  //     decoration: BoxDecoration(
  //       color: scaffoldBackground,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: primaryColor, width: 1.5),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.stretch,
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.symmetric(vertical: 10),
  //           decoration: BoxDecoration(
  //             color: primaryColor,
  //             borderRadius: BorderRadius.circular(6),
  //           ),
  //           child: Center(
  //             child: Text(
  //               title,
  //               style: TextStyle(
  //                 color: tanColor,
  //                 fontWeight: FontWeight.bold,
  //                 fontSize: 16,
  //               ),
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 12),
  //         ...children,
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final readOnly = _canceled;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        backgroundColor: scaffoldBackground,
        appBar: AppBar(
          title: const Text("Cancel Booking"),
          centerTitle: true,
          backgroundColor: primaryColor,
          iconTheme: IconThemeData(color: tanColor),
          titleTextStyle:
          TextStyle(color: tanColor, fontSize: 23, fontWeight: FontWeight.bold),
          actions: [
            IconButton(
              icon: Icon(Icons.home, color: tanColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
                );
              },
            ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : booking == null
            ? const Center(child: Text("No booking details found"))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_hallDetails != null)
                HallHeader(
                    hallDetails: _hallDetails!,
                    oliveGreen: primaryColor,
                    tan: tanColor),
              const SizedBox(height: 10),
              if (_canceled && booking != null && _hallDetails != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 90),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _sectionContainer("CANCELLATION BILL", [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              "Generate the cancellation bill and view it as a PDF document.",
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Center(
                            child: SizedBox(
                              width: 220,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CancelPdfPage(
                                        bookingData: booking!,
                                        hallDetails: _hallDetails!,
                                        cancelData: _cancelData ?? {},
                                        billingList: [],
                                        oliveGreen: primaryColor,
                                        tan: tanColor,
                                        beigeBackground: scaffoldBackground,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.picture_as_pdf, size: 20),
                                label: const Text(
                                  "Generate Bill & View PDF",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: tanColor,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),


              if (_canceled && booking != null && _hallDetails != null)
                const SizedBox(height: 25),
              if (!_canceled)
                _sectionContainer(
                  "PAYMENT DETAILS",
                [
                  _plainRowWithTanValue(
                    "RENT",
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "₹${booking!['rent']}",
                        style: TextStyle(color: primaryColor, fontSize: 15),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  _plainRowWithTanValue(
                    "ADVANCE",
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "₹${booking!['advance']}",
                        style: TextStyle(color: primaryColor, fontSize: 15),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  _plainRowWithTanValue(
                    "BALANCE",
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "₹${booking!['balance']}",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold, // optional
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),

                  // _plainRowWithTanValue("RENT", value: "₹${booking!['rent']}"),
                  // _plainRowWithTanValue("ADVANCE", value: "₹${booking!['advance']}"),
                  // _plainRowWithTanValue("BALANCE", value: "₹${booking!['balance']}"),
                ],
                ),
              // if (_canceled)
              //   _sectionContainer(
              //     "CANCELLATION DETAILS",
              //     [
              //       // _plainRowWithTanValue(
              //       //   "CANCEL CHARGE",
              //       //   value: "₹${_cancelData?['cancel_charge'] ?? chargeController.text}",
              //       // ),
              //       // _plainRowWithTanValue(
              //       //   "REFUND AMOUNT",
              //       //   value: "₹${_calculatedRefund.toStringAsFixed(2)}",
              //       // ),
              //       _plainRowWithTanValue(
              //         "CANCEL CHARGE",
              //         child: Align(
              //           alignment: Alignment.centerRight,
              //           child: Text(
              //             "₹${_cancelData?['cancel_charge'] ?? chargeController.text}",
              //             style: TextStyle(
              //               color: primaryColor,
              //               fontSize: 14,
              //             ),
              //             textAlign: TextAlign.right,
              //           ),
              //         ),
              //       ),
              //       _plainRowWithTanValue(
              //         "REFUND AMOUNT",
              //         child: Align(
              //           alignment: Alignment.centerRight,
              //           child: Text(
              //             "₹${_calculatedRefund.toStringAsFixed(2)}",
              //             style: TextStyle(
              //               color: primaryColor,
              //               fontWeight: FontWeight.bold, // ✅ Bold refund
              //               fontSize: 15,
              //             ),
              //             textAlign: TextAlign.right,
              //           ),
              //         ),
              //       ),
              //
              //       _plainRowWithTanValue(
              //         "REASON",
              //         value: _cancelData?['reason'] ?? reasonController.text,
              //       ),
              //     ],
              //   ),
              // _sectionContainer(
              //   _canceled ? "CANCELLATION DETAILS" : "PAYMENT DETAILS",
              //   [
              //     _plainRowWithTanValue("RENT", value: "₹${booking!['rent']}"),
              //     _plainRowWithTanValue(
              //         "ADVANCE", value: "₹${booking!['advance']}"),
              //     _plainRowWithTanValue(
              //         "BALANCE", value: "₹${booking!['balance']}"),
              //     if (_canceled)
              //       _plainRowWithTanValue(
              //         "REFUND AMOUNT",
              //         value: "₹${_cancelData?['refund'] ?? 0}",
              //       ),
              //
              //     if (_canceled)
              //       _plainRowWithTanValue(
              //         "CANCEL CHARGE",
              //         value:
              //         "₹${_cancelData?['cancel_charge'] ?? chargeController.text}",
              //       ),
              //
              //     if (_canceled)
              //       _plainRowWithTanValue("REASON",
              //           value: _cancelData?['reason'] ?? reasonController.text),
              //   ],
              // ),

              if (!_canceled) ...[
                const SizedBox(height: 25),
                _sectionContainer("CANCELLATION DETAILS", [
                  _plainRowWithTanValue(
                    "CANCELLATION REASON",
                    child: TextField(
                      controller: reasonController,
                      maxLines: 3,
                      readOnly: readOnly,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Enter cancellation reason",
                        hintStyle:
                        TextStyle(color: primaryColor.withValues(alpha:0.7)),
                      ),
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                  _plainRowWithTanValue(
                    "CANCEL %",
                    child: TextField(
                      controller: percentController,
                      readOnly: readOnly,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                      const InputDecoration(border: InputBorder.none),
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                  _plainRowWithTanValue(
                    "CANCEL CHARGE",
                    child: TextField(
                      controller: chargeController,
                      readOnly: readOnly,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                      const InputDecoration(border: InputBorder.none),
                      style: TextStyle(color: primaryColor),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  _plainRowWithTanValue(
                  "REFUND AMOUNT",
                  child: Align(alignment: Alignment.centerRight,
                    child: Text(
                      "₹${_calculatedRefund.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold, // Bold refund amount
                       ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  ),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _cancelData != null ? null : _confirmCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text("Cancel Booking"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: tanColor,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 38),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
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
}
