import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../public/config.dart';
import '../../utils/hall_header.dart';
import 'pdf/billing_pdf.dart';
import '../../public/main_navigation.dart';

class UpdateBookingPage extends StatefulWidget {
  final int hallId;
  final int bookingId;
  final int userId;

  const UpdateBookingPage({
    super.key,
    required this.hallId,
    required this.bookingId,
    required this.userId,
  });

  @override
  State<UpdateBookingPage> createState() => _UpdateBookingPageState();
}

class _UpdateBookingPageState extends State<UpdateBookingPage> {
  bool _loading = true;
  bool _showPdfButton = false; // controls whether PDF button appears
  bool _isReadOnly = false; // new flag
  bool showEbCharge = false;
  double? _ebStartUnit;
  double? _ebEndUnit;
  double _ebRate = 0; // add this
  double _ebTotal = 0;
  double? _cleaningAmount;
  double? _lossOfGoodsAmount;
  double? _decorationAmount;
  double? _generatorAmount;
  double? _labourAmount;
  double get _chargesTotal {
    double total = 0;
    total += _ebTotal;
    total += _cleaningAmount ?? 0;
    total += _lossOfGoodsAmount ?? 0;
    total += _decorationAmount ?? 0;
    total += _generatorAmount ?? 0;
    total += _labourAmount ?? 0;
    total += otherCharges.fold(0, (sum, c) => sum + (c['amount'] ?? 0));
    return total;
  }

  double get _grandTotal {
    final balance = double.tryParse(booking!['balance'].toString()) ?? 0;
    return _chargesTotal + balance;
  }

  double? otherAmount;
  String? otherReason;
  Map<String, dynamic>? booking;
  Map<String, dynamic>? _hallDetails;
  List<Map<String, dynamic>> existingCharges = [];
  List<Map<String, dynamic>> chargesControllers = [];
  List<Map<String, dynamic>> defaultValues = [];
  // bool _showBalancePaymentCard = false;
  TextEditingController balanceReasonController = TextEditingController(text: "Balance Payment");
  TextEditingController balanceAmountController = TextEditingController();// Theme Colors
  Map<String, dynamic> _prepareBillingData() {
    final List<Map<String, dynamic>> charges = [];

    if (_ebTotal > 0) charges.add({'reason': 'EB CHARGE', 'amount': _ebTotal});
    if ((_cleaningAmount ?? 0) > 0) charges.add({'reason': 'CLEANING', 'amount': _cleaningAmount});
    if ((_lossOfGoodsAmount ?? 0) > 0) charges.add({'reason': 'LOSS OF GOODS', 'amount': _lossOfGoodsAmount});
    if ((_decorationAmount ?? 0) > 0) charges.add({'reason': 'DECORATION', 'amount': _decorationAmount});
    if ((_generatorAmount ?? 0) > 0) charges.add({'reason': 'GENERATOR', 'amount': _generatorAmount});
    if ((_labourAmount ?? 0) > 0) charges.add({'reason': 'LABOUR', 'amount': _labourAmount});

    charges.addAll(otherCharges.where((c) => (c['amount'] ?? 0) > 0));

    final balance = double.tryParse(booking?['balance']?.toString() ?? '0') ?? 0;

    return {
      'charges': charges,
      'balance': balance,
      'grandTotal': charges.fold<double>(0.0, (sum, c) => sum + (c['amount'] ?? 0.0)) + balance,
    };
  }
  final Color primaryColor = const Color(0xFF5B6547); // Olive green
  final Color backgroundColor = const Color(0xFFECE5D8); // Soft beige
  final Color secondaryColor = const Color(0xFFD8C7A5); // Muted tan
  List<Map<String, dynamic>> otherCharges = [];

  @override
  void initState() {
    super.initState();
    _loadDefaultValues().then((_) => _loadBookingAndExistingCharges());
    _loadHallDetails();
  }

  Future<void> _loadHallDetails() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/halls/${widget.hallId}'));
      if (res.statusCode == 200) {
        setState(() {
          _hallDetails = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Error loading hall details: $e");
    }
  }

  Future<void> _loadDefaultValues() async {
    try {
      final resDefaults = await http.get(Uri.parse('$baseUrl/default-values/${widget.hallId}'));
      if (resDefaults.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resDefaults.body);
        setState(() {
          defaultValues = data.map((e) => Map<String, dynamic>.from(e)).toList();
          final ebDefault = defaultValues.firstWhere(
                (d) => d['reason'] == 'EB (per unit)',
            orElse: () => {'amount': 0},
          );
          _ebRate = (ebDefault['amount'] ?? 0).toDouble();
        });
      }

    } catch (e) {
      debugPrint("Error loading default values: $e");
    }
  }

  Future<void> _loadBookingAndExistingCharges() async {
    try {
      final resBooking = await http.get(Uri.parse('$baseUrl/bookings/${widget.hallId}/${widget.bookingId}'));

      if (resBooking.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking not found")));
        Navigator.pop(context);
        return;
      }

      final dataBooking = jsonDecode(resBooking.body);

      final resCharges = await http.get(Uri.parse('$baseUrl/charges/${widget.hallId}/${widget.bookingId}'));

      if (resCharges.statusCode == 200) {
        final List<dynamic> dataCharges = jsonDecode(resCharges.body);
        existingCharges = dataCharges.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      setState(() {
        booking = dataBooking;
        _loading = false;
        _addChargeField();
      });
    } catch (e) {
      debugPrint("Error loading booking/charges: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      Navigator.pop(context);
    }
  }

  void _addChargeField() {
    setState(() {
      chargesControllers.add({
        'reason': TextEditingController(),
        'amount': TextEditingController(),
        'startUnit': TextEditingController(text: '0'), // initialize once here
        'endUnit': TextEditingController(text: '0'),   // initialize once here
        'unit': null,
        'selectedDefault': null,
        'isCustom': false,
      });
    });
  }

  void _showOtherChargeDialog({Map<String, dynamic>? charge, int? index}) {
    String? selectedReason = charge != null ? charge['reason'] : null;
    double? amount = charge != null ? charge['amount'] : null;
    bool isCustom = charge != null && !defaultValues.any((d) => d['reason'] == charge['reason']);

    TextEditingController reasonController = TextEditingController(
      text: isCustom ? selectedReason : '',
    );
    TextEditingController amountController = TextEditingController(
      text: amount?.toString() ?? '',
    );

    // Build list of dropdown items: all default reasons (excluding EB, Rent, Peak Hours, Cancel)
    List<String> dropdownItems = defaultValues
        .map((d) => d['reason'].toString())
        .where((r) => !['EB (per unit)', 'Rent', 'Peak Hours', 'Cancel'].contains(r))
        .toList();
    dropdownItems.add('Other');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: primaryColor, width: 1.5),
              ),
              title: Center(
                child: Text(
                  charge != null ? "EDIT OTHER CHARGE" : "ADD OTHER CHARGE",
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: isCustom ? 'Other' : selectedReason,
                    decoration: InputDecoration(
                      labelText: "Reason",
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: secondaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: secondaryColor.withValues(alpha:0.2), // dropdown background
                    ),
                    dropdownColor: backgroundColor, // dropdown menu background
                    style: TextStyle(color: primaryColor), // selected item text color
                    items: dropdownItems
                        .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        r,
                        style: TextStyle(color: primaryColor), // dropdown item text color
                      ),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        if (value == 'Other') {
                          isCustom = true;
                          reasonController.text = '';
                          amountController.text = '';
                        } else {
                          isCustom = false;
                          selectedReason = value;
                          final defaultCharge = defaultValues.firstWhere(
                                (d) => d['reason'] == value,
                            orElse: () => {'amount': 0},
                          );
                          amountController.text = (defaultCharge['amount'] ?? 0).toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (isCustom)
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: "Custom Reason",
                        labelStyle: TextStyle(color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: secondaryColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: secondaryColor.withValues(alpha:0.2),
                      ),
                      style: TextStyle(color: primaryColor),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Amount (₹)",
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: secondaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: secondaryColor.withValues(alpha:0.2),
                    ),
                    style: TextStyle(color: primaryColor),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor,
                    foregroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final reason = (isCustom ? reasonController.text : selectedReason)?.trim().toUpperCase();
                    final amt = double.tryParse(amountController.text.trim()) ?? 0;
                    if (reason != null && reason.isNotEmpty && amt > 0) {
                      setState(() {
                        if (charge != null && index != null) {
                          otherCharges[index] = {'reason': reason, 'amount': amt};
                        } else {
                          otherCharges.add({'reason': reason, 'amount': amt});
                        }
                      });
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: secondaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // void _showOtherChargeDialog({Map<String, dynamic>? charge, int? index}) {
  //   // If editing, prefill values
  //   TextEditingController reasonController = TextEditingController(
  //       text: charge != null ? charge['reason'] : '');
  //   TextEditingController amountController = TextEditingController(
  //       text: charge != null ? charge['amount'].toString() : '');
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         backgroundColor: backgroundColor,
  //         title: Center(
  //           child: Text(
  //             charge != null ? "EDIT OTHER CHARGE" : "ADD OTHER CHARGE",
  //             style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
  //           ),
  //         ),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             TextField(
  //               controller: reasonController,
  //               decoration: InputDecoration(labelText: "Reason"),
  //             ),
  //             SizedBox(height: 10),
  //             TextField(
  //               controller: amountController,
  //               keyboardType: TextInputType.numberWithOptions(decimal: true),
  //               decoration: InputDecoration(labelText: "Amount (₹)"),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: Text("Cancel"),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               final reason = reasonController.text.trim().toUpperCase();
  //               final amount = double.tryParse(amountController.text.trim()) ?? 0;
  //               if (reason.isNotEmpty && amount > 0) {
  //                 setState(() {
  //                   if (charge != null && index != null) {
  //                     // Edit existing
  //                     otherCharges[index] = {'reason': reason, 'amount': amount};
  //                   } else {
  //                     // Add new
  //                     otherCharges.add({'reason': reason, 'amount': amount});
  //                   }
  //                 });
  //               }
  //               Navigator.pop(context);
  //             },
  //             child: Text("OK"),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  Future<void> _submitAll() async {
    setState(() => _loading = true);

    try {
      // Step 1: Combine all charges into a single array
      final List<Map<String, dynamic>> allCharges = [];

      // EB Charge
      if (_ebTotal > 0) {
        allCharges.add({'reason': 'EB CHARGE', 'amount': _ebTotal});
      }

      // Cleaning
      if ((_cleaningAmount ?? 0) > 0) {
        allCharges.add({'reason': 'CLEANING', 'amount': _cleaningAmount});
      }

      // Loss of Goods
      if ((_lossOfGoodsAmount ?? 0) > 0) {
        allCharges.add({'reason': 'LOSS OF GOODS', 'amount': _lossOfGoodsAmount});
      }

      // Decoration
      if ((_decorationAmount ?? 0) > 0) {
        allCharges.add({'reason': 'DECORATION', 'amount': _decorationAmount});
      }

      // Generator
      if ((_generatorAmount ?? 0) > 0) {
        allCharges.add({'reason': 'GENERATOR', 'amount': _generatorAmount});
      }

      // Labour
      if ((_labourAmount ?? 0) > 0) {
        allCharges.add({'reason': 'LABOUR', 'amount': _labourAmount});
      }

      // Custom/Other charges
      allCharges.addAll(otherCharges);

      // Step 2: Optional Debugging
      print("Submitting charges: ${jsonEncode(allCharges)}");

      // Step 3: Submit all charges to backend
      if (allCharges.isNotEmpty) {
        final resCharges = await http.post(
          Uri.parse('$baseUrl/charges/${widget.hallId}/${widget.bookingId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': widget.userId,
            'charges': allCharges,
          }),
        );

        if (resCharges.statusCode != 200 && resCharges.statusCode != 201) {
          final err = resCharges.body.isNotEmpty ? jsonDecode(resCharges.body) : {};
          throw Exception("Charges Error: ${err['message'] ?? resCharges.body}");
        }
      }

      // Step 4: Submit balance if remaining
      final balanceAmount = double.tryParse(booking?['balance']?.toString() ?? '0') ?? 0;
      if (balanceAmount > 0) {
        final resBalance = await http.post(
          Uri.parse('$baseUrl/charges/${widget.hallId}/${widget.bookingId}/balance-payment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': widget.userId,
            'amount': balanceAmount,
            'reason': 'Balance',
          }),
        );

        if (resBalance.statusCode != 200 && resBalance.statusCode != 201) {
          final err = resBalance.body.isNotEmpty ? jsonDecode(resBalance.body) : {};
          throw Exception("Balance Payment Error: ${err['message'] ?? resBalance.body}");
        }
      }

      // Step 5: Update UI
      setState(() {
        _isReadOnly = true;
        _showPdfButton = true;
      });

      _showSnackBar("Charges and balance submitted successfully!");

    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openPdf() {
    if (booking == null || _hallDetails == null) return;

    final billingData = _prepareBillingData();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateBookingPdfPage(
          bookingData: booking!,
          hallDetails: _hallDetails!,
          billingData: billingData, // <-- send complete billing data
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: secondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
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
          // Label
          Container(
            width: screenWidth * 0.35, // 35% for label
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Value container
          Container(
            width: screenWidth * 0.42, // 42% for value/child
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center, // Center content horizontally
            child: child ??
                Text(
                  value ?? "—",
                  style: TextStyle(color: primaryColor),
                  textAlign: TextAlign.center, // Center text
                ),
          ),
        ],
      ),
    );
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
            color: secondaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
        color: backgroundColor, // same as page background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: primaryColor,
          width: 1.5,
        ),
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

  void _showEbDialog() {
    // Fetch default EB rate from defaultValues
    final ebDefault = defaultValues.firstWhere(
          (d) => d['reason'] == 'EB (per unit)',
      orElse: () => {'amount': 0},
    );
    final defaultEbRate = (ebDefault['amount'] ?? 0).toDouble();

    // Use existing values if already set, else default
    final startController = TextEditingController(text: _ebStartUnit?.toString() ?? '0');
    final endController = TextEditingController(text: _ebEndUnit?.toString() ?? '0');
    final rateController = TextEditingController(text: _ebRate > 0 ? _ebRate.toString() : defaultEbRate.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor, // soft beige background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: primaryColor, width: 1.5),
          ),
          title: Center(
            child: Text(
              "EB CHARGE",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              double start = double.tryParse(startController.text) ?? 0;
              double end = double.tryParse(endController.text) ?? 0;
              double rate = double.tryParse(rateController.text) ?? defaultEbRate;
              double total = (end - start) * rate;
              if (total < 0) total = 0;

              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Start Unit
                      TextField(
                        controller: startController,
                        decoration: InputDecoration(
                          labelText: "Start Unit",
                          labelStyle: TextStyle(color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: secondaryColor.withValues(alpha:0.2),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: primaryColor),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // End Unit
                      TextField(
                        controller: endController,
                        decoration: InputDecoration(
                          labelText: "End Unit",
                          labelStyle: TextStyle(color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: secondaryColor.withValues(alpha:0.2),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: primaryColor),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Per Unit Rate
                      TextField(
                        controller: rateController,
                        decoration: InputDecoration(
                          labelText: "Per Unit Rate (₹)",
                          labelStyle: TextStyle(color: primaryColor),
                          hintText: defaultEbRate.toString(),
                          hintStyle: TextStyle(color: primaryColor.withValues(alpha:0.6)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: secondaryColor.withValues(alpha:0.2),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: primaryColor),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 20),

                      // Total Display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: secondaryColor.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primaryColor, width: 1),
                        ),
                        child: Text(
                          "Total: ₹${total.toStringAsFixed(2)}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            // Cancel Button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                foregroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            // OK Button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _ebStartUnit = double.tryParse(startController.text);
                  _ebEndUnit = double.tryParse(endController.text);
                  _ebRate = double.tryParse(rateController.text) ?? defaultEbRate;
                  _ebTotal = ((_ebEndUnit ?? 0) - (_ebStartUnit ?? 0)) * _ebRate;
                  if (_ebTotal < 0) _ebTotal = 0;
                  showEbCharge = true;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: secondaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showCleaningDialog() {
    final TextEditingController controller = TextEditingController(
        text: _cleaningAmount != null ? _cleaningAmount.toString() : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: primaryColor, width: 1.5),
          ),
          title: Center(
            child: Text(
              "CLEANING",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Amount (₹)",
              labelStyle: TextStyle(color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: secondaryColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: secondaryColor.withValues(alpha:0.2),
            ),
            style: TextStyle(color: primaryColor),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                foregroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _cleaningAmount = double.tryParse(controller.text) ?? 0;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: secondaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showChargeDialog(String title, double? initialAmount, Function(double) onSaved) {
    final TextEditingController amountController =
    TextEditingController(text: initialAmount?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: primaryColor, width: 1.5),
          ),
          title: Center(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Amount (₹)",
              labelStyle: TextStyle(color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: secondaryColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: secondaryColor.withValues(alpha:0.2),
            ),
            style: TextStyle(color: primaryColor),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                foregroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim()) ?? 0;
                if (amount > 0) {
                  onSaved(amount); // save using callback
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: secondaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    for (var c in chargesControllers) {
      if (c['reason'] is TextEditingController) (c['reason'] as TextEditingController).dispose();
      if (c['amount'] is TextEditingController) (c['amount'] as TextEditingController).dispose();
      if (c['startUnit'] is TextEditingController) (c['startUnit'] as TextEditingController).dispose();
      if (c['endUnit'] is TextEditingController) (c['endUnit'] as TextEditingController).dispose();
      if (c['unit'] is TextEditingController) (c['unit'] as TextEditingController).dispose();
    }
    balanceReasonController.dispose();
    balanceAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, true); // send refresh signal
          return false; // prevent default pop (we already did it)
        },child:Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Billing", style: TextStyle(color: secondaryColor)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
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
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : booking == null
          ? Center(child: Text("No booking details found", style: TextStyle(color: primaryColor)))
          : Container(
        color: backgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // ✅ Show Hall Details Card
              if (_hallDetails != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: HallHeader(
                    hallDetails: _hallDetails!,
                    oliveGreen: primaryColor,
                    tan: secondaryColor,
                  ),
                ),
              if (_showPdfButton)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 90),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _sectionContainer("GENERATE BILL", [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              "Generate the bill and view it as a PDF document.",
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
                                onPressed: _openPdf,
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
                                  foregroundColor: secondaryColor,
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


              if (_showPdfButton)
                const SizedBox(height: 24),
              if (!_showPdfButton)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionContainer(
                      "BOOKING DETAILS",
                      [
                        _plainRowWithTanValue("BOOKING ID", value: booking!['booking_id'].toString()),
                        _plainRowWithTanValue("NAME", value: booking!['name']),
                        _plainRowWithTanValue("PHONE", value: booking!['phone']),
                        _plainRowWithTanValue(
                          "FUNCTION DATE",
                          value: DateFormat('dd-MM-yyyy').format(DateTime.parse(booking!['function_date'])),
                        ),
                        _plainRowWithTanValue("TAMIL DATE", value: booking!['tamil_date'] ?? "N/A"),
                        _plainRowWithTanValue("TAMIL MONTH", value: booking!['tamil_month'] ?? "N/A"),
                        _plainRowWithTanValue("EVENT NAME", value: booking!['event_type'] ?? "N/A"),
                        _plainRowWithTanValue(
                          "ALLOTED FROM",
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                booking!['alloted_datetime_from'] != null
                                    ? DateFormat('dd-MM-yyyy').format(DateTime.parse(booking!['alloted_datetime_from']))
                                    : "N/A",
                                style: TextStyle(color: primaryColor),
                              ),
                              Text(
                                booking!['alloted_datetime_from'] != null
                                    ? DateFormat('hh:mm a').format(DateTime.parse(booking!['alloted_datetime_from']))
                                    : "",
                                style: TextStyle(color: primaryColor),
                              ),
                            ],
                          ),
                        ),
                        _plainRowWithTanValue(
                          "ALLOTED TO",
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                booking!['alloted_datetime_to'] != null
                                    ? DateFormat('dd-MM-yyyy').format(DateTime.parse(booking!['alloted_datetime_to']))
                                    : "N/A",
                                style: TextStyle(color: primaryColor),
                              ),
                              Text(
                                booking!['alloted_datetime_to'] != null
                                    ? DateFormat('hh:mm a').format(DateTime.parse(booking!['alloted_datetime_to']))
                                    : "",
                                style: TextStyle(color: primaryColor),
                              ),
                            ],
                          ),
                        ),
                        _plainRowWithTanValue("RENT", value: booking!['rent'].toString()),
                        _plainRowWithTanValue("ADVANCE", value: booking!['advance'].toString()),
                        _plainRowWithTanValue("BALANCE", value: booking!['balance'].toString()),
                      ],
                    ),
                    if (_isReadOnly)
                      _sectionContainer(
                        "BILLING INFORMATION",
                        [
                          _plainRowWithTanValue(
                            "BALANCE",
                            value: "₹${booking!['balance']}",
                          ),
                          const SizedBox(height: 10),

                          // EB CHARGE
                          if (_ebTotal > 0)
                            _plainRowWithTanValue("EB CHARGE", value: "₹${_ebTotal.toStringAsFixed(2)}"),

                          // CLEANING
                          if ((_cleaningAmount ?? 0) > 0)
                            _plainRowWithTanValue("CLEANING", value: "₹${_cleaningAmount!.toStringAsFixed(2)}"),

                          // LOSS OF GOODS
                          if ((_lossOfGoodsAmount ?? 0) > 0)
                            _plainRowWithTanValue("LOSS OF GOODS", value: "₹${_lossOfGoodsAmount!.toStringAsFixed(2)}"),

                          // DECORATION
                          if ((_decorationAmount ?? 0) > 0)
                            _plainRowWithTanValue("DECORATION", value: "₹${_decorationAmount!.toStringAsFixed(2)}"),

                          // GENERATOR
                          if ((_generatorAmount ?? 0) > 0)
                            _plainRowWithTanValue("GENERATOR", value: "₹${_generatorAmount!.toStringAsFixed(2)}"),

                          // LABOUR
                          if ((_labourAmount ?? 0) > 0)
                            _plainRowWithTanValue("LABOUR", value: "₹${_labourAmount!.toStringAsFixed(2)}"),

                          // OTHER CHARGES
                          ...otherCharges
                              .where((c) => (c['amount'] ?? 0) > 0)
                              .map((c) => _plainRowWithTanValue(
                            c['reason'],
                            value: "₹${c['amount'].toStringAsFixed(2)}",
                          ))
                              .toList(),

                          const SizedBox(height: 12),

                          _plainRowWithTanValue(
                            "TOTAL",
                            value: "₹${_grandTotal.toStringAsFixed(2)}",
                          ),

                          // Only show 'Other' button if not read-only
                          if (!_isReadOnly)
                            ElevatedButton.icon(
                              onPressed: _showOtherChargeDialog,
                              icon: Icon(Icons.add, color: secondaryColor),
                              label: Text("Other", style: TextStyle(color: secondaryColor)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                        ],
                      ),

                    if (!_isReadOnly)
                      _sectionContainer(
                        "BILLING INFORMATION",
                        [
                          _plainRowWithTanValue(
                            "BALANCE",
                            value: "₹${booking!['balance']}",
                          ),

                          const SizedBox(height: 10),

                          // ✅ EB Charge row (like other rows, opens dialog on tap)
                          GestureDetector(
                            onTap: _showEbDialog,
                            child: _plainRowWithTanValue(
                              "EB CHARGE",
                              value: _ebTotal != null && _ebTotal > 0
                                  ? "₹${_ebTotal.toStringAsFixed(2)}"
                                  : "Tap to add",
                            ),
                          ),
                          const SizedBox(height: 10),

                          GestureDetector(
                            onTap: _showCleaningDialog,
                            child: _plainRowWithTanValue(
                              "CLEANING",
                              value: _cleaningAmount != null && _cleaningAmount! > 0
                                  ? "₹${_cleaningAmount!.toStringAsFixed(2)}"
                                  : "Tap to add",
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showChargeDialog("Loss of Goods", _lossOfGoodsAmount, (val) {
                              setState(() => _lossOfGoodsAmount = val);
                            }),
                            child: _plainRowWithTanValue(
                              "LOSS OF GOODS",
                              value: _lossOfGoodsAmount != null && _lossOfGoodsAmount! > 0
                                  ? "₹${_lossOfGoodsAmount!.toStringAsFixed(2)}"
                                  : "Tap to add",
                            ),
                          ),

                          GestureDetector(
                            onTap: () => _showChargeDialog("Decoration", _decorationAmount, (val) {
                              setState(() => _decorationAmount = val);
                            }),
                            child: _plainRowWithTanValue(
                              "DECORATION",
                              value: _decorationAmount != null && _decorationAmount! > 0
                                  ? "₹${_decorationAmount!.toStringAsFixed(2)}"
                                  : "Tap to add",
                            ),
                          ),

                          GestureDetector(
                            onTap: () => _showChargeDialog("Generator", _generatorAmount, (val) {
                              setState(() => _generatorAmount = val);
                            }),
                            child: _plainRowWithTanValue(
                              "GENERATOR",
                              value: _generatorAmount != null && _generatorAmount! > 0
                                  ? "₹${_generatorAmount!.toStringAsFixed(2)}"
                                  : "Tap to add",
                            ),
                          ),

                          GestureDetector(
                            onTap: () => _showChargeDialog("Labour", _labourAmount, (val) {
                              setState(() => _labourAmount = val);
                            }),
                            child: _plainRowWithTanValue(
                              "LABOUR",
                              value: _labourAmount != null && _labourAmount! > 0
                                  ? "₹${_labourAmount!.toStringAsFixed(2)}"
                                  : "Tap to add",
                            ),
                          ),
                          ...otherCharges.asMap().entries.map((entry) {
                            int idx = entry.key;
                            Map<String, dynamic> c = entry.value;
                            return GestureDetector(
                              onTap: () => _showOtherChargeDialog(charge: c, index: idx),
                              child: _plainRowWithTanValue(
                                c['reason'],
                                value: "₹${c['amount'].toStringAsFixed(2)}",
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 12),
                          _plainRowWithTanValue(
                            "TOTAL",
                            value: "₹${_grandTotal.toStringAsFixed(2)}",
                          ),


                          ElevatedButton.icon(
                            onPressed: _showOtherChargeDialog,
                            icon: Icon(Icons.add, color: secondaryColor),
                            label: Text("Other", style: TextStyle(color: secondaryColor)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),


                        ],
                      ),
                    if (!_isReadOnly)
                      Align(
                        alignment: Alignment.center,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _submitAll, // only enabled if loading is false
                          icon: const Icon(Icons.save, size: 22),
                          label: const Text(
                            "Submit All",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: secondaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    SizedBox(height: 30),
                    const SizedBox(height: 50)
                  ],
                ),
              // Existing Charges section
            ],
          ),
        ),
      ),
    ),
    );
  }
}
