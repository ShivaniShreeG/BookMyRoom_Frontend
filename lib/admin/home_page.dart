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
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double drawingIn = 0.0;
  double drawingOut = 0.0;
  double currentBalance = 0.0;
  List<dynamic> roomStats = [];

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
      await fetchRoomStats(lodgeId);
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

  Future<void> fetchRoomStats(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/home/availability/7days/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          roomStats = jsonDecode(response.body);
        });
      } else {
        _showMessage("Failed to load room availability", isError: true);
      }
    } catch (e) {
      _showMessage("Error loading room stats: $e", isError: true);
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
          drawingIn = (data['totalDrawingIn'] ?? 0).toDouble();
          drawingOut = (data['totalDrawingOut'] ?? 0).toDouble();
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
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    final double textScale = screenWidth / 375;
    final double boxScale = screenHeight / 812;

    return Scaffold(
        backgroundColor: royalLight.withValues(alpha: 0.2),
        body: Container(
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
            if (roomStats.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 20 * textScale),
                child: _buildRoomAvailabilityBox(roomStats, textScale, boxScale),
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

  Widget _buildRoomAvailabilityBox(
      List<dynamic> stats, double textScale, double boxScale) {
    return buildRoomTypeCards(stats, textScale, boxScale);
  }

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

  Widget buildRoomTypeCards(List<dynamic> stats, double textScale, double boxScale) {
    // Group rooms by room_type
    Map<String, List<dynamic>> grouped = {};
    for (var r in stats) {
      String type = r['room_type'];
      grouped.putIfAbsent(type, () => []);
      grouped[type]!.add(r);
    }

    return Column(
      children: grouped.entries.map((entry) {
        final roomType = entry.key;
        final rooms = entry.value;
        final dates = rooms.first["days"];

        // Calculate total rooms for this type
        final int totalRoomCount = rooms.fold<int>(
          0,
              (sum, r) => sum + ((r["total_count"] ?? 0) as num).toInt(),
        );

        return Container(
          margin: EdgeInsets.only(bottom: 20 * boxScale),
          padding: EdgeInsets.all(16 * boxScale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20 * boxScale),
            border: Border.all(color: royal, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Center(
                child: Text(
                  "$roomType Rooms ($totalRoomCount)",
                  style: TextStyle(
                    fontSize: 18 * textScale,
                    fontWeight: FontWeight.bold,
                    color: royal,
                  ),
                ),
              ),
              SizedBox(height: 16 * boxScale),

              // Table inside Padding for spacing
              Padding(
                padding: EdgeInsets.only(top: 8.0 * boxScale),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.all(color: royal, width: 1.2),
                    columnWidths: {
                      0: FixedColumnWidth(120), // First column wider
                      for (int i = 1; i <= dates.length; i++) i: FixedColumnWidth(60),
                    },
                    children: [
                      // Table Header
                      TableRow(
                        decoration: BoxDecoration(color: royalLight.withValues(alpha: 0.2)),
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 12 * boxScale),
                            child: Center(
                              child: Text(
                                "Room Name",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14 * textScale,
                                  color: royal,
                                ),
                              ),
                            ),
                          ),
                          ...dates.map((d) => Container(
                            padding: EdgeInsets.symmetric(vertical: 12 * boxScale),
                            child: Center(
                              child: Text(
                                "${d["date"].substring(8)}-${d["date"].substring(5,7)}", // DD-MM
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13 * textScale,
                                  color: royal,
                                ),
                              ),
                            ),
                          )),
                        ],
                      ),

                      // Table Rows
                      ...rooms.map((room) {
                        return TableRow(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 12 * boxScale),
                              child: Center(
                                child: Text(
                                  "\t${room["room_name"]} (${room["total_count"]})",
                                  style: TextStyle(
                                    fontSize: 14 * textScale,
                                    fontWeight: FontWeight.w500,
                                    color: royal,
                                  ),
                                ),
                              ),
                            ),
                            ...room["days"].map((d) => Container(
                              padding: EdgeInsets.symmetric(vertical: 12 * boxScale),
                              child: Center(
                                child: Text(
                                  d["available_count"].toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15 * textScale,
                                    color: royal,
                                  ),
                                ),
                              ),
                            )),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
}
