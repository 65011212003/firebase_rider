import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:math' show cos, sqrt, asin;

class DeliveryDetailPage extends StatefulWidget {
  final String deliveryId;

  const DeliveryDetailPage({Key? key, required this.deliveryId}) : super(key: key);

  @override
  _DeliveryDetailPageState createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  final PopupController _popupLayerController = PopupController();
  LatLng? _riderLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Details'),
        backgroundColor: Colors.purple.shade400,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade200, Colors.purple.shade400],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('deliveries').doc(widget.deliveryId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final delivery = snapshot.data!.data() as Map<String, dynamic>;
            final createdAt = (delivery['createdAt'] as Timestamp).toDate();
            final formattedDate = DateFormat('MMM d, yyyy HH:mm').format(createdAt);

            final pickupLocation = LatLng(
              delivery['pickupLocation'].latitude,
              delivery['pickupLocation'].longitude,
            );
            final deliveryLocation = LatLng(
              delivery['deliveryLocation'].latitude,
              delivery['deliveryLocation'].longitude,
            );

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delivery #${widget.deliveryId}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Status: ${delivery['status']}', style: const TextStyle(color: Colors.white)),
                        Text('Created: $formattedDate', style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        _buildInfoSection('Sender Information:', delivery, 'senderName', 'senderPhone'),
                        _buildInfoSection('Recipient Information:', delivery, 'recipientName', 'recipientPhone'),
                        const SizedBox(height: 16),
                        const Text('Items:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ...(delivery['items'] as List).map((item) => _buildItemWidget(item)),
                        const SizedBox(height: 16),
                        const Text('Delivery Progress:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        _buildDeliveryProgress(delivery),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    child: LocationMapWidget(
                      pickupLocation: pickupLocation,
                      deliveryLocation: deliveryLocation,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, Map<String, dynamic> data, String nameKey, String phoneKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text('Name: ${data[nameKey]}', style: const TextStyle(color: Colors.white)),
        Text('Phone: ${data[phoneKey]}', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildItemWidget(Map<String, dynamic> item) {
    return Row(
      children: [
        if (item['imageUrl'] != null)
          Image.network(
            item['imageUrl'],
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '- ${item['description']}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryProgress(Map<String, dynamic> delivery) {
    final List<Map<String, dynamic>> steps = [
      {'status': 'pending', 'title': 'Order Placed', 'icon': Icons.shopping_cart},
      {'status': 'accepted', 'title': 'Order Accepted', 'icon': Icons.check_circle},
      {'status': 'picked_up', 'title': 'Package Picked Up', 'icon': Icons.local_shipping},
      {'status': 'delivering', 'title': 'Out for Delivery', 'icon': Icons.directions_bike},
      {'status': 'completed', 'title': 'Delivered', 'icon': Icons.done_all},
    ];

    return Column(
      children: steps.map((step) {
        final bool isCompleted = _isStepCompleted(delivery['status'], step['status']);
        return ListTile(
          leading: Icon(
            step['icon'] as IconData,
            color: isCompleted ? Colors.green : Colors.grey,
          ),
          title: Text(step['title'] as String, style: TextStyle(color: isCompleted ? Colors.white : Colors.grey[300])),
          trailing: isCompleted
              ? const Icon(Icons.check, color: Colors.green)
              : null,
        );
      }).toList(),
    );
  }

  bool _isStepCompleted(String currentStatus, String stepStatus) {
    final List<String> orderOfStatus = ['pending', 'accepted', 'picked_up', 'delivering', 'completed'];
    return orderOfStatus.indexOf(currentStatus) >= orderOfStatus.indexOf(stepStatus);
  }

  @override
  void initState() {
    super.initState();
    _listenToRiderLocation();
  }

  void _listenToRiderLocation() {
    FirebaseFirestore.instance
        .collection('deliveries')
        .doc(widget.deliveryId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final riderId = data['riderId'];
        if (riderId != null) {
          FirebaseFirestore.instance
              .collection('riders')
              .doc(riderId)
              .snapshots()
              .listen((riderSnapshot) {
            if (riderSnapshot.exists) {
              final riderData = riderSnapshot.data() as Map<String, dynamic>;
              final location = riderData['location'];
              if (location != null) {
                setState(() {
                  _riderLocation = LatLng(location.latitude, location.longitude);
                });
              }
            }
          });
        }
      }
    });
  }
}

class LocationMapWidget extends StatelessWidget {
  final LatLng pickupLocation;
  final LatLng deliveryLocation;

  const LocationMapWidget({
    Key? key,
    required this.pickupLocation,
    required this.deliveryLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      (pickupLocation.latitude + deliveryLocation.latitude) / 2,
      (pickupLocation.longitude + deliveryLocation.longitude) / 2,
    );

    final distance = calculateDistance(pickupLocation, deliveryLocation);
    final zoom = calculateZoomLevel(distance);

    return SizedBox(
      height: 300,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [pickupLocation, deliveryLocation],
                color: Colors.blue,
                strokeWidth: 4.0,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 40.0,
                height: 40.0,
                point: pickupLocation,
                child: const Icon(Icons.location_on, color: Colors.green, size: 40),
              ),
              Marker(
                width: 40.0,
                height: 40.0,
                point: deliveryLocation,
                child: const Icon(Icons.flag, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((point2.latitude - point1.latitude) * p)/2 + 
            c(point1.latitude * p) * c(point2.latitude * p) * 
            (1 - c((point2.longitude - point1.longitude) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  double calculateZoomLevel(double distance) {
    if (distance < 1) return 14;
    if (distance < 5) return 12;
    if (distance < 10) return 11;
    if (distance < 50) return 9;
    return 8;
  }
}
