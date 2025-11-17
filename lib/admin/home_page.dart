import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../public/config.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? selectedHall;
  bool _isLoading = true;
  Map<String, dynamic>? muhurthamCount;
  int? completedCount;
  int? upcomingTotal;
  Map<String, dynamic>? upcomingMonths;
  Map<String, dynamic>? upcomingYearData;
  int? upcomingYearTotal;
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double totalBilling = 0.0;
  double totalAdvance = 0.0;
  double drawingIn = 0.0;
  double drawingOut = 0.0;
  double currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadHall();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:  TextStyle(
            color: isError ? Colors.redAccent.shade400 : royal,
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

  Future<void> _loadHall() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt('lodgeId');
    if (lodgeId != null) {
      await fetchHallDetails(lodgeId);
      await fetchCurrentBalance(lodgeId);
      await fetchMuharthamCount(lodgeId);
      await fetchCompletedEvents(lodgeId);
      await fetchUpcomingEvents(lodgeId);
      await fetchUpcomingEventsYear(lodgeId);
    } else {
      setState(() => _isLoading = false);
      _showMessage("No Lodge ID found in saved data", isError: true);
    }
  }

  Future<void> fetchHallDetails(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/lodges/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          selectedHall = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showMessage(
          "Failed to load lodge details (Code: ${response.statusCode})",
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error connecting to server: $e", isError: true);
    }
  }

  Future<void> fetchMuharthamCount(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/home/peak-hour/upcoming/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          muhurthamCount = data['months'];
        });
      } else {
        _showMessage("Failed to load muhurtham data", isError: true);
      }
    } catch (e) {
      _showMessage("Error fetching muhurtham data: $e", isError: true);
    }
  }

  Future<void> fetchCompletedEvents(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/home/completed/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          completedCount = data['completed_events'];
        });
      } else {
        _showMessage("Failed to fetch completed events", isError: true);
      }
    } catch (e) {
      _showMessage("Error fetching completed events: $e", isError: true);
    }
  }

  Future<void> fetchUpcomingEvents(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/home/upcoming/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          upcomingTotal = data['total'];
          upcomingMonths = Map<String, dynamic>.from(data['months']);
        });
      } else {
        _showMessage("Failed to fetch upcoming events", isError: true);
      }
    } catch (e) {
      _showMessage("Error fetching upcoming events: $e", isError: true);
    }
  }

  Future<void> fetchUpcomingEventsYear(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/home/upcoming/year/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          upcomingYearTotal = data['total'];
          upcomingYearData = Map<String, dynamic>.from(data['months']);
        });
      } else {
        _showMessage("Failed to fetch yearly upcoming events", isError: true);
      }
    } catch (e) {
      _showMessage("Error fetching yearly upcoming events: $e", isError: true);
    }
  }

  Future<void> fetchCurrentBalance(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/home/current-balance/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          totalIncome = (data['totalIncome'] ?? 0).toDouble();
          totalExpense = (data['totalExpense'] ?? 0).toDouble();
          totalBilling = (data['totalBilling'] ?? 0).toDouble();
          totalAdvance = (data['totalAdvance'] ?? 0).toDouble();
          drawingIn = (data['drawingIn'] ?? 0).toDouble();
          drawingOut = (data['drawingOut'] ?? 0).toDouble();
          currentBalance = (data['currentBalance'] ?? 0).toDouble();
        });
      } else {
        _showMessage("Failed to fetch current balance", isError: true);
      }
    } catch (e) {
      _showMessage("Error fetching current balance: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 📱 MediaQuery scaling factors
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    final double textScale = screenWidth / 375;
    final double boxScale = screenHeight / 812;

    return Scaffold(
        backgroundColor: royalLight.withValues(alpha: 0.2),
        body: Container(
          // 🟢 Apply gradient only when not loading, else plain white background
          //   decoration: BoxDecoration(
          //     gradient: _isLoading
          //         ? null
          //         : LinearGradient(
          //       begin: Alignment.topCenter,
          //       end: Alignment.bottomCenter,
          //       colors: [
          //         Colors.teal.shade100.withValues(alpha: 0.1),
          //         Colors.teal.shade200.withValues(alpha: 0.2),
          //         Colors.teal.shade300.withValues(alpha: 0.3),
          //         Colors.teal.shade400.withValues(alpha: 0.4),
          //         Colors.teal.shade500.withValues(alpha: 0.5),
          //         Colors.teal.shade600.withValues(alpha: 0.6),
          //         Colors.teal.shade700.withValues(alpha: 0.7),
          //         Colors.teal.shade800.withValues(alpha: 0.8),
          //       ],
          //     ),
          //     color: _isLoading ? Colors.white : null,
          //   ),
            child:_isLoading
          ? const Center(
        child: CircularProgressIndicator(color: royal),
      )
          : SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (selectedHall != null)
              Align(
                alignment: Alignment.center,
                child: _buildHallCard(selectedHall!, textScale, boxScale),
              ),
            if (upcomingYearData != null)
              Padding(
                padding: EdgeInsets.only(top: 20 * boxScale),
                child: _buildUpcomingYearTable(textScale, boxScale),
              ),

            if (completedCount != null)
              Padding(
                padding: EdgeInsets.only(top: 20 * textScale),
                child: _buildCompletedBox(completedCount!, textScale, boxScale),
              ),

            if (muhurthamCount != null)
              Padding(
                padding: EdgeInsets.only(top: 20 * boxScale),
                child: _buildMuharthamTable(textScale, boxScale),
              ),
              Padding(
                padding: EdgeInsets.only(top: 20 * textScale),
                child: _buildCurrentBalanceBox(currentBalance, textScale, boxScale),
              ),
          ],
        ),
      ),
    )
    )
    );
  }

  /// 🔹 Hall Details Card
  Widget _buildHallCard(
      Map<String, dynamic> hall,
      double textScale,
      double boxScale,
      ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20 * boxScale),
        side: const BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16 * boxScale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 40 * boxScale,
              backgroundColor: royalLight,
              backgroundImage: hall['logo'] != null
                  ? MemoryImage(base64Decode(hall['logo']))
                  : null,
              child: hall['logo'] == null
                  ? Icon(Icons.home_work_rounded,
                  size: 35 * boxScale, color: royal)
                  : null,
            ),
            SizedBox(width: 16 * boxScale),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hall['name'] ?? 'No Name',
                    style: TextStyle(
                      fontSize: 18 * textScale,
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4 * boxScale),
                  Text(
                    hall['address'] ?? 'No Address',
                    style: TextStyle(
                      fontSize: 14 * textScale,
                      color: royal,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuharthamTable(double textScale, double boxScale) {


    if (muhurthamCount == null || muhurthamCount!.isEmpty) {
      return const SizedBox.shrink();
    }
    // final currentYear = DateTime.now().year; // ✅ Get current year

    final months = muhurthamCount!.keys.toList();
    final counts = muhurthamCount!.values.toList();

    // Split into two halves (top 6, next 6)
    final midIndex = (months.length / 2).ceil();
    final topMonths = months.take(midIndex).toList();
    final bottomMonths = months.skip(midIndex).toList();

    final topCounts = counts.take(midIndex).toList();
    final bottomCounts = counts.skip(midIndex).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16 * boxScale),
        side: const BorderSide(color: royal, width: 1.5),
      ),
      color: Colors.white, // main card color
      shadowColor: royal.withValues(alpha:0.4),
      child: Padding(
        padding: EdgeInsets.all(12 * boxScale),
        child: Column(
          children: [
            Text(
              'Number of Muhurthams', // ✅ Added current year
              style: TextStyle(
                fontSize: 16 * textScale,
                fontWeight: FontWeight.bold,
                color: royal,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            /// 🔹 First 6 months
            Table(
              border: TableBorder.all(color: royal.withValues(alpha:0.6), width: 0.8),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: royal.withValues(alpha:0.9),
                  ),
                  children: topMonths.map((m) {
                    return Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Center(
                        child: Text(
                          m,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12 * textScale,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.3),
                  ),
                  children: topCounts.map((c) {
                    return Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Center(
                        child: Text(
                          '$c',
                          style: TextStyle(
                            color: royal,
                            fontWeight: FontWeight.w600,
                            fontSize: 12 * textScale,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// 🔹 Next 6 months (if available)
            if (bottomMonths.isNotEmpty)
              Table(
                border: TableBorder.all(color: royal.withValues(alpha:0.6), width: 0.8),
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: royal.withValues(alpha:0.9),
                    ),
                    children: bottomMonths.map((m) {
                      return Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Center(
                          child: Text(
                            m,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12 * textScale,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  TableRow(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.3),
                    ),
                    children: bottomCounts.map((c) {
                      return Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Center(
                          child: Text(
                            '$c',
                            style: TextStyle(
                              color: royal,
                              fontWeight: FontWeight.w600,
                              fontSize: 12 * textScale,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedBox(int count, double textScale, double boxScale) {


    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // 🎨 Flat background color
        borderRadius: BorderRadius.circular(20 * boxScale),
        border: Border.all(
          color: royal,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 24 * boxScale,
          horizontal: 32 * boxScale,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🏁 Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                SizedBox(width: 8 * boxScale),
                Text(
                  "Completed Events (${DateTime.now().year})",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17 * textScale,
                    fontWeight: FontWeight.bold,
                    color: royal,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12 * boxScale),

            // 🔢 Animated total count
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: count),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) => Text(
                "$value",
                style: TextStyle(
                  fontSize: 34 * textScale,
                  fontWeight: FontWeight.w500,
                  color: royal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBalanceBox(double currentBalance, double textScale, double boxScale) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * boxScale),
        border: Border.all(
          color: royal,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 24 * boxScale,
          horizontal: 32 * boxScale,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 💰 Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 8 * boxScale),
                Text(
                  "Current Balance",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17 * textScale,
                    fontWeight: FontWeight.bold,
                    color: royal,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12 * boxScale),

            // 🔢 Animated Balance Amount
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: currentBalance),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) => Text(
                "₹${value.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 34 * textScale,
                  fontWeight: FontWeight.w500,
                  color: royal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingYearTable(double textScale, double boxScale) {
    if (upcomingYearData == null || upcomingYearData!.isEmpty) {
      return const SizedBox.shrink();
    }

    final months = upcomingYearData!.keys.toList();
    final counts = upcomingYearData!.values.toList();

    // Split 12 months into two rows of 6 each
    final mid = (months.length / 2).ceil();
    final firstHalfMonths = months.take(mid).toList();
    final secondHalfMonths = months.skip(mid).toList();

    final firstHalfCounts = counts.take(mid).toList();
    final secondHalfCounts = counts.skip(mid).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16 * boxScale),
        side: const BorderSide(color: royal, width: 1.5),
      ),
      color: Colors.white,
      shadowColor: royal.withValues(alpha:0.4),
      child: Padding(
        padding: EdgeInsets.all(12 * boxScale),
        child: Column(
          children: [
            Text(
              'Upcoming Events($upcomingYearTotal)',
              style: TextStyle(
                fontSize: 16 * textScale,
                fontWeight: FontWeight.bold,
                color: royal,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            /// 🔹 First 6 months
            Table(
              border: TableBorder.all(color: royal.withValues(alpha:0.6), width: 0.8),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: royal.withValues(alpha:0.9)),
                  children: firstHalfMonths.map((m) {
                    return Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Center(
                        child: Text(
                          m,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12 * textScale,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                TableRow(
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.3)),
                  children: firstHalfCounts.map((c) {
                    return Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Center(
                        child: Text(
                          '$c',
                          style: TextStyle(
                            color: royal,
                            fontWeight: FontWeight.w600,
                            fontSize: 12 * textScale,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// 🔹 Next 6 months
            if (secondHalfMonths.isNotEmpty)
              Table(
                border: TableBorder.all(color: royal.withValues(alpha:0.6), width: 0.8),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: royal.withValues(alpha:0.9)),
                    children: secondHalfMonths.map((m) {
                      return Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Center(
                          child: Text(
                            m,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12 * textScale,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  TableRow(
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.3)),
                    children: secondHalfCounts.map((c) {
                      return Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Center(
                          child: Text(
                            '$c',
                            style: TextStyle(
                              color: royal,
                              fontWeight: FontWeight.w600,
                              fontSize: 12 * textScale,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
