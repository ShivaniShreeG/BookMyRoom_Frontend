import 'package:flutter/material.dart';
import 'create_admin.dart';
import 'block_page.dart';
import 'delete_page.dart';
import 'edit_hall.dart';
import 'payment_history.dart';
import 'add_message.dart';
import 'view_tickets.dart';

class ManagePage extends StatelessWidget {
  final dynamic selectedHall;

  const ManagePage({super.key, required this.selectedHall});

  @override
  Widget build(BuildContext context) {
    if (selectedHall == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3EAD6),
        body: Center(
          child: Text(
            "⚠ No hall selected",
            style: TextStyle(
              color: Color(0xFF5B6547),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8),
      appBar: AppBar(
        title: Text(
          "Manage ${selectedHall['name'] ?? 'Hall'}",
          style: const TextStyle(
            color: Color(0xFFD8C9A9),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF5B6547),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),

            // Create Admin card
            _buildMainCard(
              context,
              title: "Create",
              icon: Icons.person_add,
              label: "Admin",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateAdminPage(hall: selectedHall),
                  ),
                );
              },
            ),

            const SizedBox(height: 25),

            // One Action card with both Block and Delete buttons
            _buildActionCard(context),
            const SizedBox(height: 25),

            _buildViewCard(context),

          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 260,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        shadowColor: Colors.black26,
        color: const Color(0xFFD8C9A9), // Solid card color
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF5B6547),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 0),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF5B6547), size: 28),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: screenWidth * 0.20,
                  height: screenWidth * 0.20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B6547),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26.withValues(alpha:0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, size: 44, color: const Color(0xFFD8C9A9)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF5B6547),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context) {
    final actions = [
      {
        'icon': Icons.block,
        'label': 'Block',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BlockHallPage(hall: selectedHall)),
          );
        },
      },
      {
        'icon': Icons.edit,
        'label': 'Edit',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditHallPage(hall: selectedHall)),
          );
        },
      },
      {
        'icon': Icons.delete,
        'label': 'Delete',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DeleteHallPage(hall: selectedHall)),
          );
        },
      },
      {
        'icon': Icons.message,
        'label': 'Message',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HallMessagesPage(hall: selectedHall)),
          );
        },
      },
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      shadowColor: Colors.black26,
      color: const Color(0xFFD8C9A9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  "Actions",
                  style: TextStyle(
                    color: Color(0xFF5B6547),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: Color(0xFF5B6547), size: 28),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ Use Wrap instead of Row for flexibility
            Wrap(
              spacing: 20, // horizontal spacing
              runSpacing: 16, // vertical spacing
              alignment: WrapAlignment.center,
              children: actions
                  .map(
                    (action) => _buildActionButton(
                  context,
                  icon: action['icon'] as IconData,
                  label: action['label'] as String,
                  onTap: action['onTap'] as VoidCallback,
                  color: const Color(0xFF5B6547),
                ),
              )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewCard(BuildContext context) {
    // final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 260,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        shadowColor: Colors.black26,
        color: const Color(0xFFD8C9A9), // Solid card color
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "View",
                    style: TextStyle(
                      color: Color(0xFF5B6547),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 0),
                  Icon(Icons.arrow_drop_down, color: Color(0xFF5B6547), size: 28),
                ],
              ),
              const Spacer(),

              // Buttons Row — reduced spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // _buildActionButton(
                  //   context,
                  //   icon: Icons.block,
                  //   label: "Block",
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (_) => BlockHallPage(hall: selectedHall),
                  //       ),
                  //     );
                  //   },
                  // ),
                  // const SizedBox(width: 20), // smaller fixed gap
                  // _buildActionButton(
                  //   context,
                  //   icon: Icons.edit,
                  //   label: "Edit",
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (_) => EditHallPage(hall: selectedHall),
                  //       ),
                  //     );
                  //   },
                  // ),
                  // const SizedBox(width: 20),
                  _buildActionButton(
                    context,
                    icon: Icons.history,
                    label: "Payment history",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionHistoryPage(hall: selectedHall),
                        ),
                      );
                    },
                    color: const Color(0xFF5B6547),
                  ),
                  const SizedBox(width: 20), // smaller fixed gap
                  _buildActionButton(
                    context,
                    icon: Icons.confirmation_num,
                    label: "Tickets",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewTicketsPage(hall: selectedHall),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        Color? color,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: screenWidth * 0.20,
            height: screenWidth * 0.20,
            decoration: BoxDecoration(
              color: color ?? const Color(0xFF5B6547),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26.withValues(alpha:0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 42, color: const Color(0xFFD8C9A9)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5B6547),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
