import 'package:flutter/material.dart';
import 'package:taxi_users/authentication/login_screen.dart'; // Import the login screen

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Function to handle logout
  void _logout() {
    // Navigate back to LoginScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
      ),
      body: const Center(
        child: Text(
          "Home Page",
          style: TextStyle(fontSize: 20, color: Colors.black), // Changed to black for better visibility
        ),
      ),
      // Add a FloatingActionButton to log out
      floatingActionButton: FloatingActionButton(
        onPressed: _logout,
        child: const Icon(Icons.logout),
        tooltip: 'Logout',
      ),
    );
  }
}
