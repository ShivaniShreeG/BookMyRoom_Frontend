import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import 'create_admin.dart';
import 'app_payment.dart';
import 'default_value_page.dart';
import 'add_peak_hour.dart';
import 'add_instruction_page.dart';
import 'submit.dart';
import 'add_facilitator.dart';
import 'add_room.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  String? lodgeName;
  String? lodgeAddress;
  String? lodgeLogo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHallData();
  }

  Future<void> _fetchHallData() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");

    if (lodgeId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/lodges/$lodgeId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          lodgeName = data["name"];
          lodgeAddress = data["address"];
          lodgeLogo = data["logo"];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: royal)),
      );
    }

    return Scaffold(
      backgroundColor: royalLight.withValues(alpha: 0.2),
      body: SingleChildScrollView(
        child: Container(padding: const EdgeInsets.all(20),
          // decoration: BoxDecoration(
          //   gradient: LinearGradient(
          //       begin: AlignmentGeometry.topCenter,
          //       end: AlignmentGeometry.bottomCenter,
          //       colors: [
          //     Colors.teal.shade100.withValues(alpha: 0.1),
          //     Colors.teal.shade200.withValues(alpha: 0.2),
          //     Colors.teal.shade300.withValues(alpha: 0.3),
          //     Colors.teal.shade400.withValues(alpha: 0.4),
          //     Colors.teal.shade500.withValues(alpha: 0.5),
          //     Colors.teal.shade600.withValues(alpha: 0.6),
          //     Colors.teal.shade700.withValues(alpha: 0.7),
          //     Colors.teal.shade800.withValues(alpha: 0.8),
          //   ])
          // ),
          child: Column(
            children: [
              // 🔹 Hall Card
              if (lodgeName != null) _buildHallCard(),
              const SizedBox(height: 20),
              // 🔹 Manage Card
              _buildManageCard(screenWidth),
              const SizedBox(height: 20),
              _buildExpenseCard(screenWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHallCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: royal, // ✅ Border color
          width: 1.5,               // ✅ Border thickness
        ),
      ),
      color: Colors.white,
      // color: Colors.teal.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // ✅ Aligns avatar & text top-to-top
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: royalLight,
              backgroundImage: (lodgeLogo != null && lodgeLogo!.isNotEmpty)
                  ? MemoryImage(base64Decode(lodgeLogo!))
                  : null,
              child: (lodgeLogo == null || lodgeLogo!.isEmpty)
                  ? const Icon(Icons.home_work_rounded, size: 35, color: royal)
                  : null,
            ),
            const SizedBox(width: 16),
            // ✅ Flexible layout like your scaled version
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lodgeName ?? "Unknown Hall",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                    maxLines: 2, // ✅ Allow up to 2 lines (flexible title)
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lodgeAddress ?? "No address available",
                    style: const TextStyle(
                      fontSize: 14,
                      color: royal,
                    ),
                    maxLines: 3, // ✅ Allow up to 3 lines
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(double screenWidth) {
    final buttonSize = 70.0; // square buttons
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: royal, // ✅ Border color
          width: 1.5,                 // ✅ Border thickness
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Centered title + dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Service",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // const SizedBox(width:),
                GestureDetector(
                  onTap: () {
                    // Dropdown action
                  },
                  child: const Icon(
                    Icons.arrow_drop_down,
                    color: royal,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Buttons
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildManageButton(
                  icon: Icons.payment,
                  label: "App Payment",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AppPaymentPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.confirmation_num,
                  label: "Submit Tickets",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SubmitTicketPage()),
                    );
                  },
                  size: buttonSize,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageCard(double screenWidth) {
    final buttonSize = 70.0; // square buttons

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: royal, // ✅ Border color
          width: 1.5,                 // ✅ Border thickness
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Manage",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Dropdown action
                  },
                  child: const Icon(
                    Icons.arrow_drop_down,
                    color: royal,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Buttons
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildManageButton(
                  icon: Icons.admin_panel_settings,
                  label: "Admin",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateAdminPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.room_preferences,
                  label: "Rooms",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RoomsPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.access_time,
                  label: "Peak Hours",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PeakHoursPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.attach_money,
                  label: "Charges",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DefaultValuesPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.rule,
                  label: "Instruction",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HallInstructionsPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.domain_add,
                  label: "Facilitator",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddFacilitatorPage()),
                    );
                  },
                  size: buttonSize,
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double size,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              // color: const Color(0xFF5B6547),
              color: royalLight.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: royal.withValues(alpha:0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 32, color:Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size,
          height: 36, // keeps consistent spacing for text lines
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: royal,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
