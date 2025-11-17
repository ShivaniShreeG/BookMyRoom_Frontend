import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

class HallMessagesPage extends StatefulWidget {
  final dynamic hall;

  const HallMessagesPage({super.key, required this.hall});

  @override
  State<HallMessagesPage> createState() => _HallMessagesPageState();
}

class _HallMessagesPageState extends State<HallMessagesPage> {
  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFD8C9A9);
  final Color surfaceColor = const Color(0xFFECE5D8);

  bool _isLoading = true;
  List<dynamic> _messages = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  // 📩 Fetch all messages for this hall
  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/message/hall/${widget.hall['hall_id']}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages = data is List ? data : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
          "Failed to load messages (Code: ${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching messages: $e";
        _isLoading = false;
      });
    }
  }

  // ➕ Add a new message
  Future<void> _addMessage(String message) async {
    final body = jsonEncode({
      'hall_id': widget.hall['hall_id'],
      'message': message,
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/message'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 201) {
        _fetchMessages();
      } else {
        _showSnackBar("Failed to add message (${response.statusCode})", true);
      }
    } catch (e) {
      _showSnackBar("Error adding message: $e", true);
    }
  }

  // 📝 Edit message text (message_id remains same)
  Future<void> _editMessage(int messageId, String newText) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/message/$messageId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': newText}),
      );

      if (response.statusCode == 200) {
        _fetchMessages();
      } else {
        _showSnackBar("Failed to edit message (${response.statusCode})", true);
      }
    } catch (e) {
      _showSnackBar("Error editing message: $e", true);
    }
  }

  // ❌ Delete message
  Future<void> _deleteMessage(int messageId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/message/$messageId'),
      );

      if (response.statusCode == 200) {
        _fetchMessages();
      } else {
        _showSnackBar("Failed to delete message (${response.statusCode})", true);
      }
    } catch (e) {
      _showSnackBar("Error deleting message: $e", true);
    }
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // 🧾 Dialog to add or edit message
  Future<void> _showMessageDialog({String? existingText, int? messageId}) async {
    final controller = TextEditingController(text: existingText ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          existingText == null ? "Add Message" : "Edit Message",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Enter your message...",
            filled: true,
            fillColor: backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: backgroundColor,
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context);
              if (messageId == null) {
                _addMessage(text);
              } else {
                _editMessage(messageId, text);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          "Messages - ${widget.hall['name']}",
          style: TextStyle(color: backgroundColor),
        ),
        iconTheme: IconThemeData(color: backgroundColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMessages,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () => _showMessageDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(color: primaryColor),
        ),
      )
          : _messages.isEmpty
          ? Center(
        child: Text(
          "No messages for this hall yet.",
          style: TextStyle(color: primaryColor),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          return Card(
            color: backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primaryColor, width: 1),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                msg['message'] ?? 'No content',
                style: TextStyle(color: primaryColor),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    color: primaryColor,
                    onPressed: () => _showMessageDialog(
                      existingText: msg['message'],
                      messageId: msg['id'],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    color: Colors.red[700],
                    onPressed: () => _deleteMessage(msg['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
