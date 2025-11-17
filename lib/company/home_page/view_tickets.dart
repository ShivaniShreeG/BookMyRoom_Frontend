import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // for date formatting
import '../../../public/config.dart';

class ViewTicketsPage extends StatefulWidget {
  final dynamic hall;

  const ViewTicketsPage({super.key, required this.hall});

  @override
  State<ViewTicketsPage> createState() => _ViewTicketsPageState();
}

class _ViewTicketsPageState extends State<ViewTicketsPage> {
  final Color primaryColor = const Color(0xFF5B6547); // Olive Green 🌿
  final Color backgroundColor = const Color(0xFFD8C9A9); // Muted Tan 🏺
  final Color surfaceColor = const Color(0xFFECE5D8);

  bool _isLoading = true;
  List<dynamic> _messages = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/submit-ticket/hall/${widget.hall['hall_id']}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages = (data is List) ? data : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
          "❌ Failed to load messages (Code: ${response.statusCode}).";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "❌ Error fetching messages: $e";
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return "Unknown Date";
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        title: Text(
          "Tickets - ${widget.hall['name'] ?? 'Hall'}",
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: backgroundColor,
            onPressed: _fetchMessages,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: primaryColor, fontSize: 16),
        ),
      )
          : _messages.isEmpty
          ? Center(
        child: Text(
          "No tickets found for this hall.",
          style: TextStyle(color: primaryColor, fontSize: 16),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchMessages,
        color: primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final ticket = _messages[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket['issue'] ?? 'No issue provided',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person, color: primaryColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "User ID: ${ticket['user_id'] ?? 'Unknown'}",
                        style: TextStyle(
                          color: primaryColor.withValues(alpha:0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: primaryColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(ticket['created_at']),
                        style: TextStyle(
                          color: primaryColor.withValues(alpha:0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
