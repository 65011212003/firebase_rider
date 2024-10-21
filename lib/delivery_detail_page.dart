import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';

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
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('deliveries').doc(widget.deliveryId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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
                      Text('Delivery #${widget.deliveryId}', style: Theme.of(context).textTheme.titleLarge),
                      Text('Status: ${delivery['status']}'),
                      Text('Created: $formattedDate'),
                      const SizedBox(height: 16),
                      Text('Sender Information:', style: Theme.of(context).textTheme.titleMedium),
                      Text('Name: ${delivery['senderName']}'),
                      Text('Phone: ${delivery['senderPhone']}'),
                      const SizedBox(height: 16),
                      Text('Recipient Information:', style: Theme.of(context).textTheme.titleMedium),
                      Text('Name: ${delivery['recipientName']}'),
                      Text('Phone: ${delivery['recipientPhone']}'),
                      const SizedBox(height: 16),
                      Text('Items:', style: Theme.of(context).textTheme.titleMedium),
                      ...(delivery['items'] as List).map((item) => Text('- ${item['description']}')),
                      const SizedBox(height: 16),
                      Text('Delivery Progress:', style: Theme.of(context).textTheme.titleMedium),
                      _buildDeliveryProgress(delivery),
                    ],
                  ),
                ),
                SizedBox(
                  height: 300,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        (pickupLocation.latitude + deliveryLocation.latitude) / 2,
                        (pickupLocation.longitude + deliveryLocation.longitude) / 2,
                      ),
                      initialZoom: 12,
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
                            strokeWidth: 3.0,
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
                          if (_riderLocation != null)
                            Marker(
                              width: 40.0,
                              height: 40.0,
                              point: _riderLocation!,
                              child: const Icon(Icons.directions_bike, color: Colors.blue, size: 40),
                            ),
                        ],
                      ),
                      PopupMarkerLayer(
                        options: PopupMarkerLayerOptions(
                          popupController: _popupLayerController,
                          markers: [
                            Marker(
                              point: pickupLocation,
                              child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                            ),
                            Marker(
                              point: deliveryLocation,
                              child: const Icon(Icons.flag, color: Colors.red, size: 40),
                            ),
                          ],
                          popupDisplayOptions: PopupDisplayOptions(
                            builder: (_, Marker marker) {
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    marker.point == pickupLocation ? 'Pickup Location' : 'Delivery Location',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
          title: Text(step['title'] as String),
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
