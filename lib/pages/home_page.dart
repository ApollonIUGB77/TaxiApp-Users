import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

import '../authentication/login_screen.dart';
import '../global/SettingsPage.dart';
import '../global/global_var.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Clé API Google Maps depuis GlobalVar
  final String _googleMapsApiKey = GlobalVar.googleMapsApiKey;

  // Contrôleur de la carte
  final Completer<GoogleMapController> _googleMapController = Completer();

  // Contrôleur du champ de recherche
  final TextEditingController _searchController = TextEditingController();

  // Client de l'API Places
  late GoogleMapsPlaces _places;

  // Position actuelle
  LatLng _currentPosition = const LatLng(0.0, 0.0);

  // Utilisateur actuel
  User? _currentUser;

  // Ensemble de marqueurs
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _places = GoogleMapsPlaces(apiKey: _googleMapsApiKey);
    _checkLocationPermission();
    _getCurrentUser();
  }

  // Obtenir l'utilisateur connecté
  void _getCurrentUser() {
    _currentUser = FirebaseAuth.instance.currentUser;
    setState(() {});
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        // Les permissions sont refusées
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Les permissions sont refusées définitivement
      return;
    }

    // Les permissions sont accordées, obtenir la position actuelle
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      // Mettre à jour la position de la caméra
      CameraPosition cameraPosition = CameraPosition(
        target: _currentPosition,
        zoom: 16.0,
      );

      final GoogleMapController controller = await _googleMapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(cameraPosition),
      );
    } catch (e) {
      // Gérer les exceptions
      print(e);
    }
  }

  // Méthode pour obtenir les suggestions d'adresses
  Future<List<Prediction>> _getAddressSuggestions(String input) async {
    if (input.isEmpty) {
      return [];
    }

    PlacesAutocompleteResponse response = await _places.autocomplete(
      input,
      language: 'fr',
      // Supprimez ou commentez la ligne suivante pour permettre les résultats mondiaux
      // components: [Component(Component.country, 'ci')],
    );

    if (response.isOkay) {
      return response.predictions;
    } else {
      print('Erreur lors de l\'autocomplétion : ${response.errorMessage}');
      _showErrorDialog(
          'Erreur lors de l\'autocomplétion : ${response.errorMessage}');
      return [];
    }
  }

  // Méthode pour obtenir les détails d'un lieu et afficher sur la carte
  Future<void> _getPlaceDetailAndShowOnMap(String placeId) async {
    PlacesDetailsResponse detail = await _places.getDetailsByPlaceId(placeId);

    if (detail.isOkay) {
      double lat = detail.result.geometry!.location.lat;
      double lng = detail.result.geometry!.location.lng;

      LatLng selectedPosition = LatLng(lat, lng);

      // Ajouter un marqueur à la position sélectionnée
      setState(() {
        _markers.clear(); // Supprimer les marqueurs précédents
        _markers.add(
          Marker(
            markerId: const MarkerId('selected-location'),
            position: selectedPosition,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: detail.result.name,
              snippet: detail.result.formattedAddress,
            ),
          ),
        );
      });

      // Déplacer la caméra vers la position sélectionnée
      final GoogleMapController controller = await _googleMapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: selectedPosition,
            zoom: 16.0,
          ),
        ),
      );
    } else {
      print(
          'Erreur lors de la récupération des détails du lieu : ${detail.errorMessage}');
      _showErrorDialog(
          'Erreur lors de la récupération des détails du lieu : ${detail.errorMessage}');
    }
  }

  // Méthode pour afficher un message d'erreur
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Méthode pour se déconnecter
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Menu latéral (Drawer)
      drawer: Drawer(
        child: ListView(
          children: [
            // En-tête du menu avec les informations de l'utilisateur
            UserAccountsDrawerHeader(
              accountName: Text(_currentUser?.displayName ?? 'Utilisateur'),
              accountEmail: Text(_currentUser?.email ?? 'Email non disponible'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: const Icon(
                  Icons.person,
                  size: 50.0,
                  color: Colors.grey,
                ),
              ),
            ),
            // Bouton Paramètres
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              child: const ListTile(
                leading: Icon(Icons.settings),
                title: Text('Paramètres'),
              ),
            ),
            // Bouton Déconnexion
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const ListTile(
                leading: Icon(Icons.logout),
                title: Text('Déconnexion'),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Votre Application'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            markers: _markers, // Ajouter les marqueurs
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 16.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _googleMapController.complete(controller);
              _getCurrentLocation();
            },
          ),
          // Barre de recherche
          Positioned(
            top: 10.0,
            left: 15.0,
            right: 15.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: TypeAheadField<Prediction>(
                textFieldConfiguration: TextFieldConfiguration(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Chercher une adresse',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                suggestionsCallback: _getAddressSuggestions,
                itemBuilder: (context, Prediction suggestion) {
                  return ListTile(
                    title: Text(suggestion.description ?? ''),
                  );
                },
                onSuggestionSelected: (Prediction suggestion) {
                  _searchController.text = suggestion.description ?? '';
                  _getPlaceDetailAndShowOnMap(suggestion.placeId!);
                },
                noItemsFoundBuilder: (context) => const ListTile(
                  title: Text('Aucun résultat trouvé'),
                ),
                errorBuilder: (context, error) => ListTile(
                  title: Text('Erreur: $error'),
                ),
              ),
            ),
          ),
          // Bouton pour centrer sur la position actuelle
          Positioned(
            bottom: 80.0,
            right: 15.0,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
