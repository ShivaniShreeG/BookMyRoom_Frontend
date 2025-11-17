import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

class EditHallPage extends StatefulWidget {
  final dynamic hall;

  const EditHallPage({super.key, required this.hall});

  @override
  State<EditHallPage> createState() => _EditHallPageState();
}

class _EditHallPageState extends State<EditHallPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _dueDateController;


  String? _base64Logo;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.hall['name']);
    _phoneController = TextEditingController(text: widget.hall['phone']);
    _emailController = TextEditingController(text: widget.hall['email']);
    _addressController = TextEditingController(text: widget.hall['address']);
    _base64Logo = widget.hall['logo'];
    _dueDateController = TextEditingController(
      text: widget.hall['dueDate'] != null
          ? widget.hall['dueDate'].toString().split('T').first
          : '',
    );

  }
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _dueDateController.dispose(); // 🆕 added line
    super.dispose();
  }


  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = File(picked.path);
        _base64Logo = base64Encode(bytes);
      });
    }
  }
  Future<void> _selectDueDate(BuildContext context) async {
    DateTime initialDate;
    try {
      initialDate = DateTime.parse(_dueDateController.text);
    } catch (_) {
      initialDate = DateTime.now();
    }
    print("📅 Due date received from backend: ${widget.hall['dueDate']}");

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5B6547), // header & buttons
              onPrimary: Color(0xFFD8C9A9), // text on buttons
              onSurface: Color(0xFF5B6547), // body text
            ),
            dialogBackgroundColor: Color(0xFFECE5D8),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dueDateController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _updateHall(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final hallData = {
      "name": _nameController.text.trim(),
      "phone": _phoneController.text.trim(),
      "email": _emailController.text.trim(),
      "address": _addressController.text.trim(),
      if (_base64Logo != null) "logo": _base64Logo,
      "dueDate": _dueDateController.text.trim(),

    };

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/halls/${widget.hall['hall_id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(hallData),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hall updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, data); // Return updated data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update hall: ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating hall: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTextField(
      {required TextEditingController controller,
        required String label,
        TextInputType type = TextInputType.text,
        int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        validator: (value) =>
        value == null || value.isEmpty ? 'Please enter $label' : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Color(0xFFD8C9A9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B6547),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
        title: const Text(
          "Edit Hall",
          style: TextStyle(
            color: Color(0xFFD8C9A9),
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: const Color(0xFFECE5D8),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: Color(0xFF5B6547), // border color
              width: 1, // border thickness
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Logo preview
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF5B6547),
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_base64Logo != null
                          ? MemoryImage(base64Decode(_base64Logo!))
                          : null) as ImageProvider?,
                      child: _selectedImage == null && _base64Logo == null
                          ? const Icon(Icons.add_a_photo,
                          color: Colors.white, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Tap to change logo",
                    style: TextStyle(
                      color: Color(0xFF5B6547),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(controller: _nameController, label: 'Name'),
                  _buildTextField(
                      controller: _phoneController,
                      label: 'Phone',
                      type: TextInputType.phone),
                  _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      type: TextInputType.emailAddress),
                  _buildTextField(
                      controller: _addressController,
                      label: 'Address',
                      maxLines: 2),
                  GestureDetector(
                    onTap: () => _selectDueDate(context),
                    child: AbsorbPointer(
                      child: _buildTextField(
                        controller: _dueDateController,
                        label: 'Due Date (YYYY-MM-DD)',
                        type: TextInputType.datetime,
                      ),
                    ),
                  ),


                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B6547),
                        foregroundColor: const Color(0xFFD8C9A9),
                        padding:
                        const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _updateHall(context),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
