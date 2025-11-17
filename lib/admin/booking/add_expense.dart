import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;
  bool _showForm = false;
  int? _editingExpenseId;

  List<Map<String, dynamic>> _expenses = [];
  Map<String, dynamic>? hallDetails;

  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFD8C9A9);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId != null) {
      await _fetchHallDetails(hallId); // fetch hall info
      await _fetchExpenses();// fetch admins
    }
  }

  Future<void> _fetchExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/expenses/$hallId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _expenses = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching expenses: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Hall ID not found")),
      );
      setState(() => _isLoading = false);
      return;
    }

    final body = {
      "hall_id": hallId,
      "reason": _reasonController.text.trim(),
      "amount": double.parse(_amountController.text.trim())
    };

    try {
      http.Response response;
      if (_editingExpenseId == null) {
        response = await http.post(
          Uri.parse("$baseUrl/expenses"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      } else {
        response = await http.patch(
          Uri.parse("$baseUrl/expenses/$_editingExpenseId"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingExpenseId == null
                ? "✅ Expense added successfully"
                : "✅ Expense updated successfully"),
          ),
        );

        _formKey.currentState!.reset();
        _reasonController.clear();
        _amountController.clear();

        setState(() {
          _editingExpenseId = null;
          _showForm = false;
        });

        _fetchExpenses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error submitting expense: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteExpense(int expenseId) async {
    try {
      final url = Uri.parse("$baseUrl/expenses/$expenseId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() => _expenses.removeWhere((e) => e["id"] == expenseId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Expense deleted successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to delete: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error deleting expense: $e");
    }
  }

  void _showDeleteDialog(int expenseId, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Delete Expense", style: TextStyle(color: primaryColor)),
        content: Text("Do you want to delete the expense for \"$reason\"?",
            style: TextStyle(color: primaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _deleteExpense(expenseId);
            },
            child: Text("Confirm", style: TextStyle(color: backgroundColor)),
          ),
        ],
      ),
    );
  }

  void _editExpense(Map<String, dynamic> expense) {
    setState(() {
      _editingExpenseId = expense["id"];
      _reasonController.text = expense["reason"] ?? "";
      _amountController.text = expense["amount"]?.toString() ?? "";
      _showForm = true;
    });
  }

  // InputDecoration _buildInputDecoration(String label) {
  //   return InputDecoration(
  //     labelText: label,
  //     labelStyle: TextStyle(color: primaryColor),
  //     enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
  //     focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
  //   );
  // }

  Widget _buildExpenseForm() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: primaryColor, width: 1),
      ),
      color: const Color(0xFFECE5D8),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Reason Field
              labeledTanRow(
                label: "Reason",
                child: TextFormField(
                  controller: _reasonController,
                  textCapitalization: TextCapitalization.characters, // Auto uppercase
                  style: TextStyle(color: primaryColor),
                  cursorColor: primaryColor,
                  decoration:  InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: "Enter Reason",          // ✅ Hint added
                    hintStyle: TextStyle(color: primaryColor,fontSize: 15),
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter reason" : null,
                ),
              ),

              const SizedBox(height: 16),

              // Amount Field
              labeledTanRow(
                label: "Amount",
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: primaryColor),
                  cursorColor: primaryColor,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: "Enter Amount",          // ✅ Hint added
                    hintStyle: TextStyle(color: primaryColor,fontSize: 15),
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter amount" : null,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: backgroundColor,
                      ),
                      onPressed: _isLoading ? null : _submitExpense,
                      child: _isLoading
                          ? CircularProgressIndicator(color: backgroundColor)
                          : Text(
                        _editingExpenseId == null
                            ? "Add Expense"
                            : "Update Expense",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _editingExpenseId = null;
                        _reasonController.clear();
                        _amountController.clear();
                      });
                    },
                    child: Text("Close", style: TextStyle(color: primaryColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha:0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Leading icon with background circle
            // Container(
            //   padding: const EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     color: primaryColor.withValues(alpha0.2),
            //     shape: BoxShape.circle,
            //   ),
            //   child: Icon(Icons.attach_money, color: primaryColor, size: 28),
            // ),
            // const SizedBox(width: 16),

            // Reason and amount
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense["reason"]?.toUpperCase() ?? "-",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${expense["amount"] ?? "-"}",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Edit & Delete buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: primaryColor),
                  onPressed: () => _editExpense(expense),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: primaryColor),
                  onPressed: () =>
                      _showDeleteDialog(expense["id"], expense["reason"] ?? "-"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildExpenseCard(Map<String, dynamic> expense) {
  //   return Card(
  //     color: backgroundColor,
  //     elevation: 3,
  //     margin: const EdgeInsets.symmetric(vertical: 8),
  //     child: ListTile(
  //       leading: Icon(Icons.attach_money, color: primaryColor),
  //       title: Text(expense["reason"] ?? "-", style: TextStyle(color: primaryColor)),
  //       subtitle: Text("Amount: ₹${expense["amount"] ?? "-"}",
  //           style: TextStyle(color: primaryColor)),
  //       trailing: Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           IconButton(
  //             icon: Icon(Icons.edit, color: primaryColor),
  //             onPressed: () => _editExpense(expense),
  //           ),
  //           IconButton(
  //             icon: Icon(Icons.delete, color: primaryColor),
  //             onPressed: () => _showDeleteDialog(expense["id"], expense["reason"] ?? "-"),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget labeledTanRow({
    required String label,
    String? value,
    Widget? child,
    String? hint,
    double labelWidthFactor = 0.25,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final primaryColor = const Color(0xFF5B6547);
    final tanColor = const Color(0xFFD8C9A9);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // ✅ vertically center the row
        children: [
          // Label
          Container(
            width: screenWidth * labelWidthFactor,
            alignment: Alignment.centerLeft, // ✅ vertically center, keep left aligned
            child: Text(
              label,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Value/Input takes remaining width
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tanColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: child ?? Text(
                value ?? "—",
                style: TextStyle(color: primaryColor),
              ),
            ),
          ),
        ],
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
        children: [
          Expanded(
            child: Center(
              child: Text(
                hall['name']?.toString().toUpperCase() ?? "HALL NAME",
                style: TextStyle(
                  color: backgroundColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ClipOval(
            child: hall['logo'] != null
                ? Image.memory(base64Decode(hall['logo']),
                width: 70, height: 70, fit: BoxFit.cover)
                : const Icon(Icons.home_work, color: Colors.white, size: 35),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchHallDetails(int hallId) async {
    try {
      final url = Uri.parse('$baseUrl/halls/$hallId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        hallDetails = jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching hall details: $e");
    } finally {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Add Expenses", style: TextStyle(color: Color(0xFFD8C9A9))),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Color(0xFFD8C9A9)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
      ),
      body: _isFetching
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hallDetails != null) _buildHallCard(hallDetails!),
            const SizedBox(height: 16),
            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                ),
                onPressed: () => setState(() => _showForm = true),
                child: const Text("Add Expense"),
              ),
            if (_showForm) _buildExpenseForm(),
            const SizedBox(height: 16),
            ..._expenses.map(_buildExpenseCard).toList(),
          ],
        ),
      ),
    );
  }
}
