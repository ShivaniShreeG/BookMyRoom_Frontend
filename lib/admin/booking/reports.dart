import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'finance_report/monthly_report_page.dart';
import 'finance_report/yearly_report_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../public/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/main_navigation.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Color primaryColor = const Color(0xFF5B6547);
  final Color scaffoldBackground = const Color(0xFFECE5D8);
  final Color cardColor = const Color(0xFFD8C9A9);
  final Color backgroundColor = const Color(0xFFD8C9A9);

  DateTime _selectedMonth = DateTime.now();
  int? selectedYear = DateTime.now().year; // ✅ default to current year
  Map<String, dynamic>? hallDetails;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId != null) {
      await _fetchHallDetails(hallId); // fetch hall info// fetch admins
    }
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
          shadowColor: primaryColor.withValues(alpha:0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: scaffoldBackground.withValues(alpha:0.98),
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
                    color: primaryColor,
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
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: scaffoldBackground.withValues(alpha:0.9),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    );

                    Widget monthDropdown = DropdownButtonFormField<int>(
                      initialValue: selectedMonth,
                      dropdownColor: scaffoldBackground.withValues(alpha:0.95),
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      iconEnabledColor: primaryColor,
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
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
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
                      dropdownColor: scaffoldBackground.withValues(alpha:0.95),
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      iconEnabledColor: primaryColor,
                      decoration: dropdownDecoration("Year"),
                      items: List.generate(30, (index) {
                        final year = DateTime.now().year - 10 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              year.toString(),
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
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
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: cardColor,
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
          backgroundColor: scaffoldBackground.withValues(alpha:0.95),
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
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 20),

                // 🔹 Styled Year Dropdown
                DropdownButtonFormField<int>(
                  initialValue: selected,
                  dropdownColor: scaffoldBackground, // dropdown background
                  style: TextStyle(
                    color: primaryColor, // dropdown text color
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  iconEnabledColor: primaryColor,
                  decoration: InputDecoration(
                    labelText: "Year",
                    labelStyle: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: scaffoldBackground,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  items: List.generate(30, (index) {
                    final year = DateTime.now().year - 10 + index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(
                        year.toString(),
                        style: TextStyle(color: primaryColor),
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
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: cardColor,
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
      // print("Error fetching hall details: $e");
    } finally {
      setState(() {});
    }
  }

  // 🌟 Section Header Builder
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: cardColor,
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
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Reports", style: TextStyle(color: Color(0xFFD8C9A9))),
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
                            "Generate Monthly Report for your hall.",
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
                            width: 180,
                            child: ElevatedButton(
                              onPressed: _pickMonthYear,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cardColor,
                                foregroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                                backgroundColor: primaryColor,
                                foregroundColor: cardColor,
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
                            "Generate Yearly Report for your hall.",
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
                            width: 150,
                            child: ElevatedButton(
                              onPressed: _pickYear,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cardColor,
                                foregroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                                backgroundColor: primaryColor,
                                foregroundColor: cardColor,
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
