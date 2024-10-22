import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

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

  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      // Using OpenStreetMap's OSRM service for routing
      final response = await http.get(Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=polyline'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          
          // Decode the polyline
          final polylinePoints = PolylinePoints();
          final points = polylinePoints.decodePolyline(geometry);
          
          // Convert to LatLng list
          return points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        }
      }
      return [start, end]; // Fallback to direct line if route fetch fails
    } catch (e) {
      print('Error getting route: $e');
      return [start, end]; // Fallback to direct line
    }
  }
}
