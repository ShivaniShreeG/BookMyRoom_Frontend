import 'package:flutter/material.dart';
import 'public/main_navigation.dart'; // <- your main navigation file

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ramchin Lodge Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainNavigation(), // ✅ Always start with MainNavigation
    );
  }
}
