import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'dart:math' show cos, sqrt, asin;
import 'package:easy_stepper/easy_stepper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'location_service.dart';
import 'dart:async';

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
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateEstimates();
    });
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

  Widget _buildPhotoCard(String title, String imageUrl, DateTime? timestamp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timestamp != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
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
          child: Container(
            width: double.infinity,
            height: 200,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
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
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  // Add this method inside the _DeliveryDetailPageState class
  Widget _buildPhotoWithTimestamp(String title, String imageUrl, Timestamp? timestamp, [IconData? icon]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timestamp != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (icon != null) Icon(icon, size: 20, color: Colors.grey),
                    if (icon != null) const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat('MMM d, y HH:mm').format(timestamp.toDate()),
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
          child: Container(
            width: double.infinity,
            height: 200,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Add this method to initialize the tracking
  void _initializeTracking(Map<String, dynamic> delivery) {
    if ((delivery['status'] == 'delivering' || delivery['status'] == 'picked_up') && 
        delivery['riderId'] != null) {
      _deliverySubscription = FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.deliveryId)
          .snapshots()
          .listen((snapshot) async {
        if (!snapshot.exists) return;
        
        final deliveryData = snapshot.data() as Map<String, dynamic>;
        if (deliveryData['riderLocation'] != null) {
          final location = deliveryData['riderLocation'] as GeoPoint;
          final destination = deliveryData['status'] == 'picked_up'
              ? deliveryData['deliveryLocation'] as GeoPoint
              : deliveryData['pickupLocation'] as GeoPoint;
          
          final routeResult = await findDistance(
            location.latitude,
            location.longitude,
            destination.latitude,
            destination.longitude,
          );

          if (mounted) {
            setState(() {
              _riderLocation = LatLng(location.latitude, location.longitude);
              _routePoints = routeResult['routePoints'] as List<LatLng>;
              _estimatedDistance = routeResult['distance'] as double;
              final timeInMinutes = (_estimatedDistance / 30) * 60;
              _estimatedTime = '${timeInMinutes.round()} min';
            });
            
            // Center map on rider location
            _mapController.move(_riderLocation!, 15);
          }
        }
      });
    }
  }

  // Add this method to clean up subscription
  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _deliverySubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateEstimates() async {
    if (_riderLocation != null && mounted) {
      final delivery = await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.deliveryId)
          .get();
      
      final data = delivery.data();
      if (data == null) return;

      final destinationPoint = data['status'] == 'picked_up' 
          ? data['deliveryLocation']
          : data['pickupLocation'];

      if (destinationPoint == null) return;

      final result = await findDistance(
        _riderLocation!.latitude,
        _riderLocation!.longitude,
        destinationPoint.latitude,
        destinationPoint.longitude,
      );

      if (mounted) {
        setState(() {
          _estimatedDistance = result['distance'];
          // Assuming average speed of 30 km/h
          final timeInMinutes = (_estimatedDistance / 30) * 60;
          _estimatedTime = '${timeInMinutes.round()} min';
        });
      }
    }
  }

  // Add this widget where you want to show the live tracking interface
  Widget _buildLiveTrackingCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            height: 300,
            padding: const EdgeInsets.all(8),
            child: _riderLocation == null 
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : FlutterMap(
                    mapController: _mapController,
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
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 50,
                            height: 50,
                            point: _riderLocation!,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delivery_dining,
                                color: Colors.blue,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTrackingInfo(
                  Icons.timer,
                  'Estimated Time',
                  _estimatedTime,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                _buildTrackingInfo(
                  Icons.directions_bike,
                  'Distance',
                  '${_estimatedDistance.toStringAsFixed(1)} km',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingInfo(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 30),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
  
}

class LocationMapWidget extends StatefulWidget {
  final LatLng pickupLocation;
  final LatLng deliveryLocation;

  const LocationMapWidget({
    Key? key,
    required this.pickupLocation,
    required this.deliveryLocation,
  }) : super(key: key);

  @override
  _LocationMapWidgetState createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<LocationMapWidget> {
  List<LatLng> routePoints = [];

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final points = await LocationService.getRoute(
      widget.pickupLocation,
      widget.deliveryLocation,
    );
    setState(() {
      routePoints = points;
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      (widget.pickupLocation.latitude + widget.deliveryLocation.latitude) / 2,
      (widget.pickupLocation.longitude + widget.deliveryLocation.longitude) / 2,
    );

    final distance = calculateDistance(widget.pickupLocation, widget.deliveryLocation);
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
            // Draw the route
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
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
                  point: widget.pickupLocation,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                Marker(
                  width: 40.0,
                  height: 40.0,
                  point: widget.deliveryLocation,
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

