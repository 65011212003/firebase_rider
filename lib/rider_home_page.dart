import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'login_page.dart';
import 'dart:developer' as developer;
import 'package:collection/collection.dart';

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
            colors: [Colors.purple.shade200, Colors.purple.shade400],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('deliveries')
              .where('status', whereIn: ['pending', 'accepted', 'picked_up'])
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              developer.log('Error in deliveries stream: ${snapshot.error}');
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final deliveries = snapshot.data!.docs;

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('riders').doc(riderId).snapshots(),
              builder: (context, riderSnapshot) {
                if (riderSnapshot.hasError) {
                  developer.log('Error in rider stream: ${riderSnapshot.error}');
                  return Center(child: Text('Error: ${riderSnapshot.error}', style: const TextStyle(color: Colors.white)));
                }

                if (!riderSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final riderData = riderSnapshot.data!.data() as Map<String, dynamic>?;
                final String? activeDeliveryId = riderData?['activeDeliveryId'] as String?;

                final pendingDeliveries = deliveries.where((doc) => doc['status'] == 'pending').toList();
                final activeDelivery = activeDeliveryId != null
                    ? deliveries.firstWhereOrNull((doc) => doc.id == activeDeliveryId)
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeDelivery != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Active Delivery', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      ),
                    if (activeDelivery != null)
                      AvailableDeliveryItem(
                        delivery: activeDelivery.data() as Map<String, dynamic>,
                        deliveryId: activeDelivery.id,
                        riderId: riderId,
                        isActiveDelivery: true,
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Pending Requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                    ),
                    if (pendingDeliveries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('No pending requests', style: TextStyle(color: Colors.white)),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: pendingDeliveries.length,
                          itemBuilder: (context, index) {
                            final delivery = pendingDeliveries[index].data() as Map<String, dynamic>;
                            final String deliveryId = pendingDeliveries[index].id;
                            return AvailableDeliveryItem(
                              delivery: delivery,
                              deliveryId: deliveryId,
                              riderId: riderId,
                              isActiveDelivery: false,
                            );
                          },
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

class AvailableDeliveryItem extends StatefulWidget {
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
  _AvailableDeliveryItemState createState() => _AvailableDeliveryItemState();
}

class _AvailableDeliveryItemState extends State<AvailableDeliveryItem> {
  bool _mounted = false;

  @override
  void initState() {
    super.initState();
    _mounted = true;
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = (widget.delivery['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy HH:mm').format(createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.white.withOpacity(0.9),
      child: Column(
        children: [
          ListTile(
            title: Text('Delivery #${widget.deliveryId}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Created: $formattedDate'),
            trailing: widget.isActiveDelivery
                ? IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showDeliveryInfoDialog(),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pickup: ${_formatLocation(widget.delivery['pickupLocation'])}'),
                const SizedBox(height: 8),
                Text('Delivery: ${_formatLocation(widget.delivery['deliveryLocation'])}'),
                const SizedBox(height: 16),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(widget.delivery['items'] as List).map((item) => Text('- ${item['description']}')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!widget.isActiveDelivery)
                  _buildActionButton('Accept', Colors.green, () => _updateDeliveryStatus('accepted'))
                else ...[
                  _buildActionButton('Pickup', Colors.blue, () => _updateDeliveryStatus('picked_up')),
                  _buildActionButton('Delivering', Colors.orange, () => _updateDeliveryStatus('delivering')),
                  _buildActionButton('Finish', Colors.green, () => _updateDeliveryStatus('completed')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: widget.delivery['status'] == label.toLowerCase() ? null : onPressed,
      child: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        disabledBackgroundColor: Colors.grey,
      ),
    );
  }

  String _formatLocation(GeoPoint location) {
    return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
  }

  void _updateDeliveryStatus(String newStatus) async {
    if (!_mounted) return;

    if (newStatus == 'picked_up' || newStatus == 'completed') {
      final imageFile = await _takePhoto();
      if (imageFile == null) {
        if (!_mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please take a photo of the ${newStatus == 'picked_up' ? 'package' : 'delivery'}')),
        );
        return;
      }
      await _uploadPhotoAndUpdateStatus(imageFile, newStatus);
    } else {
      await _updateStatusInFirestore(newStatus);
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
        'riderId': widget.riderId,
        '${newStatus == 'picked_up' ? 'pickupPhotoUrl' : 'deliveryPhotoUrl'}': photoUrl,
      });

      if (newStatus == 'completed') {
        await FirebaseFirestore.instance.collection('riders').doc(widget.riderId).update({
          'activeDeliveryId': null,
        });
      }

      if (!_mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo uploaded and delivery status updated to $newStatus')),
      );
    } catch (e) {
      developer.log('Error updating delivery status: $e');
      if (!_mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating delivery status: $e')),
      );
    }
  }

  Future<void> _updateStatusInFirestore(String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('deliveries').doc(widget.deliveryId).update({
        'status': newStatus,
        'riderId': widget.riderId,
      });

      if (newStatus == 'accepted') {
        await FirebaseFirestore.instance.collection('riders').doc(widget.riderId).update({
          'activeDeliveryId': widget.deliveryId,
        });
      }

      if (!_mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delivery status updated to $newStatus')),
      );
    } catch (e) {
      developer.log('Error updating delivery status: $e');
      if (!_mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating delivery status: $e')),
      );
    }
  }

  void _showDeliveryInfoDialog() {
    if (!_mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Tracking ID #${widget.deliveryId}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapPreview(),
                const SizedBox(height: 16),
                const Text('ข้อมูลเบื้องต้น', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('ผู้ส่ง: ${widget.delivery['senderName'] ?? 'N/A'}'),
                Text('ผู้รับ: ${widget.delivery['recipientName']}'),
                Text('ที่อยู่รับ: ${_formatLocation(widget.delivery['deliveryLocation'])}'),
                Text('เบอร์โทร: ${widget.delivery['recipientPhone']}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateDeliveryStatus('picked_up');
                  },
                  child: const Text('รับสินค้า'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateDeliveryStatus('delivering');
                  },
                  child: const Text('กำลังส่งสินค้า'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateDeliveryStatus('completed');
                  },
                  child: const Text('ส่งสินค้าแล้ว'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapPreview() {
    // This is a placeholder for the map preview
    // You might want to implement a static map image here
    return Container(
      height: 150,
      color: Colors.grey[300],
      child: const Center(
        child: Text('Map Preview'),
      ),
    );
  }
}
