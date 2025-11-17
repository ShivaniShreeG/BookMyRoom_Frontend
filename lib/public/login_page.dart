import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation.dart';
import 'config.dart';
import 'forgot_password.dart';
import 'register.dart';

/// 🎨 App Color Palette
const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _lodgeIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        _lodgeIdController.text = prefs.getInt('lodgeId')?.toString() ?? '';
        _userIdController.text = prefs.getString('userId') ?? '';
        _passwordController.text = prefs.getString('password') ?? '';
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent, // Let border container show
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: royal, width: 2), // 💙 Royal blue border
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            message,
            style: const TextStyle(
              color: royal,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveUserData(
      String role, int lodgeId, String userId, String designation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);
    await prefs.setInt('lodgeId', lodgeId);
    await prefs.setString('userId', userId);
    await prefs.setString('designation', designation);

    if (_rememberMe) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('password', _passwordController.text);
    } else {
      await prefs.setBool('rememberMe', false);
      await prefs.remove('password');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse("$baseUrl/auth/login");

      Map<String, dynamic> body = {
        "userId": _userIdController.text.trim(),
        "password": _passwordController.text.trim(),
      };
      if (_lodgeIdController.text.trim().isNotEmpty) {
        body["lodgeId"] = int.tryParse(_lodgeIdController.text.trim());
      }

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      setState(() => _isLoading = false);

      if (response.statusCode != 200) {
        _showMessage("Server error: ${response.statusCode}");
        return;
      }

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final user = data['user'];
        final message = data['message'] ?? "Login successful";

        _showMessage(message);

        await _saveUserData(
          user['role']?.toString() ?? '',
          user['lodgeId'] is int ? user['lodgeId'] : int.tryParse(user['lodgeId']?.toString() ?? '0') ?? 0,
          user['userId']?.toString() ?? '',
          user['designation']?.toString() ?? '',
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
      else {
        _showMessage(data['message'] ?? "Login failed");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error connecting to server: $e");
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
      body: Container(
        // 🌈 Gradient Background only
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [royalblue, royalLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 24 * textScale,
              vertical: 40 * boxScale,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Column(
                  children: [
                    Text(
                      "LODGE",
                      style: TextStyle(
                        fontSize: 24 * textScale,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        fontFamily: 'Good Times',
                      ),
                    ),
                    Text(
                      "MANAGEMENT",
                      style: TextStyle(
                        fontSize: 24 * textScale,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.1,
                        fontFamily: 'Good Times',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20 * boxScale),

                // Login Card (solid royal accents)
                Container(
                  padding: EdgeInsets.all(24 * boxScale),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20 * boxScale),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline,
                            color: royal, size: 40 * boxScale),
                        SizedBox(height: 12 * boxScale),
                        Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 26 * textScale,
                            fontWeight: FontWeight.bold,
                            color: royal,
                          ),
                        ),
                        SizedBox(height: 24 * boxScale),

                        // 🏠 Lodge ID
                        _buildTextField(
                          controller: _lodgeIdController,
                          icon: Icons.home_work_rounded,
                          label: "Lodge ID",
                          keyboard: TextInputType.number,
                          validator: (v) {
                            if (v != null &&
                                v.isNotEmpty &&
                                int.tryParse(v) == null) {
                              return "Enter a valid Lodge ID";
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16 * boxScale),

                        // 👤 User ID
                        _buildTextField(
                          controller: _userIdController,
                          icon: Icons.person,
                          label: "User ID",
                          keyboard: TextInputType.number,
                          validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? "User ID is required"
                              : null,
                        ),
                        SizedBox(height: 16 * boxScale),

                        // 🔒 Password
                        _buildTextField(
                          controller: _passwordController,
                          icon: Icons.lock,
                          label: "Password",
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: royal,
                            ),
                            onPressed: () {
                              setState(() =>
                              _obscurePassword = !_obscurePassword);
                            },
                          ),
                          validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? "Password is required"
                              : null,
                        ),
                        SizedBox(height: 16 * boxScale),

                        // Solid royal Login button
                        SizedBox(
                          width: double.infinity,
                          height: 50 * boxScale,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: royal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12 * boxScale),
                              ),
                            ),
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                color: Colors.white)
                                : Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 18 * textScale,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12 * boxScale),

                        // Forgot Password
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage()),
                            );
                          },
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(
                                color: royal, fontSize: 14 * textScale),
                          ),
                        ),

                        // Register
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const CreateHallOwnerPage()),
                            );
                          },
                          child: Text(
                            "Not registered yet? Register",
                            style: TextStyle(
                                color: royal, fontSize: 14 * textScale),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24 * boxScale),

                Text(
                  "© ${DateTime.now().year} Ramchin Technologies Private Limited",
                  style:
                  TextStyle(color: Colors.white, fontSize: 12 * textScale),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🧩 Reusable text field builder
  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: royal, fontSize: 14),
      cursorColor: royal, // 👈 Makes typing pointer royal
      keyboardType: keyboard,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: royal),
        suffixIcon: suffixIcon,
        labelText: label,
        labelStyle: const TextStyle(color: royal),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: royal, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: royal, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true, // 💙 Enables background color
        fillColor: royalLight.withValues(alpha: 0.05),
      ),
      validator: validator,
    );
  }

}
