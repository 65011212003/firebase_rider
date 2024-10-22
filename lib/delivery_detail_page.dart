import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:math' show cos, sqrt, asin;
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class DeliveryDetailPage extends StatefulWidget {
  final String deliveryId;

  const DeliveryDetailPage({
    Key? key, 
    required this.deliveryId,
  }) : super(key: key);

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
        title: const Text(
          'Delivery Details',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.purple.shade400,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade200,
              Colors.purple.shade400,
            ],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('deliveries')
              .doc(widget.deliveryId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }

            final delivery = snapshot.data!.data() as Map<String, dynamic>?;
            
            if (delivery == null) {
              return const Center(
                child: Text(
                  'Delivery data not found',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              );
            }

            final createdAt = (delivery['createdAt'] as Timestamp?)?.toDate();
            final formattedDate = createdAt != null 
                ? DateFormat('MMM d, yyyy HH:mm').format(createdAt) 
                : 'N/A';

            final pickupTime = (delivery['pickupTime'] as Timestamp?)?.toDate();
            final formattedPickupTime = pickupTime != null 
                ? DateFormat('MMM d, yyyy HH:mm').format(pickupTime) 
                : 'N/A';

            final deliveryTime = (delivery['deliveryTime'] as Timestamp?)?.toDate();
            final formattedDeliveryTime = deliveryTime != null 
                ? DateFormat('MMM d, yyyy HH:mm').format(deliveryTime) 
                : 'N/A';

            final riderId = delivery['riderId'] as String?;

            final pickupLocation = delivery['pickupLocation'] != null 
                ? LatLng(
                    delivery['pickupLocation'].latitude,
                    delivery['pickupLocation'].longitude,
                  ) 
                : null;
            
            final deliveryLocation = delivery['deliveryLocation'] != null 
                ? LatLng(
                    delivery['deliveryLocation'].latitude,
                    delivery['deliveryLocation'].longitude,
                  ) 
                : null;

            LatLng? riderLocation;
            if (delivery['riderLocation'] != null) {
              final GeoPoint location = delivery['riderLocation'];
              riderLocation = LatLng(location.latitude, location.longitude);
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(delivery['senderId'])
                  .get(),
              builder: (context, senderSnapshot) {
                if (senderSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final senderData = senderSnapshot.data?.data() as Map<String, dynamic>?;

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(delivery['recipientId'])
                      .get(),
                  builder: (context, recipientSnapshot) {
                    if (recipientSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final recipientData = recipientSnapshot.data?.data() as Map<String, dynamic>?;

                    return FutureBuilder<DocumentSnapshot?>(
                      future: riderId != null
                          ? FirebaseFirestore.instance.collection('riders').doc(riderId).get()
                          : Future.value(null),
                      builder: (context, riderSnapshot) {
                        final riderData = riderSnapshot.data?.data() as Map<String, dynamic>?;
                        final riderName = riderData?['name'] ?? 'N/A';

                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery #${widget.deliveryId}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Status: ${delivery['status'] ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Created: $formattedDate',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Pickup Time: $formattedPickupTime',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Delivery Time: $formattedDeliveryTime',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Rider: $riderName',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        _buildInfoSection(
                                          'Sender Information:', 
                                          senderData ?? {}, 
                                          'name', 
                                          'phone',
                                          'imageUrl',
                                        ),
                                        const Divider(height: 32),
                                        _buildInfoSection(
                                          'Recipient Information:', 
                                          recipientData ?? {}, 
                                          'name', 
                                          'phone',
                                          'imageUrl',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Items:',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      ...(delivery['items'] as List? ?? [])
                                          .map((item) => _buildItemWidget(item)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Delivery Progress:',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: _buildDeliveryProgress(delivery),
                                ),
                                if (delivery['status'] == 'delivering')
                                  _buildRiderLocationMap(riderLocation),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    String title,
    Map<String, dynamic> data,
    String nameKey,
    String phoneKey,
    String imageKey,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: data[imageKey] != null
                  ? NetworkImage(data[imageKey])
                  : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name: ${data[nameKey] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Phone: ${data[phoneKey] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemWidget(Map<String, dynamic> item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: item['imageUrl'] != null
            ? Image.network(
                item['imageUrl'],
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              )
            : Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: const Icon(
                  Icons.image,
                  color: Colors.grey,
                ),
              ),
      ),
      title: Text(
        item['description'] ?? 'No description',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        'Quantity: ${item['quantity'] ?? 'N/A'}',
        style: TextStyle(
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildDeliveryProgress(Map<String, dynamic> delivery) {
    final List<Map<String, dynamic>> steps = [
      {
        'status': 'pending',
        'title': 'Order Placed',
        'icon': Icons.shopping_cart
      },
      {
        'status': 'accepted',
        'title': 'Order Accepted',
        'icon': Icons.check_circle
      },
      {
        'status': 'picked_up',
        'title': 'Package Picked Up',
        'icon': Icons.local_shipping
      },
      {
        'status': 'delivering',
        'title': 'Out for Delivery',
        'icon': Icons.directions_bike
      },
      {
        'status': 'completed',
        'title': 'Delivered',
        'icon': Icons.done_all
      },
    ];

    final currentStatus = delivery['status'] as String? ?? 'pending';

    return Column(
      children: steps.map((step) {
        final bool isCompleted = _isStepCompleted(
          currentStatus,
          step['status'] as String,
        );
        return ListTile(
          leading: Icon(
            step['icon'] as IconData,
            color: isCompleted ? Colors.green : Colors.grey,
            size: 28,
          ),
          title: Text(
            step['title'] as String,
            style: TextStyle(
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
              color: isCompleted ? Colors.green : Colors.grey,
            ),
          ),
          trailing: isCompleted
              ? const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                )
              : null,
        );
      }).toList(),
    );
  }

  bool _isStepCompleted(String currentStatus, String stepStatus) {
    final List<String> orderOfStatus = [
      'pending',
      'accepted',
      'picked_up',
      'delivering',
      'completed'
    ];
    return orderOfStatus.indexOf(currentStatus) >= 
           orderOfStatus.indexOf(stepStatus);
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
        final data = snapshot.data() as Map<String, dynamic>?;
        final riderId = data?['riderId'];
        if (riderId != null) {
          FirebaseFirestore.instance
              .collection('riders')
              .doc(riderId)
              .snapshots()
              .listen((riderSnapshot) {
            if (riderSnapshot.exists) {
              final riderData = riderSnapshot.data() as Map<String, dynamic>?;
              final location = riderData?['location'];
              if (location != null && mounted) {
                setState(() {
                  _riderLocation = LatLng(
                    location.latitude,
                    location.longitude,
                  );
                });
              }
            }
          });
        }
      }
    });
  }

  Widget _buildRiderLocationMap(LatLng? riderLocation) {
    if (riderLocation == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: riderLocation,
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: riderLocation,
                child: const Icon(Icons.delivery_dining, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
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

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                  color: Colors.blue.shade600,
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
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                Marker(
                  width: 40.0,
                  height: 40.0,
                  point: deliveryLocation,
                  child: const Icon(
                    Icons.flag,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
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
