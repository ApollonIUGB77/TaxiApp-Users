// © 2026 Aboubacar Sidick Meite (ApollonIUGB77) — All Rights Reserved
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});
  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    if (_user == null) { setState(() => _loading = false); return; }
    try {
      final snap = await FirebaseDatabase.instance.ref('trips/${_user!.uid}').get();
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        final list = data.entries.map((e) {
          final trip = Map<String, dynamic>.from(e.value as Map);
          trip['id'] = e.key;
          return trip;
        }).toList();
        list.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
        setState(() { _trips = list; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des courses'),
        backgroundColor: const Color(0xFFDB1702),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDB1702)))
          : _trips.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _trips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _buildTripCard(_trips[i]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('Aucune course pour l\'instant', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        const SizedBox(height: 8),
        Text('Vos prochaines courses apparaîtront ici.', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
      ]),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final ts = trip['timestamp'];
    String dateStr = '';
    if (ts != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts is int ? ts : int.tryParse(ts.toString()) ?? 0);
      dateStr = DateFormat('dd MMM yyyy · HH:mm', 'fr_FR').format(dt);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFDB1702).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(trip['rideType'] ?? 'Standard', style: const TextStyle(color: Color(0xFFDB1702), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const Spacer(),
          if (dateStr.isNotEmpty) Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
        const SizedBox(height: 12),
        _tripRow(Icons.radio_button_checked, 'Départ', 'Votre position', Colors.green),
        const Padding(padding: EdgeInsets.only(left: 8), child: SizedBox(height: 16, child: VerticalDivider(color: Colors.grey, width: 1))),
        _tripRow(Icons.location_on, 'Arrivée', trip['destName'] ?? '', const Color(0xFFDB1702)),
        const SizedBox(height: 12),
        Row(children: [
          _chip(Icons.route, '${(trip['distanceKm'] ?? 0).toStringAsFixed(1)} km'),
          const SizedBox(width: 8),
          _chip(Icons.payments_outlined, '${(trip['fare'] ?? 0).toInt()} FCFA'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Text('Terminée', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  Widget _tripRow(IconData icon, String label, String value, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
      ]),
    ]);
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ]),
    );
  }
}
