import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'delivery_detail_page.dart';
// Add imports for real-time location tracking
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// ignore: unused_import
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ReceiveDeliveryPage extends StatefulWidget {
  final String userId;
  final String userName;

  const ReceiveDeliveryPage({Key? key, required this.userId, required this.userName}) : super(key: key);

  @override
  _ReceiveDeliveryPageState createState() => _ReceiveDeliveryPageState();
}

class _ReceiveDeliveryPageState extends State<ReceiveDeliveryPage> {
  late Stream<QuerySnapshot> _deliveriesStream;
  Map<String, LatLng> _riderLocations = {};
  Map<String, List<LatLng>> _routePoints = {};

  Future<Map<String, dynamic>> findDistance(
      double startLat, double startLong, double endLat, double endLong) async {
    final response = await http.get(Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/$startLong,$startLat;$endLong,$endLat?overview=full&geometries=geojson'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
      final distance = data['routes'][0]['distance'] as num;
      return {
        "isError": false,
        "distance": (distance / 1000),
        "routePoints": coordinates
            .map((coord) => LatLng(coord[1] as double, coord[0] as double))
            .toList()
      };
    }
    return {"isError": true, "routePoints": [], "distance": -1};
  }

  @override
  void initState() {
    super.initState();
    _deliveriesStream = FirebaseFirestore.instance
        .collection('deliveries')
        .where('recipientId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    // Listen to rider locations for all active deliveries
    _setupRiderLocationListeners();
  }

  void _setupRiderLocationListeners() {
    _deliveriesStream.listen((snapshot) {
      for (var doc in snapshot.docs) {
        final delivery = doc.data() as Map<String, dynamic>;
        final riderId = delivery['riderId'];
        if (riderId != null && delivery['status'] != 'completed') {
          // Listen to rider location updates
          FirebaseFirestore.instance
              .collection('riders')
              .doc(riderId)
              .snapshots()
              .listen((riderSnapshot) async {
            if (riderSnapshot.exists) {
              final riderData = riderSnapshot.data() as Map<String, dynamic>;
              if (riderData['location'] != null) {
                final location = riderData['location'] as GeoPoint;
                final riderLocation = LatLng(location.latitude, location.longitude);
                
                // Get pickup and delivery locations
                final pickupLocation = delivery['pickupLocation'] as GeoPoint;
                final deliveryLocation = delivery['deliveryLocation'] as GeoPoint;
                
                // Get route points using findDistance
                final routeResult = await findDistance(
                  pickupLocation.latitude,
                  pickupLocation.longitude,
                  deliveryLocation.latitude,
                  deliveryLocation.longitude
                );

                setState(() {
                  _riderLocations[doc.id] = riderLocation;
                  _routePoints[doc.id] = routeResult['routePoints'] as List<LatLng>;
                });
              }
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Incoming Deliveries'),
        backgroundColor: Colors.purple.shade400,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _deliveriesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final deliveries = snapshot.data!.docs;

          if (deliveries.isEmpty) {
            return const Center(child: Text('No incoming deliveries found.'));
          }

          return ListView.builder(
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index].data() as Map<String, dynamic>;
              final deliveryId = deliveries[index].id;
              
              // Get rider location and route points for this delivery
              final riderLocation = _riderLocations[deliveryId];
              final routePoints = _routePoints[deliveryId];
              
              return Column(
                children: [
                  IncomingDeliveryItem(
                    delivery: delivery,
                    deliveryId: deliveryId,
                    recipientName: widget.userName,
                  ),
                  if (riderLocation != null && 
                      delivery['status'] == 'delivering')
                    Container(
                      height: 200,
                      margin: const EdgeInsets.all(16),
                          // Start of Selection
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: riderLocation, // Changed from center
                              initialZoom: 15, // Changed from zoom
                            ),
                            children: [
                              TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          if (routePoints != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  color: Colors.blue,
                                  strokeWidth: 3.0,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 40,
                                height: 40,
                                point: riderLocation,
                                child: const Icon(
                                  Icons.delivery_dining,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class IncomingDeliveryItem extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final String deliveryId;
  final String recipientName;

  const IncomingDeliveryItem({
    Key? key,
    required this.delivery,
    required this.deliveryId,
    required this.recipientName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdAt = (delivery['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy HH:mm').format(createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [
          ListTile(
            title: Text('From: ${delivery['senderName'] ?? 'Unknown Sender'}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${_formatStatus(delivery['status'])}'),
                Text('Date: $formattedDate'),
                Text('Items: ${(delivery['items'] as List).length}'),
                Text('To: $recipientName'),
                if (delivery['riderId'] != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('riders')
                        .doc(delivery['riderId'])
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final riderData = snapshot.data!.data() as Map<String, dynamic>?;
                        return Text('Rider: ${riderData?['name'] ?? 'Unknown'}');
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeliveryDetailPage(deliveryId: deliveryId),
                ),
              );
            },
          ),
          _buildProgressIndicator(delivery['status']),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting for Rider';
      case 'accepted':
        return 'Rider Assigned';
      case 'picked_up':
        return 'Package Picked Up';
      case 'delivering':
        return 'Out for Delivery';
      case 'completed':
        return 'Delivered';
      default:
        return status;
    }
  }

  Widget _buildProgressIndicator(String status) {
    final steps = ['pending', 'accepted', 'picked_up', 'delivering', 'completed'];
    final currentStep = steps.indexOf(status);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isCompleted = index <= currentStep;

          return Column(
            children: [
              Icon(
                _getStepIcon(step),
                color: isCompleted ? Colors.green : Colors.grey,
              ),
              Text(
                _getStepLabel(step),
                style: TextStyle(
                  color: isCompleted ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  IconData _getStepIcon(String step) {
    switch (step) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.person;
      case 'picked_up':
        return Icons.local_shipping;
      case 'delivering':
        return Icons.delivery_dining;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.circle;
    }
  }

  String _getStepLabel(String step) {
    switch (step) {
      case 'pending':
        return 'Waiting';
      case 'accepted':
        return 'Assigned';
      case 'picked_up':
        return 'Picked Up';
      case 'delivering':
        return 'Delivering';
      case 'completed':
        return 'Delivered';
      default:
        return step;
    }
  }
}
