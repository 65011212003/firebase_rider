import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'login_page.dart';

class RiderHomePage extends StatelessWidget {
  final String riderId;

  const RiderHomePage({Key? key, required this.riderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Deliveries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              // Show a confirmation dialog
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
                          // Navigate to the LoginPage
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('deliveries')
            .where('status', whereIn: ['pending', 'accepted', 'picked_up'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final deliveries = snapshot.data!.docs;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('riders').doc(riderId).snapshots(),
            builder: (context, riderSnapshot) {
              if (riderSnapshot.hasError) {
                return Center(child: Text('Error: ${riderSnapshot.error}'));
              }

              if (!riderSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final riderData = riderSnapshot.data!.data() as Map<String, dynamic>?;
              final String? activeDeliveryId = riderData?['activeDeliveryId'] as String?;

              if (deliveries.isEmpty && activeDeliveryId == null) {
                return const Center(child: Text('No available deliveries.'));
              }

              return ListView.builder(
                itemCount: deliveries.length,
                itemBuilder: (context, index) {
                  final delivery = deliveries[index].data() as Map<String, dynamic>;
                  final String deliveryId = deliveries[index].id;
                  final bool isActiveDelivery = deliveryId == activeDeliveryId;

                  // Only show the active delivery or available deliveries if the rider has no active delivery
                  if (isActiveDelivery || activeDeliveryId == null) {
                    return AvailableDeliveryItem(
                      delivery: delivery,
                      deliveryId: deliveryId,
                      riderId: riderId,
                      isActiveDelivery: isActiveDelivery,
                    );
                  } else {
                    return const SizedBox.shrink(); // Hide other deliveries
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class AvailableDeliveryItem extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final String deliveryId;
  final String riderId;
  final bool isActiveDelivery;

  const AvailableDeliveryItem({
    Key? key,
    required this.delivery,
    required this.deliveryId,
    required this.riderId,
    required this.isActiveDelivery,
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
            title: Text('Delivery #$deliveryId', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Created: $formattedDate'),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pickup: ${_formatLocation(delivery['pickupLocation'])}'),
                const SizedBox(height: 8),
                Text('Delivery: ${_formatLocation(delivery['deliveryLocation'])}'),
                const SizedBox(height: 16),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(delivery['items'] as List).map((item) => Text('- ${item['description']}')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!isActiveDelivery)
                  _buildActionButton(context, 'Accept', Colors.green, () => _updateDeliveryStatus(context, 'accepted'))
                else ...[
                  _buildActionButton(context, 'Pickup', Colors.blue, () => _updateDeliveryStatus(context, 'picked_up')),
                  _buildActionButton(context, 'Delivering', Colors.orange, () => _updateDeliveryStatus(context, 'delivering')),
                  _buildActionButton(context, 'Finish', Colors.green, () => _updateDeliveryStatus(context, 'completed')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: delivery['status'] == label.toLowerCase() ? null : onPressed,
      child: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: Colors.grey,
      ),
    );
  }

  String _formatLocation(GeoPoint location) {
    return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
  }

  void _updateDeliveryStatus(BuildContext context, String newStatus) async {
    if (newStatus == 'picked_up' || newStatus == 'completed') {
      final imageFile = await _takePhoto(context);
      if (imageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please take a photo of the ${newStatus == 'picked_up' ? 'package' : 'delivery'}')),
        );
        return;
      }
      await _uploadPhotoAndUpdateStatus(context, imageFile, newStatus);
    } else {
      await _updateStatusInFirestore(context, newStatus);
    }
  }

  Future<File?> _takePhoto(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    return image != null ? File(image.path) : null;
  }

  Future<void> _uploadPhotoAndUpdateStatus(BuildContext context, File imageFile, String newStatus) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('${newStatus == 'picked_up' ? 'pickup' : 'delivery'}_photos/$deliveryId.jpg');
      await ref.putFile(imageFile);
      final photoUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('deliveries').doc(deliveryId).update({
        'status': newStatus,
        'riderId': riderId,
        '${newStatus == 'picked_up' ? 'pickupPhotoUrl' : 'deliveryPhotoUrl'}': photoUrl,
      });

      if (newStatus == 'completed') {
        await FirebaseFirestore.instance.collection('riders').doc(riderId).update({
          'activeDeliveryId': null,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo uploaded and delivery status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating delivery status: $e')),
      );
    }
  }

  Future<void> _updateStatusInFirestore(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('deliveries').doc(deliveryId).update({
        'status': newStatus,
        'riderId': riderId,
      });

      if (newStatus == 'accepted') {
        await FirebaseFirestore.instance.collection('riders').doc(riderId).update({
          'activeDeliveryId': deliveryId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delivery status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating delivery status: $e')),
      );
    }
  }
}
