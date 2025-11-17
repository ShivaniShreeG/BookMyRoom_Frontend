import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';

class AddDrawingPage extends StatefulWidget {
  const AddDrawingPage({super.key});

  @override
  State<AddDrawingPage> createState() => _AddDrawingPageState();
}

class _AddDrawingPageState extends State<AddDrawingPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedType = "OUT"; // default value

  bool _isLoading = false;
  bool _isFetching = true;
  bool _showForm = false;
  int? _editingDrawingId;

  List<Map<String, dynamic>> _drawings = [];
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
      await _fetchHallDetails(hallId);
      await _fetchDrawings();
    }
  }

  Future<void> _fetchDrawings() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    if (hallId == null) return;

    try {
      final url = Uri.parse("$baseUrl/drawing/hall/$hallId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _drawings = List<Map<String, dynamic>>.from(data.reversed);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching drawings: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _submitDrawing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");
    final userId = prefs.getInt("userId");
    if (hallId == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Hall ID or User ID not found")),
      );
      setState(() => _isLoading = false);
      return;
    }

    final body = {
      "hall_id": hallId,
      "user_id": userId,
      "reason": _reasonController.text.trim(),
      "amount": double.parse(_amountController.text.trim()),
      "type": _selectedType, // 👈 added here

    };

    try {
      http.Response response;
      if (_editingDrawingId == null) {
        response = await http.post(
          Uri.parse("$baseUrl/drawing"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      } else {
        response = await http.patch(
          Uri.parse("$baseUrl/drawing/$_editingDrawingId"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingDrawingId == null
                ? "✅ Drawing added successfully"
                : "✅ Drawing updated successfully"),
          ),
        );

        _formKey.currentState!.reset();
        _reasonController.clear();
        _amountController.clear();

        setState(() {
          _editingDrawingId = null;
          _showForm = false;
        });

        _fetchDrawings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error submitting drawing: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDrawing(int drawingId) async {
    try {
      final url = Uri.parse("$baseUrl/drawing/$drawingId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() => _drawings.removeWhere((e) => e["id"] == drawingId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Drawing deleted successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to delete: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error deleting drawing: $e");
    }
  }

  void _showDeleteDialog(int drawingId, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Delete Drawing", style: TextStyle(color: primaryColor)),
        content: Text(
          "Do you want to delete the drawing for \"$reason\"?",
          style: TextStyle(color: primaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _deleteDrawing(drawingId);
            },
            child: Text("Confirm", style: TextStyle(color: backgroundColor)),
          ),
        ],
      ),
    );
  }

  void _editDrawing(Map<String, dynamic> drawing) {
    setState(() {
      _editingDrawingId = drawing["id"];
      _reasonController.text = drawing["reason"] ?? "";
      _amountController.text = drawing["amount"]?.toString() ?? "";
      _showForm = true;
    });
  }

  Widget _buildDrawingForm() {
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
              labeledTanRow(
                label: "Type",
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  dropdownColor: const Color(0xFFD8C9A9), // background of dropdown
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    color: primaryColor, // text color
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  iconEnabledColor: primaryColor, // dropdown arrow color
                  items: const [
                    DropdownMenuItem(
                      value: "IN",
                      child: Text("IN"),
                    ),
                    DropdownMenuItem(
                      value: "OUT",
                      child: Text("OUT"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              labeledTanRow(
                label: "Reason",
                child: TextFormField(
                  controller: _reasonController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: primaryColor),
                  cursorColor: primaryColor,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: "Enter Reason",
                    hintStyle: TextStyle(color: primaryColor, fontSize: 15),
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter reason" : null,
                ),
              ),
              const SizedBox(height: 16),
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
                    hintText: "Enter Amount",
                    hintStyle: TextStyle(color: primaryColor, fontSize: 15),
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
                      onPressed: _isLoading ? null : _submitDrawing,
                      child: _isLoading
                          ? CircularProgressIndicator(color: backgroundColor)
                          : Text(_editingDrawingId == null
                          ? "Add Drawing"
                          : "Update Drawing"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _editingDrawingId = null;
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

  Widget _buildDrawingCard(Map<String, dynamic> drawing) {
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drawing["reason"]?.toUpperCase() ?? "-",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${drawing["amount"] ?? "-"}",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: drawing["type"] == "IN"
                          ? Colors.green.withValues(alpha:0.15)
                          : Colors.red.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: drawing["type"] == "IN"
                            ? Colors.green
                            : Colors.red,
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      drawing["type"] ?? "-",
                      style: TextStyle(
                        color: drawing["type"] == "IN"
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
      ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: primaryColor),
                  onPressed: () => _editDrawing(drawing),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: primaryColor),
                  onPressed: () => _showDeleteDialog(
                    drawing["id"],
                    drawing["reason"] ?? "-",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: screenWidth * labelWidthFactor,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tanColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: child ??
                  Text(
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
        title: const Text(
          "Add Drawing",
          style: TextStyle(color: Color(0xFFD8C9A9)),
        ),
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
                onPressed: () {
                  setState(() {
                    _showForm = true;
                    if (_reasonController.text.isEmpty) {
                      _reasonController.text = "Drawing";
                    }
                  });
                },
                child: const Text("Add Drawing"),
              ),
            if (_showForm) _buildDrawingForm(),
            const SizedBox(height: 16),
            ..._drawings.map(_buildDrawingCard).toList(),
          ],
        ),
      ),
    );
  }
}
