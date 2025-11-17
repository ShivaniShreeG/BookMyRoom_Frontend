import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';
class ViewFinancePage extends StatefulWidget {
  const ViewFinancePage({super.key});

  @override
  State<ViewFinancePage> createState() => _ViewFinancePageState();
}

class _ViewFinancePageState extends State<ViewFinancePage> {
  bool _isFetching = true;

  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _billings = [];
  List<Map<String, dynamic>> _filteredData = [];
  Map<String, dynamic>? hallDetails;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _drawing = [];
  Map<String, double> _calculateTotals() {
    double totalIncome = 0;
    double totalExpense = 0;
    double totalDrawingIn = 0;
    double totalDrawingOut = 0;

    for (var item in _filteredData) {
      final amount = double.tryParse(item["amount"].toString()) ?? 0;
      switch (item["type"]) {
        case "Income":
          totalIncome += amount;
          break;
        case "Expense":
          totalExpense += amount;
          break;
        case "Drawing In":
          totalDrawingIn += amount;
          break;
        case "Drawing Out":
          totalDrawingOut += amount;
          break;
      }
    }

    return {
      "income": totalIncome,
      "expense": totalExpense,
      "drawingIn": totalDrawingIn,
      "drawingOut": totalDrawingOut,
    };
  }


  DateTime _selectedMonth = DateTime.now();
  String _selectedFilter = "All"; // All | Income | Expense

  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFD8C9A9);
  final Color scaffoldBackground = const Color(0xFFECE5D8);
  final Color cardColor = const Color(0xFFD8C9A9);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId != null) {
      await _fetchHallDetails(hallId);
      await Future.wait([
        _fetchExpenses(hallId),
        _fetchBillings(hallId),
        _fetchBookings(hallId),
        _fetchIncomes(hallId),
        _fetchDrawing(hallId)
      ]);
      _filterCombinedData();
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
  
  Future<void> _fetchBookings(int hallId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/bookings/all/$hallId"));
      if (response.statusCode == 200) {
        _bookings = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("❌ Error fetching bookings: $e");
    }
  }

  Future<void> _fetchExpenses(int hallId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/expenses/$hallId"));
      if (response.statusCode == 200) {
        _expenses = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("❌ Error fetching expenses: $e");
    }
  }

  Future<void> _fetchBillings(int hallId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/billings/$hallId"));
      if (response.statusCode == 200) {
        _billings = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("❌ Error fetching billings: $e");
    }
  }

  void _filterCombinedData() {
    List<Map<String, dynamic>> combined = [];

    // Add Incomes
    if (_selectedFilter == "All" || _selectedFilter == "Income") {
      combined.addAll(_incomes.where((inc) {
        final date = DateTime.tryParse(inc["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year;
      }).map((inc) => {
        "type": "Income",
        "title": inc["reason"] ?? "Income",
        "amount": inc["amount"] ?? 0,
        "date": inc["created_at"],
      }));

      // Billings
      combined.addAll(_billings.where((b) {
        final date = DateTime.tryParse(b["updated_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year;
      }).map((b) => {
        "type": "Income",
        "title": "Billing for Booking ID: ${b["booking_id"] ?? "-"}",
        "amount": b["total"] ?? 0,
        "date": b["updated_at"],
      }));

      // Booking Advances
      combined.addAll(_bookings.where((bk) {
        final date = DateTime.tryParse(bk["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year &&
            (double.tryParse(bk["advance"].toString()) ?? 0) > 0;
      }).map((bk) => {
        "type": "Income",
        "title": "Advance for Booking ID: ${bk["booking_id"] ?? "-"}",
        "amount": bk["advance"] ?? 0,
        "date": bk["created_at"],
      }));
    }

    // Add Expenses
    if (_selectedFilter == "All" || _selectedFilter == "Expense") {
      combined.addAll(_expenses.where((e) {
        final date = DateTime.tryParse(e["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year;
      }).map((e) => {
        "type": "Expense",
        "title": e["reason"] ?? "-",
        "amount": e["amount"] ?? 0,
        "date": e["created_at"],
      }));
    }

    // Add Drawing In
    if (_selectedFilter == "All" || _selectedFilter == "Drawing In") {
      combined.addAll(_drawing.where((d) {
        final date = DateTime.tryParse(d["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year &&
            (d["type"].toString().toLowerCase() == "in");
      }).map((d) => {
        "type": "Drawing In",
        "title": d["reason"] ?? "Drawing In",
        "amount": d["amount"] ?? 0,
        "date": d["created_at"],
      }));
    }

    // Add Drawing Out
    if (_selectedFilter == "All" || _selectedFilter == "Drawing Out") {
      combined.addAll(_drawing.where((d) {
        final date = DateTime.tryParse(d["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year &&
            (d["type"].toString().toLowerCase() == "out");
      }).map((d) => {
        "type": "Drawing Out",
        "title": d["reason"] ?? "Drawing Out",
        "amount": d["amount"] ?? 0,
        "date": d["created_at"],
      }));
    }

    // Sort by date descending
    combined.sort((a, b) {
      DateTime da = DateTime.tryParse(a["date"] ?? "") ?? DateTime.now();
      DateTime db = DateTime.tryParse(b["date"] ?? "") ?? DateTime.now();
      return db.compareTo(da);
    });

    setState(() {
      _filteredData = combined;
      _isFetching = false;
    });
  }

  Future<void> _pickMonthYear() async {
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: scaffoldBackground.withValues(alpha:0.95),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Select Month and Year",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _monthDropdown(selectedMonth, (val) => selectedMonth = val)),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(child: _yearDropdown(selectedYear, (val) => selectedYear = val)),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: primaryColor))),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: cardColor),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(selectedYear, selectedMonth);
                          _filterCombinedData();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _monthDropdown(int value, Function(int) onChanged) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: "Month",
        labelStyle: TextStyle(color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownColor: scaffoldBackground,
      items: List.generate(12, (index) {
        final m = index + 1;
        return DropdownMenuItem(value: m, child: Text(DateFormat.MMMM().format(DateTime(0, m))));
      }),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }

  Widget _yearDropdown(int value, Function(int) onChanged) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: "Year",
        labelStyle: TextStyle(color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownColor: scaffoldBackground,
      items: List.generate(30, (index) {
        final y = DateTime.now().year - 10 + index;
        return DropdownMenuItem(value: y, child: Text(y.toString()));
      }),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
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
                ),
              ),
            ),
          ),
          ClipOval(
            child: hall['logo'] != null
                ? Image.memory(base64Decode(hall['logo']), width: 70, height: 70, fit: BoxFit.cover)
                : const Icon(Icons.home_work, color: Colors.white, size: 35),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard(Map<String, dynamic> item) {
    late Color amountColor;
    late IconData iconData;

    switch (item["type"]) {
      case "Income":
        amountColor = Colors.green.shade700;
        iconData = Icons.arrow_downward;
        break;
      case "Expense":
        amountColor = Colors.red.shade700;
        iconData = Icons.arrow_upward;
        break;
      case "Drawing In":
        amountColor = Colors.teal.shade700;
        iconData = Icons.south_west; // inward arrow style
        break;
      case "Drawing Out":
        amountColor = Colors.orange;
        iconData = Icons.north_east; // outward arrow style
        break;
      default:
        amountColor = Colors.grey.shade700;
        iconData = Icons.info_outline;
    }

    return Card(
      color: backgroundColor,
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(iconData, color: amountColor),
        title: Text(
          item["title"],
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          item["date"] != null
              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item["date"]))
              : "",
          style: TextStyle(
            color: primaryColor,
            fontSize: 13,
          ),
        ),
        trailing: Text(
          "₹${item["amount"]}",
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totals = _calculateTotals();

    final income = totals["income"] ?? 0.0;
    final expense = totals["expense"] ?? 0.0;
    final drawingIn = totals["drawingIn"] ?? 0.0;
    final drawingOut = totals["drawingOut"] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // === Row 1: Income & Expense ===
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Income
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Income",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${income.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),

              // Expense
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Expense",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${expense.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14), // space between rows

          // === Row 2: Drawing In & Drawing Out ===
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drawing In
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Drawing In",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${drawingIn.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),

              // Drawing Out
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Drawing Out",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${drawingOut.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _buildFinanceCard(Map<String, dynamic> item) {
  //   final bool isIncome = item["type"] == "Income";
  //   final Color amountColor = isIncome ? Colors.green.shade700 : Colors.red.shade700;
  //
  //   return Card(
  //     color: backgroundColor,
  //     elevation: 3,
  //     margin: const EdgeInsets.symmetric(vertical: 6),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: ListTile(
  //       leading: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: amountColor),
  //       title: Text(item["title"], style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
  //       subtitle: Text(
  //         "${isIncome ? 'Income' : 'Expense'}: ₹${item["amount"]}",
  //         style: TextStyle(color: amountColor, fontWeight: FontWeight.w600),
  //       ),
  //       trailing: Text(
  //         item["date"] != null
  //             ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item["date"]))
  //             : "",
  //         style: TextStyle(color: primaryColor, fontSize: 12),
  //       ),
  //     ),
  //   );
  // }

  Future<void> _fetchHallDetails(int hallId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/halls/$hallId'));
      if (response.statusCode == 200) {
        hallDetails = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Error fetching hall details: $e");
    } finally {
      setState(() {});
    }
  }

  Widget _buildFilterChips() {
    final row1Filters = ["All", "Income", "Expense"];
    final row2Filters = ["Drawing In", "Drawing Out"];

    Widget buildRow(List<String> filters) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter;
                  _filterCombinedData();
                });
              },
              selectedColor: primaryColor,
              backgroundColor: backgroundColor,
              labelStyle: TextStyle(
                color: isSelected ? backgroundColor : primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: [
        buildRow(row1Filters),
        buildRow(row2Filters),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Finance Overview", style: TextStyle(color: Color(0xFFD8C9A9))),
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
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hallDetails != null) _buildHallCard(hallDetails!),
            const SizedBox(height: 16),
            _buildMonthPickerButton(),
            const SizedBox(height: 10),
            _buildFilterChips(),
            const SizedBox(height: 12),
            _buildSummaryCard(),
            const SizedBox(height: 12),
            if (_filteredData.isEmpty)
              Center(
                child: Text(
                  "No records found for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.",
                  style: TextStyle(color: primaryColor, fontSize: 16),
                ),
              )
            else
              ..._filteredData.map(_buildFinanceCard),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthPickerButton() {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: cardColor,
        ),
        onPressed: _pickMonthYear,
        child: Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
      ),
    );
  }
}
