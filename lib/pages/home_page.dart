// © 2026 Aboubacar Sidick Meite (ApollonIUGB77) — All Rights Reserved
import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

import '../authentication/login_screen.dart';
import '../global/SettingsPage.dart';
import '../global/global_var.dart';
import 'profile_screen.dart';
import 'trip_history_screen.dart';

// ── Ride state machine ────────────────────────────────────────────────────────
enum RideState { idle, destinationSelected, requesting, driverFound, inTrip, completed }

// ── Ride types ────────────────────────────────────────────────────────────────
class RideType {
  final String name;
  final IconData icon;
  final double pricePerKm;
  final String description;
  const RideType({required this.name, required this.icon, required this.pricePerKm, required this.description});
}

const List<RideType> rideTypes = [
  RideType(name: 'Standard',  icon: Icons.directions_car,     pricePerKm: 350,  description: 'Confortable & abordable'),
  RideType(name: 'Premium',   icon: Icons.star,                pricePerKm: 600,  description: 'Berline haut de gamme'),
  RideType(name: 'Moto',      icon: Icons.two_wheeler,         pricePerKm: 200,  description: 'Rapide en ville'),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {

  // ── Map ────────────────────────────────────────────────────────────────────
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _destController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  late GoogleMapsPlaces _places;

  LatLng _currentPosition = const LatLng(5.3484, -4.0167); // Abidjan default
  LatLng? _destinationPosition;
  String _destinationName = '';
  String _destinationAddress = '';
  Set<Marker>  _markers  = {};
  Set<Polyline> _polylines = {};

  // ── State ──────────────────────────────────────────────────────────────────
  RideState _rideState   = RideState.idle;
  int _selectedRideType  = 0;
  double _estimatedFare  = 0;
  double _estimatedKm    = 0;
  int    _estimatedMins  = 0;
  User?  _currentUser;
  bool   _loadingLocation = true;

  // Driver info (simulated after acceptance)
  String _driverName   = '';
  String _driverPhone  = '';
  String _driverPlate  = '';
  double _driverRating = 0;
  int    _driverEta    = 0;

  Timer? _requestTimer;
  late AnimationController _pulseController;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _places = GoogleMapsPlaces(apiKey: GlobalVar.googleMapsApiKey);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _loadUser();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _requestTimer?.cancel();
    _pulseController.dispose();
    _destController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadUser() {
    setState(() => _currentUser = FirebaseAuth.instance.currentUser);
  }

  // ── Location ───────────────────────────────────────────────────────────────
  Future<void> _checkLocationPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) { setState(() => _loadingLocation = false); return; }
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _loadingLocation = false;
      });
      final ctrl = await _mapController.future;
      ctrl.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _currentPosition, zoom: 15.5)));
    } catch (_) { setState(() => _loadingLocation = false); }
  }

  // ── Autocomplete ───────────────────────────────────────────────────────────
  Future<List<Prediction>> _getSuggestions(String input) async {
    if (input.trim().isEmpty) return [];
    final r = await _places.autocomplete(input, language: 'fr');
    return r.isOkay ? r.predictions : [];
  }

  Future<void> _selectDestination(Prediction p) async {
    final detail = await _places.getDetailsByPlaceId(p.placeId!);
    if (!detail.isOkay) return;

    final lat = detail.result.geometry!.location.lat;
    final lng = detail.result.geometry!.location.lng;
    final dest = LatLng(lat, lng);

    setState(() {
      _destinationPosition = dest;
      _destinationName    = detail.result.name;
      _destinationAddress = detail.result.formattedAddress ?? '';
      _destController.text = detail.result.name;
      _markers = {
        Marker(markerId: const MarkerId('pickup'), position: _currentPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '📍 Votre position')),
        Marker(markerId: const MarkerId('destination'), position: dest,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: '🏁 ${detail.result.name}')),
      };
    });

    _calculateFare();
    _fitMapBounds();

    setState(() => _rideState = RideState.destinationSelected);
  }

  void _fitMapBounds() async {
    if (_destinationPosition == null) return;
    final ctrl = await _mapController.future;
    final bounds = LatLngBounds(
      southwest: LatLng(
        min(_currentPosition.latitude,  _destinationPosition!.latitude),
        min(_currentPosition.longitude, _destinationPosition!.longitude),
      ),
      northeast: LatLng(
        max(_currentPosition.latitude,  _destinationPosition!.latitude),
        max(_currentPosition.longitude, _destinationPosition!.longitude),
      ),
    );
    ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ── Fare estimation ────────────────────────────────────────────────────────
  void _calculateFare() {
    if (_destinationPosition == null) return;
    final distM = Geolocator.distanceBetween(
      _currentPosition.latitude, _currentPosition.longitude,
      _destinationPosition!.latitude, _destinationPosition!.longitude,
    );
    final km = distM / 1000;
    final type = rideTypes[_selectedRideType];
    setState(() {
      _estimatedKm   = km;
      _estimatedFare = max(500, km * type.pricePerKm).roundToDouble();
      _estimatedMins = max(3, (km / 0.4).round()); // ~40km/h average
    });
  }

  // ── Request ride ───────────────────────────────────────────────────────────
  void _requestRide() {
    setState(() => _rideState = RideState.requesting);

    // Save trip request to Firebase
    _saveTripToFirebase();

    // Simulate driver search (3-8 seconds)
    final waitSecs = 3 + Random().nextInt(6);
    _requestTimer = Timer(Duration(seconds: waitSecs), _onDriverFound);
  }

  void _onDriverFound() {
    final names  = ['Kouamé A.', 'Diallo S.', 'Koné B.', 'Traoré M.', 'Bamba K.'];
    final plates = ['CI-4521-AB', 'CI-2367-CD', 'CI-8810-EF', 'CI-1234-GH'];
    final r = Random();
    setState(() {
      _driverName   = names[r.nextInt(names.length)];
      _driverPhone  = '+225 07 ${r.nextInt(90)+10} ${r.nextInt(90)+10} ${r.nextInt(90)+10}';
      _driverPlate  = plates[r.nextInt(plates.length)];
      _driverRating = 4.2 + r.nextDouble() * 0.7;
      _driverEta    = 2 + r.nextInt(8);
      _rideState    = RideState.driverFound;
    });
  }

  void _startTrip() => setState(() => _rideState = RideState.inTrip);

  void _completeTrip() {
    _updateTripStatusFirebase('completed');
    setState(() { _rideState = RideState.completed; });
  }

  void _resetRide() {
    setState(() {
      _rideState           = RideState.idle;
      _destinationPosition = null;
      _destinationName     = '';
      _destinationAddress  = '';
      _estimatedFare       = 0;
      _estimatedKm         = 0;
      _destController.clear();
      _markers             = {};
      _polylines           = {};
    });
    _getCurrentLocation();
  }

  // ── Firebase ───────────────────────────────────────────────────────────────
  void _saveTripToFirebase() {
    if (_currentUser == null || _destinationPosition == null) return;
    final db = FirebaseDatabase.instance.ref('trips/${_currentUser!.uid}').push();
    db.set({
      'userId':       _currentUser!.uid,
      'userName':     _currentUser!.displayName ?? 'Utilisateur',
      'pickupLat':    _currentPosition.latitude,
      'pickupLng':    _currentPosition.longitude,
      'destLat':      _destinationPosition!.latitude,
      'destLng':      _destinationPosition!.longitude,
      'destName':     _destinationName,
      'destAddress':  _destinationAddress,
      'rideType':     rideTypes[_selectedRideType].name,
      'fare':         _estimatedFare,
      'distanceKm':   _estimatedKm,
      'status':       'requested',
      'timestamp':    ServerValue.timestamp,
    });
  }

  void _updateTripStatusFirebase(String status) {
    // In a real app we'd update the specific trip document
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildMap(),
          if (_loadingLocation) _buildLoadingOverlay(),
          _buildTopBar(),
          if (_rideState == RideState.idle) _buildSearchBar(),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  // ── Map ────────────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return GoogleMap(
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: _markers,
      polylines: _polylines,
      initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 15),
      onMapCreated: (ctrl) {
        _mapController.complete(ctrl);
        _getCurrentLocation();
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black38,
      child: const Center(child: CircularProgressIndicator(color: Colors.red)),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12, right: 12,
      child: Row(
        children: [
          // Hamburger
          Material(
            elevation: 4, shape: const CircleBorder(), color: Colors.white,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Scaffold.of(context).openDrawer(),
              child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.menu, color: Colors.black87)),
            ),
          ),
          const Spacer(),
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFDB1702), borderRadius: BorderRadius.circular(20)),
            child: const Text('🚖 CommuTaxi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Spacer(),
          // Recenter
          Material(
            elevation: 4, shape: const CircleBorder(), color: Colors.white,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _getCurrentLocation,
              child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.my_location, color: Color(0xFFDB1702))),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar (idle state) ────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Positioned(
      bottom: 20, left: 16, right: 16,
      child: Material(
        elevation: 8, borderRadius: BorderRadius.circular(16), color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Où allez-vous ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800])),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.radio_button_checked, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Votre position actuelle', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
                ],
              ),
              const Padding(padding: EdgeInsets.only(left: 9), child: SizedBox(height: 4, width: 1, child: VerticalDivider(color: Colors.grey))),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFDB1702), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TypeAheadField<Prediction>(
                      textFieldConfiguration: TextFieldConfiguration(
                        controller: _destController,
                        decoration: InputDecoration(
                          hintText: 'Entrez votre destination',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                          border: InputBorder.none, isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      suggestionsCallback: _getSuggestions,
                      itemBuilder: (ctx, Prediction p) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined, color: Color(0xFFDB1702), size: 18),
                        title: Text(p.description ?? '', style: const TextStyle(fontSize: 13)),
                      ),
                      onSuggestionSelected: _selectDestination,
                      noItemsFoundBuilder: (ctx) => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Aucun résultat', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom panel (all states except idle) ──────────────────────────────────
  Widget _buildBottomPanel() {
    if (_rideState == RideState.idle) return const SizedBox.shrink();
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: switch (_rideState) {
          RideState.destinationSelected => _buildDestinationPanel(),
          RideState.requesting          => _buildRequestingPanel(),
          RideState.driverFound         => _buildDriverFoundPanel(),
          RideState.inTrip              => _buildInTripPanel(),
          RideState.completed           => _buildCompletedPanel(),
          _                             => const SizedBox.shrink(),
        },
      ),
    );
  }

  // ── Panel: destination selected → choose ride type + fare ─────────────────
  Widget _buildDestinationPanel() {
    return _panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHandle(),
          const SizedBox(height: 8),
          // Trip summary
          Row(children: [
            const Icon(Icons.location_on, color: Colors.green, size: 16),
            const SizedBox(width: 6),
            const Text('Votre position', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.flag, color: Color(0xFFDB1702), size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(_destinationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
          ]),
          Text('  $_destinationAddress', style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),

          const SizedBox(height: 12),
          // Stats
          Row(children: [
            _statChip(Icons.route, '${_estimatedKm.toStringAsFixed(1)} km'),
            const SizedBox(width: 8),
            _statChip(Icons.access_time, '$_estimatedMins min'),
          ]),

          const SizedBox(height: 14),
          const Text('Choisir un type de trajet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),

          // Ride type selector
          ...rideTypes.asMap().entries.map((e) {
            final i = e.key; final rt = e.value;
            final selected = i == _selectedRideType;
            return GestureDetector(
              onTap: () { setState(() => _selectedRideType = i); _calculateFare(); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: selected ? const Color(0xFFDB1702) : Colors.grey[200]!, width: selected ? 2 : 1),
                  borderRadius: BorderRadius.circular(10),
                  color: selected ? const Color(0xFFDB1702).withOpacity(0.05) : Colors.white,
                ),
                child: Row(children: [
                  Icon(rt.icon, color: selected ? const Color(0xFFDB1702) : Colors.grey, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rt.name, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? const Color(0xFFDB1702) : Colors.black87)),
                    Text(rt.description, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ])),
                  Text('${_estimatedFare.toInt()} FCFA', style: TextStyle(fontWeight: FontWeight.bold, color: selected ? const Color(0xFFDB1702) : Colors.black87)),
                ]),
              ),
            );
          }),

          const SizedBox(height: 8),
          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _requestRide,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDB1702), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Commander — ${_estimatedFare.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          TextButton(onPressed: _resetRide, child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  // ── Panel: searching driver ────────────────────────────────────────────────
  Widget _buildRequestingPanel() {
    return _panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _panelHandle(),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Transform.scale(
              scale: 1.0 + _pulseController.value * 0.1,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: const Color(0xFFDB1702).withOpacity(0.1 + _pulseController.value * 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.directions_car, color: Color(0xFFDB1702), size: 36),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Recherche d\'un chauffeur...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Destination : $_destinationName', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 6),
          const LinearProgressIndicator(color: Color(0xFFDB1702), backgroundColor: Color(0xFFFFCDD2)),
          const SizedBox(height: 16),
          TextButton(onPressed: _resetRide, child: const Text('Annuler la recherche', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  // ── Panel: driver found ────────────────────────────────────────────────────
  Widget _buildDriverFoundPanel() {
    return _panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHandle(),
          Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFDB1702), shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.white, size: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(children: [
                const Icon(Icons.star, color: Colors.amber, size: 14),
                Text(' ${_driverRating.toStringAsFixed(1)}  •  $_driverPlate', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ]),
            ])),
            Column(children: [
              Container(
                decoration: BoxDecoration(color: const Color(0xFFDB1702).withOpacity(0.1), shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.phone, color: Color(0xFFDB1702)), onPressed: () {}),
              ),
              Text('Appeler', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ]),
          ]),
          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.access_time, color: Color(0xFFDB1702), size: 18),
            const SizedBox(width: 6),
            Text('Arrivée dans $_driverEta min', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            _statChip(Icons.flag, _destinationName, maxWidth: 140),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startTrip,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Démarrer le trajet', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel: in trip ────────────────────────────────────────────────────────
  Widget _buildInTripPanel() {
    return _panel(
      color: const Color(0xFF1A1A2E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _panelHandle(color: Colors.white30),
          Row(children: [
            const Icon(Icons.navigation, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Trajet en cours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text('${_estimatedMins} min restantes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: 0.4, color: Colors.greenAccent, backgroundColor: Colors.white24, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.flag, color: Color(0xFFDB1702), size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(_destinationName, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeTrip,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Arrivé à destination', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel: completed ─────────────────────────────────────────────────────
  Widget _buildCompletedPanel() {
    return _panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _panelHandle(),
          const Icon(Icons.check_circle, color: Colors.green, size: 56),
          const SizedBox(height: 8),
          const Text('Trajet terminé !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 4),
          Text('${_estimatedFare.toInt()} FCFA · ${_estimatedKm.toStringAsFixed(1)} km · $_destinationName',
            style: TextStyle(color: Colors.grey[600], fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.star_border, color: Color(0xFFDB1702)),
              label: const Text('Évaluer', style: TextStyle(color: Color(0xFFDB1702))),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFDB1702)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: _resetRide,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDB1702), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Nouveau trajet'),
            )),
          ]),
        ],
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFDB1702)),
            accountName: Text(_currentUser?.displayName ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(_currentUser?.phoneNumber ?? _currentUser?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text((_currentUser?.displayName?.isNotEmpty == true ? _currentUser!.displayName![0] : 'U').toUpperCase(),
                style: const TextStyle(color: Color(0xFFDB1702), fontWeight: FontWeight.bold, fontSize: 24)),
            ),
          ),
          _drawerItem(Icons.history, 'Historique des courses', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TripHistoryScreen()));
          }),
          _drawerItem(Icons.person, 'Mon profil', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
          }),
          _drawerItem(Icons.settings, 'Paramètres', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
          }),
          const Divider(),
          _drawerItem(Icons.logout, 'Déconnexion', _signOut, color: Colors.red),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('© 2026 ASM', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFFDB1702)),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _panel({required Widget child, Color color = Colors.white}) {
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, -4))]),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: child,
    );
  }

  Widget _panelHandle({Color color = const Color(0xFFE0E0E0)}) {
    return Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))));
  }

  Widget _statChip(IconData icon, String label, {double? maxWidth}) {
    return Container(
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth) : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
