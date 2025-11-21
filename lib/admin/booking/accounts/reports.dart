import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'reports/monthly_report_page.dart';
import 'reports/yearly_report_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../public/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/main_navigation.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {

  DateTime _selectedMonth = DateTime.now();
  int? selectedYear = DateTime.now().year; // ✅ default to current year
  Map<String, dynamic>? hallDetails;
  @override
  void initState() {
    super.initState();
    _fetchHallDetails();
  }
  
  // 🌟 Modern Month-Year Picker
  Future<void> _pickMonthYear() async {
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          elevation: 8,
          shadowColor: royal.withValues(alpha:0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🔹 Title
                Text(
                  'Select Month and Year',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: royal,
                  ),
                ),
                const SizedBox(height: 20),

                // 🔹 Dropdown Fields
                LayoutBuilder(
                  builder: (context, constraints) {
                    bool isNarrow = constraints.maxWidth < 360;

                    // Common dropdown styling
                    InputDecoration dropdownDecoration(String label) => InputDecoration(
                      labelText: label,
                      labelStyle: TextStyle(
                        color: royal,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: royal, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: royal, width: 2),
                      ),
                    );

                    Widget monthDropdown = DropdownButtonFormField<int>(
                      initialValue: selectedMonth,
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: royal,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      iconEnabledColor: royal,
                      decoration: dropdownDecoration("Month"),
                      items: List.generate(12, (index) {
                        final month = index + 1;
                        final monthName = DateFormat.MMMM().format(DateTime(0, month));
                        return DropdownMenuItem(
                          value: month,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              monthName,
                              style: TextStyle(color: royal, fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) selectedMonth = val;
                      },
                    );

                    Widget yearDropdown = DropdownButtonFormField<int>(
                      initialValue: selectedYear,
                      dropdownColor:Colors.white,
                      style: TextStyle(
                        color: royal,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      iconEnabledColor: royal,
                      decoration: dropdownDecoration("Year"),
                      items: List.generate(30, (index) {
                        final year = DateTime.now().year - 10 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              year.toString(),
                              style: TextStyle(color: royal, fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) selectedYear = val;
                      },
                    );

                    return isNarrow
                        ? Column(
                      children: [
                        monthDropdown,
                        const SizedBox(height: 12),
                        yearDropdown,
                      ],
                    )
                        : Row(
                      children: [
                        Expanded(child: monthDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: yearDropdown),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 25),

                // 🔹 Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: royal,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(selectedYear, selectedMonth);
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
    );
  }

  // 🌟 Year Picker
  Future<void> _pickYear() async {
    int selected = selectedYear ?? DateTime.now().year;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🔹 Title
                Text(
                  'Select Year',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: royal,
                  ),
                ),
                const SizedBox(height: 20),

                // 🔹 Styled Year Dropdown
                DropdownButtonFormField<int>(
                  initialValue: selected,
                  dropdownColor: Colors.white, // dropdown background
                  style: TextStyle(
                    color: royal, // dropdown text color
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  iconEnabledColor: royal,
                  decoration: InputDecoration(
                    labelText: "Year",
                    labelStyle: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: royal, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: royal, width: 2),
                    ),
                  ),
                  items: List.generate(30, (index) {
                    final year = DateTime.now().year - 10 + index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(
                        year.toString(),
                        style: TextStyle(color: royal),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) selected = val;
                  },
                ),

                const SizedBox(height: 25),

                // 🔹 Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: royal,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          selectedYear = selected;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
    );
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

  // 🌟 Section Header Builder
  Widget _sectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: royal, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: royal,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // 🌟 Build UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Reports", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Add this line at the top
            if (hallDetails != null)
              _buildHallCard(hallDetails!),
            const SizedBox(height: 20),

            // Keep your current Center content
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // fit content
                    children: [
                      // MONTHLY REPORT
                      _sectionContainer("MONTHLY REPORT", [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            "Generate Monthly Report for your lodge.",
                            style: TextStyle(
                              color: royal,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Center(
                          child: SizedBox(
                            width: 180,
                            child: ElevatedButton(
                              onPressed: _pickMonthYear,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: royal,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: royal,width: 1)
                              ),
                              child: Text(
                                DateFormat('MMMM yyyy').format(_selectedMonth),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MonthlyReportPage(
                                      month: _selectedMonth.month,
                                      year: _selectedMonth.year,
                                      hallDetails: hallDetails!, // ✅ pass hall details
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: royal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                "Generate Monthly Report",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 20),
                      // YEARLY REPORT (same as before)
                      _sectionContainer("YEARLY REPORT", [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            "Generate Yearly Report for your lodge.",
                            style: TextStyle(
                              color: royal,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Center(
                          child: SizedBox(
                            width: 150,
                            child: ElevatedButton(
                              onPressed: _pickYear,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: royal,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: royal,width: 1)
                              ),
                              child: Text(
                                selectedYear.toString(),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => YearlyReportPage(
                                      year: selectedYear!,
                                      hallDetails: hallDetails!, // ✅ pass hall details
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: royal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                "Generate Yearly Report",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
