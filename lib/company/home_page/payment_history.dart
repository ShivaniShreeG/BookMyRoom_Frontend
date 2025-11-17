import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

class TransactionHistoryPage extends StatefulWidget {
  final dynamic hall;

  const TransactionHistoryPage({super.key, required this.hall});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<dynamic> transactions = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/app-payment/history/${widget.hall['hall_id']}'),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          transactions = data;
          loading = false;
        });
      } else if (response.statusCode == 404) {
        // Handle "no payments found"
        setState(() {
          transactions = [];
          loading = false;
        });
      } else {
        setState(() {
          error = "Failed to load: ${response.body}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error: $e";
        loading = false;
      });
    }
  }

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      return "${date.day.toString().padLeft(2, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.year}";
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color oliveGreen = Color(0xFF5B6547);
    const Color mutedTan = Color(0xFFD8C9A9);
    const Color beige = Color(0xFFECE5D8);

    return Scaffold(
      backgroundColor: beige,
      appBar: AppBar(
        title: Text(
          "Transactions - ${widget.hall['name'] ?? 'Hall'}",
          style: const TextStyle(color: mutedTan, fontWeight: FontWeight.bold),
        ),
        backgroundColor: oliveGreen,
        iconTheme: const IconThemeData(color: mutedTan),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: oliveGreen))
          : error != null
          ? Center(
        child: Text(
          error!,
          style: const TextStyle(color: oliveGreen),
        ),
      )
          : transactions.isEmpty
          ? const Center(
        child: Text(
          "No transactions found.",
          style: TextStyle(color: oliveGreen, fontSize: 16),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(12),
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 80, top: 12),
          itemCount: transactions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12), // 👈 space between cards
          itemBuilder: (context, index) {
            final tx = transactions[index];

            final baseAmount = tx['BaseAmount'] ?? 0;
            final gstAmount = tx['gstAmount'] ?? 0;
            final total = tx['totalAmount'] ?? 0;
            final status = tx['status'] ?? 'N/A';
            final transactionId = tx['transactionId'] ?? '-';
            final paidAt = _formatDate(tx['paidAt']);
            final start = _formatDate(tx['periodStart']);
            final end = _formatDate(tx['periodEnd']);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: oliveGreen, width: 1),
              ),
              color: Color(0xFFF3E2CB),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Transaction ID:",
                          style: TextStyle(
                            color: oliveGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          transactionId,
                          style: const TextStyle(color: oliveGreen,),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Paid At:", style: TextStyle(color: oliveGreen)),
                        Text(paidAt, style: TextStyle(color: oliveGreen)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Period Start:", style: TextStyle(color: oliveGreen)),
                        Text(start, style: TextStyle(color: oliveGreen)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Period End:", style: TextStyle(color: oliveGreen)),
                        Text(end, style: TextStyle(color: oliveGreen)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Base Amount:", style: TextStyle(color: oliveGreen)),
                        Text("₹${baseAmount.toStringAsFixed(2)}", style: TextStyle(color: oliveGreen)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("GST (18%):", style: TextStyle(color: oliveGreen)),
                        Text("₹${gstAmount.toStringAsFixed(2)}", style: TextStyle(color: oliveGreen)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Total:", style: TextStyle(color: oliveGreen, fontWeight: FontWeight.bold)),
                        Text("₹${total.toStringAsFixed(2)}",
                            style: const TextStyle(color: oliveGreen,fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Status:", style: TextStyle(color: oliveGreen)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == "COMPLETED"
                                ? Colors.green[100]
                                : Colors.red[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: status == "COMPLETED"
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),


                  ],

                ),

              ),

            );

          },

        ),
      ),

    );
  }
}
