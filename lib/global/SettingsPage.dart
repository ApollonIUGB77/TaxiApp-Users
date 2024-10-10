import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? _currentUser;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _nameController.text = _currentUser?.displayName ?? '';
  }

  Future<void> _updateDisplayName() async {
    if (_currentUser != null) {
      await _currentUser!.updateDisplayName(_nameController.text.trim());
      await _currentUser!.reload();
      _currentUser = FirebaseAuth.instance.currentUser;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom mis à jour avec succès')),
      );

      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom affiché',
              ),
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: _updateDisplayName,
              child: const Text('Mettre à jour'),
            ),
          ],
        ),
      ),
    );
  }
}
