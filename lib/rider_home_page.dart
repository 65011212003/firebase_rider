import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'location_service.dart';
import 'login_page.dart';
import 'dart:math' show cos, sqrt, asin;
import 'package:intl/intl.dart';

class RiderHomePage extends StatefulWidget {
  final String riderId;

  const RiderHomePage({
    Key? key, 
    required this.riderId,
  }) : super(key: key);

  @override
  _RiderHomePageState createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  Position? _currentPosition;
  String? _activeDeliveryId;
  bool _isLoading = true;
  final LocationService _locationService = LocationService();
  final double _maxDeliveryRadius = 20; // Maximum radius in meters

  @override
  void initState() {
    super.initState();
    _initializeRider();
  }

  Future<void> _initializeRider() async {
    try {
      // Get current location
      _currentPosition = await Geolocator.getCurrentPosition();
      
      // Check for active delivery
      final riderDoc = await FirebaseFirestore.instance
          .collection('riders')
          .doc(widget.riderId)
          .get();
      
      if (riderDoc.exists) {
        final riderData = riderDoc.data() as Map<String, dynamic>;
        _activeDeliveryId = riderData['activeDeliveryId'] as String?;
      }

      // Start location tracking if there's an active delivery
      if (_activeDeliveryId != null) {
        _locationService.startTracking(widget.riderId, _activeDeliveryId!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing rider: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _isWithinDeliveryRadius(GeoPoint location) async {
    try {
      if (_currentPosition == null) return false;
      
      // Ensure location is not null before accessing its properties
      if (location == null) return false;
      
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        location.latitude,
        location.longitude,
      );
      
      return distance <= _maxDeliveryRadius;
    } catch (e) {
      print('Error calculating delivery radius: $e');
      return false;
    }
  }

  Future<void> _acceptDelivery(String deliveryId) async {
    try {
      final deliveryDoc = await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(deliveryId)
          .get();
      
      if (!deliveryDoc.exists) return;
      
      final deliveryData = deliveryDoc.data() as Map<String, dynamic>;
      final pickupLocation = deliveryData['pickupLocation'] as GeoPoint?;
      
      // Add null check for pickupLocation
      if (pickupLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup location not found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!await _isWithinDeliveryRadius(pickupLocation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be within 20 meters of pickup location'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Check if delivery is still available
        final freshDelivery = await transaction.get(deliveryDoc.reference);
        if (freshDelivery.get('status') != 'pending') {
          throw Exception('Delivery already taken');
        }

        // Update delivery status
        transaction.update(deliveryDoc.reference, {
          'status': 'accepted',
          'riderId': widget.riderId,
        });

        // Update rider's active delivery
        transaction.update(
          FirebaseFirestore.instance.collection('riders').doc(widget.riderId),
          {'activeDeliveryId': deliveryId},
        );
      });

      setState(() {
        _activeDeliveryId = deliveryId;
      });

      // Start location tracking
      _locationService.startTracking(widget.riderId, deliveryId);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting delivery: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateDeliveryStatus(String status) async {
    if (_activeDeliveryId == null) return;

    try {
      if ((status == 'picked_up' || status == 'completed') && 
          !await _takeAndUploadPhoto(status)) {
        return;
      }

      // Create update data map with explicit type
      final Map<String, dynamic> updateData = {
        'status': status,
      };

      // Only add location if we can get it
      try {
        final position = await Geolocator.getCurrentPosition();
        updateData['riderLocation'] = GeoPoint(position.latitude, position.longitude);
      } catch (e) {
        print('Error getting location: $e');
        // Continue without location if we can't get it
      }

      // Add timestamps based on status
      if (status == 'picked_up') {
        updateData['pickupTime'] = FieldValue.serverTimestamp();
      } else if (status == 'completed') {
        updateData['deliveryTime'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(_activeDeliveryId)
          .update(updateData);

      if (status == 'completed') {
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(widget.riderId)
            .update({'activeDeliveryId': null});

        _locationService.stopTracking();
        setState(() {
          _activeDeliveryId = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _takeAndUploadPhoto(String status) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please take a photo'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('delivery_photos')
          .child('${_activeDeliveryId}_${status}.jpg');
      
      await ref.putFile(File(image.path));
      final photoUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(_activeDeliveryId)
          .update({
        '${status}PhotoUrl': photoUrl,
      });

      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading photo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation when delivery is active
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Rider Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          automaticallyImplyLeading: _activeDeliveryId == null,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                if (_activeDeliveryId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Complete current delivery first'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
            ),
          ],
        ),
        body: _activeDeliveryId != null
            ? _buildActiveDelivery()
            : _buildAvailableDeliveries(),
      ),
    );
  }

  Widget _buildActiveDelivery() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliveries')
          .doc(_activeDeliveryId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final delivery = snapshot.data!.data() as Map<String, dynamic>;
        final status = delivery['status'] as String;

        // Wrap the Column in a SingleChildScrollView
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildDeliveryMap(delivery),
              _buildDeliveryInfo(delivery),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildStatusButtons(status),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailableDeliveries() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliveries')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final deliveries = snapshot.data!.docs;

        if (deliveries.isEmpty) {
          return const Center(
            child: Text(
              'No available deliveries',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: deliveries.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final delivery = deliveries[index].data() as Map<String, dynamic>;
            final deliveryId = deliveries[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 8,
              ),
              elevation: 2,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  'Delivery #$deliveryId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Status: ${delivery['status']}',
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _acceptDelivery(deliveryId),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveryMap(Map<String, dynamic> delivery) {
    final pickupLocation = delivery['pickupLocation'] as GeoPoint?;
    final deliveryLocation = delivery['deliveryLocation'] as GeoPoint?;
    
    if (pickupLocation == null || deliveryLocation == null) {
      return const SizedBox.shrink();
    }

    final pickup = LatLng(pickupLocation.latitude, pickupLocation.longitude);
    final destination = LatLng(deliveryLocation.latitude, deliveryLocation.longitude);

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16.0),
      child: LocationMapWidget(
        pickupLocation: pickup,
        deliveryLocation: destination,
      ),
    );
  }

  Widget _buildDeliveryInfo(Map<String, dynamic> delivery) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // Wrap the Column in a SingleChildScrollView if needed
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery #${delivery['id']}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Status', delivery['status']),
            _buildInfoRow('Sender', delivery['senderName'] ?? 'N/A'),
            _buildInfoRow('Recipient', delivery['recipientName'] ?? 'N/A'),
            _buildInfoRow('Pickup Address', delivery['pickupAddress'] ?? 'N/A'), 
            _buildInfoRow('Delivery Address', delivery['deliveryAddress'] ?? 'N/A'),
            _buildInfoRow('Created At', delivery['createdAt']?.toDate().toString() ?? 'N/A'),
            _buildInfoRow('Pickup Time', delivery['pickupTime']?.toDate().toString() ?? 'N/A'),
            _buildInfoRow('Delivery Time', delivery['deliveryTime']?.toDate().toString() ?? 'N/A'),
            _buildInfoRow('Total Items', (delivery['items'] as List?)?.length.toString() ?? '0'),
            _buildInfoRow('Notes', delivery['notes'] ?? 'N/A'),
            if (delivery['pickupPhotoUrl'] != null || delivery['deliveryPhotoUrl'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Delivery Photos:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            const Text(
              'Items:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Replace the existing ListView.builder for items with this updated version
            Container(
              constraints: const BoxConstraints(maxHeight: 300), // Increased height for better visibility
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: (delivery['items'] as List? ?? []).length,
                itemBuilder: (context, index) {
                  final item = (delivery['items'] as List)[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            item['description'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Quantity: ${item['quantity']}',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        if (item['imageUrl'] != null)
                          GestureDetector(
                            onTap: () => _showFullScreenImage(item['imageUrl']),
                            child: Container(
                              width: double.infinity,
                              height: 200,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Image.network(
                                item['imageUrl'],
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
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButtons(String status) {
    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: 16, // Reduced horizontal padding
        vertical: 12,   // Reduced vertical padding
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      minimumSize: const Size(120, 40), // Set minimum size instead of using constraints
    );

    switch (status) {
      case 'accepted':
        return ElevatedButton(
          style: buttonStyle,
          onPressed: () => _updateDeliveryStatus('picked_up'),
          child: const Text(
            'Mark as Picked Up',
            style: TextStyle(fontSize: 14), // Reduced font size
          ),
        );
      case 'picked_up':
        return ElevatedButton(
          style: buttonStyle,
          onPressed: () => _updateDeliveryStatus('delivering'),
          child: const Text(
            'Start Delivery',
            style: TextStyle(fontSize: 14),
          ),
        );
      case 'delivering':
        return ElevatedButton(
          style: buttonStyle,
          onPressed: () => _updateDeliveryStatus('completed'),
          child: const Text(
            'Complete Delivery',
            style: TextStyle(fontSize: 14),
          ),
        );
      default:
        return const SizedBox.shrink();
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
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                );
              },
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
}

// Add this class at the end of the file, after the _RiderHomePageState class

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

    final distance = _calculateDistance(widget.pickupLocation, widget.deliveryLocation);
    final zoom = _calculateZoomLevel(distance);

    return Container(
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
            center: center, // Changed from initialCenter
            zoom: zoom, // Changed from initialZoom
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

  double _calculateDistance(LatLng point1, LatLng point2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((point2.latitude - point1.latitude) * p)/2 + 
            c(point1.latitude * p) * c(point2.latitude * p) * 
            (1 - c((point2.longitude - point1.longitude) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  double _calculateZoomLevel(double distance) {
    if (distance < 1) return 14;
    if (distance < 5) return 12;
    if (distance < 10) return 11;
    if (distance < 50) return 9;
    return 8;
  }
}

