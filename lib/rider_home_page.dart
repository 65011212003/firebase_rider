import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'login_page.dart';
import 'dart:developer' as developer;
import 'location_service.dart';

class RiderHomePage extends StatelessWidget {
  final String riderId;

  const RiderHomePage({Key? key, required this.riderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        backgroundColor: Colors.purple.shade400,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('Sign Out'),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                            (Route<dynamic> route) => false,
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade100, Colors.purple.shade300],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('riders').doc(riderId).snapshots(),
          builder: (context, riderSnapshot) {
            if (riderSnapshot.hasError) {
              developer.log('Error in rider stream: ${riderSnapshot.error}');
              return Center(child: Text('Error: ${riderSnapshot.error}', style: TextStyle(color: Colors.red[800])));
            }

            if (!riderSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final riderData = riderSnapshot.data!.data() as Map<String, dynamic>?;
            final String? activeDeliveryId = riderData?['activeDeliveryId'] as String?;

            return StreamBuilder<QuerySnapshot>(
              stream: activeDeliveryId != null
                  ? FirebaseFirestore.instance
                      .collection('deliveries')
                      .where(FieldPath.documentId, isEqualTo: activeDeliveryId)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('deliveries')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  developer.log('Error in deliveries stream: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red[800])));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final deliveries = snapshot.data!.docs;

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverToBoxAdapter(
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rider Dashboard',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.purple[800]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ID: $riderId',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.purple[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          activeDeliveryId != null ? 'Active Delivery' : 'Available Deliveries',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.purple[800]),
                        ),
                      ),
                    ),
                    if (activeDeliveryId != null)
                      SliverPadding(
                        padding: const EdgeInsets.all(16.0),
                        sliver: SliverToBoxAdapter(
                          child: deliveries.isEmpty
                              ? Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text('Active delivery not found', style: TextStyle(color: Colors.red[800])),
                                  ),
                                )
                              : ActiveDeliveryItem(
                                  delivery: deliveries.first.data() as Map<String, dynamic>,
                                  deliveryId: deliveries.first.id,
                                  riderId: riderId,
                                ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16.0),
                        sliver: deliveries.isEmpty
                            ? SliverToBoxAdapter(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text('No available deliveries', style: TextStyle(color: Colors.grey[600])),
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final delivery = deliveries[index].data() as Map<String, dynamic>;
                                    final String deliveryId = deliveries[index].id;
                                    return AvailableDeliveryItem(
                                      delivery: delivery,
                                      deliveryId: deliveryId,
                                      riderId: riderId,
                                    );
                                  },
                                  childCount: deliveries.length,
                                ),
                              ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AvailableDeliveryItem extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final String deliveryId;
  final String riderId;

  const AvailableDeliveryItem({
    Key? key,
    required this.delivery,
    required this.deliveryId,
    required this.riderId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdAt = (delivery['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy HH:mm').format(createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.white.withOpacity(0.9),
      child: ListTile(
        title: Text('Delivery #$deliveryId', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Created: $formattedDate'),
        trailing: ElevatedButton(
          onPressed: () => _acceptDelivery(context),
          child: const Text('Accept'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.green,
          ),
        ),
      ),
    );
  }

  void _acceptDelivery(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('deliveries').doc(deliveryId).update({
        'status': 'accepted',
        'riderId': riderId,
      });
      await FirebaseFirestore.instance.collection('riders').doc(riderId).update({
        'activeDeliveryId': deliveryId,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery accepted')),
      );
    } catch (e) {
      developer.log('Error accepting delivery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting delivery: $e')),
      );
    }
  }
}

class ActiveDeliveryItem extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final String deliveryId;
  final String riderId;

  const ActiveDeliveryItem({
    Key? key,
    required this.delivery,
    required this.deliveryId,
    required this.riderId,
  }) : super(key: key);

  @override
  _ActiveDeliveryItemState createState() => _ActiveDeliveryItemState();
}

class _ActiveDeliveryItemState extends State<ActiveDeliveryItem> {
  late BuildContext _context;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _context = context;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Delivery #${widget.deliveryId}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Status: ${widget.delivery['status']}'),
            Text('Pickup: ${_formatLocation(widget.delivery['pickupLocation'])}'),
            Text('Delivery: ${_formatLocation(widget.delivery['deliveryLocation'])}'),
            const SizedBox(height: 16),
            const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...(widget.delivery['items'] as List).map((item) => Text('- ${item['description']}')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _updateDeliveryStatus(),
              child: Text(_getNextActionText()),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLocation(GeoPoint location) {
    return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
  }

  String _getNextActionText() {
    switch (widget.delivery['status']) {
      case 'accepted':
        return 'Pick Up';
      case 'picked_up':
        return 'Start Delivery';
      case 'delivering':
        return 'Complete Delivery';
      default:
        return 'Update Status';
    }
  }

  Future<void> _updateDeliveryStatus() async {
    String newStatus;
    switch (widget.delivery['status']) {
      case 'accepted':
        newStatus = 'picked_up';
        break;
      case 'picked_up':
        newStatus = 'delivering';
        break;
      case 'delivering':
        newStatus = 'completed';
        break;
      default:
        return;
    }

    try {
      // Change the type to Map<String, dynamic> to accept both String and FieldValue
      final Map<String, dynamic> updateData = {
        'status': newStatus,
      };

      if (newStatus == 'picked_up') {
        updateData['pickupTime'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'completed') {
        updateData['deliveryTime'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance.collection('deliveries').doc(widget.deliveryId).update(updateData);

      if (newStatus == 'picked_up' || newStatus == 'completed') {
        final imageFile = await _takePhoto();
        if (imageFile == null) {
          ScaffoldMessenger.of(_context).showSnackBar(
            SnackBar(content: Text('Please take a photo of the ${newStatus == 'picked_up' ? 'package' : 'delivery'}')),
          );
          return;
        }
        await _uploadPhotoAndUpdateStatus(imageFile, newStatus);
      } else {
        await _updateStatusInFirestore(newStatus);
      }

      // Start location tracking when status changes to 'delivering'
      if (newStatus == 'delivering') {
        LocationService().startTracking(widget.riderId, widget.deliveryId);
      }

      // Stop location tracking when status changes to 'completed'
      if (newStatus == 'completed') {
        LocationService().stopTracking();
      }
    } catch (e) {
      developer.log('Error updating delivery status: $e');
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(content: Text('Error updating delivery status: $e')),
      );
    }
  }

  Future<File?> _takePhoto() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    return image != null ? File(image.path) : null;
  }

  Future<void> _uploadPhotoAndUpdateStatus(File imageFile, String newStatus) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('${newStatus == 'picked_up' ? 'pickup' : 'delivery'}_photos/${widget.deliveryId}.jpg');
      await ref.putFile(imageFile);
      final photoUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('deliveries').doc(widget.deliveryId).update({
        'status': newStatus,
        '${newStatus == 'picked_up' ? 'pickupPhotoUrl' : 'deliveryPhotoUrl'}': photoUrl,
      });

      if (newStatus == 'completed') {
        await FirebaseFirestore.instance.collection('riders').doc(widget.riderId).update({
          'activeDeliveryId': null,
        });
      }

      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(content: Text('Photo uploaded and delivery status updated to $newStatus')),
      );
    } catch (e) {
      developer.log('Error updating delivery status: $e');
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(content: Text('Error updating delivery status: $e')),
      );
    }
  }

  Future<void> _updateStatusInFirestore(String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('deliveries').doc(widget.deliveryId).update({
        'status': newStatus,
      });

      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(content: Text('Delivery status updated to $newStatus')),
      );
    } catch (e) {
      developer.log('Error updating delivery status: $e');
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(content: Text('Error updating delivery status: $e')),
      );
    }
  }

  @override
  void dispose() {
    LocationService().stopTracking();
    super.dispose();
  }
}
