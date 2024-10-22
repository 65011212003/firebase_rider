import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;

  Future<void> startTracking(String riderId, String deliveryId) async {
    // Request permission
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Handle permission denied
      return;
    }

    // Start listening to location updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _updateLocation(riderId, deliveryId, position);
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
  }

  Future<void> _updateLocation(String riderId, String deliveryId, Position position) async {
    await FirebaseFirestore.instance.collection('riders').doc(riderId).update({
      'location': GeoPoint(position.latitude, position.longitude),
    });

    await FirebaseFirestore.instance.collection('deliveries').doc(deliveryId).update({
      'riderLocation': GeoPoint(position.latitude, position.longitude),
    });
  }

  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final response = await http.get(
        Uri.parse('$_baseUrl?q=$encodedAddress&format=json&limit=1'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          final location = results.first;
          return LatLng(
            double.parse(location['lat']),
            double.parse(location['lon']),
          );
        }
      }
      return null;
    } catch (e) {
      print('Error getting coordinates: $e');
      return null;
    }
  }
}
