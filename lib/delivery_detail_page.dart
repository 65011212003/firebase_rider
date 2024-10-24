// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class DeliveryDetailPage extends StatefulWidget {
  final String deliveryId;

  const DeliveryDetailPage({
    super.key,
    required this.deliveryId,
  });

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  final PopupController _popupLayerController = PopupController();
  LatLng? _riderLocation;
  final MapController _mapController = MapController();
  List<LatLng> polylineCoordinates = [];
  StreamSubscription<DocumentSnapshot>? _deliverySubscription;
  List<LatLng> _routePoints = [];

  // Add these variables
  Timer? _locationUpdateTimer;
  double _estimatedDistance = 0.0;
  String _estimatedTime = 'Calculating...';

  Future<Map<String, dynamic>> findDistance(
      double startLat, double startLong, double endLat, double endLong) async {
    final response = await http.get(Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/$startLong,$startLat;$endLong,$endLat?overview=full&geometries=geojson'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
      final distance = data['routes'][0]['distance'] as num;
      
      // Convert coordinates to List<LatLng>
      List<LatLng> routePoints = [];
      for (var coord in coordinates) {
        if (coord is List && coord.length >= 2) {
          double lng = (coord[0] as num).toDouble();
          double lat = (coord[1] as num).toDouble();
          routePoints.add(LatLng(lat, lng));
        }
      }
      
      return {
        "isError": false,
        "distance": (distance / 1000),
        "routePoints": routePoints
      };
    }
    return {"isError": true, "routePoints": <LatLng>[], "distance": -1};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delivery Details', 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF5300F9), // Updated color
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF5300F9).withOpacity(0.5), // Updated color with opacity
              Color(0xFF5300F9), // Updated color
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

            // Initialize tracking when delivery data is available
            _initializeTracking(delivery);

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
                                if (pickupLocation != null && deliveryLocation != null)
                                  FutureBuilder<Map<String, dynamic>>(
                                    future: findDistance(
                                      pickupLocation.latitude,
                                      pickupLocation.longitude,
                                      deliveryLocation.latitude,
                                      deliveryLocation.longitude
                                    ),
                                    builder: (context, routeSnapshot) {
                                      if (routeSnapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      
                                      final routePoints = routeSnapshot.data?['routePoints'] as List<LatLng>? ?? [];
                                      
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
                                              initialCenter: LatLng(
                                                (pickupLocation.latitude + deliveryLocation.latitude) / 2,
                                                (pickupLocation.longitude + deliveryLocation.longitude) / 2,
                                              ),
                                              initialZoom: 13,
                                            ),
                                            children: [
                                              TileLayer(
                                                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                subdomains: const ['a', 'b', 'c'],
                                              ),
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
                                                    point: pickupLocation,
                                                    width: 40,
                                                    height: 40,
                                                    child: const Icon(
                                                      Icons.location_on,
                                                      color: Colors.green,
                                                      size: 40,
                                                    ),
                                                  ),
                                                  Marker(
                                                    point: deliveryLocation,
                                                    width: 40,
                                                    height: 40,
                                                    child: const Icon(
                                                      Icons.flag,
                                                      color: Colors.red,
                                                      size: 40,
                                                    ),
                                                  ),
                                                  if (riderLocation != null)
                                                    Marker(
                                                      point: riderLocation,
                                                      width: 40,
                                                      height: 40,
                                                      child: const Icon(
                                                        Icons.delivery_dining,
                                                        color: Colors.blue,
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Delivery Progress Photos:',
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
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (delivery['picked_upPhotoUrl'] != null)
                                              _buildPhotoWithTimestamp(
                                                'Picked Up Photo',
                                                delivery['picked_upPhotoUrl'],
                                                delivery['pickupTime'],
                                                Icons.inventory_2,
                                              ),
                                            if (delivery['allItemsImageUrl'] != null)
                                              _buildPhotoWithTimestamp(
                                                'All Items Photo', 
                                                delivery['allItemsImageUrl'],
                                                delivery['pickupTime'],
                                                Icons.inventory,
                                              ),
                                            if (delivery['completedPhotoUrl'] != null)
                                              _buildPhotoWithTimestamp(
                                                'Completed Photo',
                                                delivery['completedPhotoUrl'], 
                                                delivery['deliveryTime'],
                                                Icons.check_circle,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Add this widget after _buildDeliveryMap:
                                if (delivery['status'] == 'delivering' && _riderLocation != null)
                                  Column(
                                    children: [
                                      Container(
                                        height: 300,
                                        margin: const EdgeInsets.symmetric(vertical: 16),
                                        child: FlutterMap(
                                          options: MapOptions(
                                            initialCenter: _riderLocation!,
                                            initialZoom: 15,
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              subdomains: const ['a', 'b', 'c'],
                                            ),
                                            if (_routePoints.isNotEmpty)
                                              PolylineLayer(
                                                polylines: [
                                                  Polyline(
                                                    points: _routePoints,
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
                                                  point: LatLng(
                                                    delivery['pickupLocation'].latitude,
                                                    delivery['pickupLocation'].longitude,
                                                  ),
                                                  child: const Icon(
                                                    Icons.location_on,
                                                    color: Colors.green,
                                                    size: 40,
                                                  ),
                                                ),
                                                Marker(
                                                  width: 40,
                                                  height: 40,
                                                  point: LatLng(
                                                    delivery['deliveryLocation'].latitude,
                                                    delivery['deliveryLocation'].longitude,
                                                  ),
                                                  child: const Icon(
                                                    Icons.flag,
                                                    color: Colors.red,
                                                    size: 40,
                                                  ),
                                                ),
                                                Marker(
                                                  width: 40,
                                                  height: 40,
                                                  point: _riderLocation!,
                                                  child: const Icon(
                                                    Icons.delivery_dining,
                                                    color: Colors.blue,
                                                    size: 40,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Card(
                                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              Column(
                                                children: [
                                                  const Icon(Icons.timer, color: Colors.blue),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Est. Time',
                                                    style: TextStyle(color: Colors.grey[600]),
                                                  ),
                                                  const Text('15-20 min'),
                                                ],
                                              ),
                                              Column(
                                                children: [
                                                  const Icon(Icons.directions_bike, color: Colors.blue),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Distance',
                                                    style: TextStyle(color: Colors.grey[600]),
                                                  ),
                                                  const Text('2.5 km'),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                // Inside your build method, where you want to show the tracking interface
                                // Add this after the delivery progress stepper and before the photos section

                                if (delivery['status'] == 'delivering' || delivery['status'] == 'picked_up') ...[
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Live Tracking:',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLiveTrackingCard(),
                                ]
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
    final currentStep = steps.indexWhere((step) => step['status'] == currentStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EasyStepper(
            activeStep: currentStep,
            stepShape: StepShape.circle,
            stepBorderRadius: 12,
            borderThickness: 2,
            padding: const EdgeInsets.all(24),
            stepRadius: 28,
            finishedStepBorderColor: Colors.green,
            finishedStepTextColor: Colors.green,
            finishedStepBackgroundColor: Colors.green,
            activeStepIconColor: Colors.white,
            activeStepBorderColor: Colors.purple,
            activeStepTextColor: Colors.purple,
            loadingAnimation: "false",
            steps: steps.map((step) {
              return EasyStep(
                customStep: Icon(
                  step['icon'] as IconData,
                  size: 24,
                  color: _isStepCompleted(currentStatus, step['status'] as String) 
                      ? Colors.white 
                      : Colors.grey,
                ),
                title: step['title'] as String,
              );
            }).toList(),
          ),
        ],
      ),
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
    // Start periodic updates
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateEstimates();
    });
  }

  void _listenToRiderLocation() {
    _deliverySubscription = FirebaseFirestore.instance
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
        if (data?['status'] == 'completed') {
          _deliverySubscription?.cancel();
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
    );
  }

  // Add this new method to _DeliveryDetailPageState class
  Widget _buildDeliveryPhotos(Map<String, dynamic> delivery) {
    if (delivery['pickupPhotoUrl'] == null && delivery['deliveryPhotoUrl'] == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Delivery Photos:',
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (delivery['pickupPhotoUrl'] != null)
                  _buildPhotoCard(
                    'Pickup Photo',
                    delivery['pickupPhotoUrl'],
                    delivery['pickupTime']?.toDate(),
                  ),
                if (delivery['deliveryPhotoUrl'] != null)
                  _buildPhotoCard(
                    'Delivery Photo',
                    delivery['deliveryPhotoUrl'],
                    delivery['deliveryTime']?.toDate(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Add these methods to the _DeliveryDetailPageState class

  void _initializeTracking(Map<String, dynamic> delivery) {
    if (delivery['status'] == 'delivering' || delivery['status'] == 'picked_up') {
      // Start location updates
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _updateEstimates();
      });
    }
  }

  Widget _buildPhotoWithTimestamp(
    String title,
    String imageUrl,
    Timestamp? timestamp,
    [IconData? icon]
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (timestamp != null)
          Text(
            DateFormat('MMM d, y HH:mm').format(timestamp.toDate()),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showFullScreenImage(imageUrl),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveTrackingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Tracking Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.timer),
                    const SizedBox(height: 8),
                    Text(
                      'Est. Time',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(_estimatedTime),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.directions_car),
                    const SizedBox(height: 8),
                    Text(
                      'Distance',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text('${_estimatedDistance.toStringAsFixed(1)} km'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateEstimates() async {
    if (_riderLocation == null) return;

    try {
      // Get the delivery document
      final deliveryDoc = await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.deliveryId)
          .get();

      if (!deliveryDoc.exists) return;

      final delivery = deliveryDoc.data() as Map<String, dynamic>;
      final deliveryLocation = delivery['deliveryLocation'] as GeoPoint;
      final destination = LatLng(deliveryLocation.latitude, deliveryLocation.longitude);

      // Calculate route and update estimates
      final result = await findDistance(
        _riderLocation!.latitude,
        _riderLocation!.longitude,
        destination.latitude,
        destination.longitude,
      );

      if (!result['isError']) {
        setState(() {
          _estimatedDistance = result['distance'];
          // Assuming average speed of 30 km/h
          final timeInMinutes = (_estimatedDistance / 30 * 60).round();
          _estimatedTime = '$timeInMinutes min';
        });
      }
    } catch (e) {
      print('Error updating estimates: $e');
    }
  }

  Widget _buildPhotoCard(String title, String imageUrl, DateTime? timestamp) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (timestamp != null)
                  Text(
                    DateFormat('MMM d, y HH:mm').format(timestamp),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showFullScreenImage(imageUrl),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
