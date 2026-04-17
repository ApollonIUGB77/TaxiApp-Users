// © 2026 Aboubacar Sidick Meite (ApollonIUGB77) — All Rights Reserved
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  int _totalTrips = 0;
  double _totalSpent = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (_user == null) { setState(() => _loading = false); return; }
    try {
      final snap = await FirebaseDatabase.instance.ref('trips/${_user!.uid}').get();
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        double total = 0;
        for (final t in data.values) {
          final trip = Map<String, dynamic>.from(t as Map);
          total += (trip['fare'] ?? 0).toDouble();
        }
        setState(() { _totalTrips = data.length; _totalSpent = total; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final initials = (_user?.displayName?.isNotEmpty == true ? _user!.displayName![0] : 'U').toUpperCase();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFFDB1702),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFDB1702), Color(0xFFB71C1C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 48),
                  CircleAvatar(
                    radius: 44, backgroundColor: Colors.white,
                    child: Text(initials, style: const TextStyle(color: Color(0xFFDB1702), fontSize: 36, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  Text(_user?.displayName ?? 'Utilisateur', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(_user?.phoneNumber ?? _user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Stats
                Row(children: [
                  Expanded(child: _statCard('🚗', 'Courses', '$_totalTrips')),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('💰', 'Total dépensé', '${_totalSpent.toInt()} FCFA')),
                ]),
                const SizedBox(height: 20),
                // Account info
                _section('Informations du compte', [
                  _infoTile(Icons.phone, 'Téléphone', _user?.phoneNumber ?? 'Non renseigné'),
                  _infoTile(Icons.email_outlined, 'Email', _user?.email ?? 'Non renseigné'),
                  _infoTile(Icons.verified_user_outlined, 'Statut', _user?.emailVerified == true ? 'Vérifié' : 'Non vérifié'),
                ]),
                const SizedBox(height: 16),
                _section('Préférences', [
                  _infoTile(Icons.language, 'Langue', 'Français'),
                  _infoTile(Icons.payments, 'Paiement', 'Espèces / Mobile Money'),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
        child: Column(children: children),
      ),
    ]);
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: const Color(0xFFDB1702), size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
    );
  }
}
