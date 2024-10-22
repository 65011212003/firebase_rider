import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math';

class DeliveryItem {
  String description;
  XFile? image;
  String? imageUrl;

  DeliveryItem({required this.description, this.image, this.imageUrl});
}

class SendDeliveryPage extends StatefulWidget {
  final String userId;

  const SendDeliveryPage({Key? key, required this.userId}) : super(key: key);

  @override
  _SendDeliveryPageState createState() => _SendDeliveryPageState();
}

class _SendDeliveryPageState extends State<SendDeliveryPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedRecipientId;
  String? _selectedRecipientName;
  String? _selectedRecipientPhone;
  LatLng? _pickupLocation;
  LatLng? _deliveryLocation;
  List<DeliveryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadSenderLocation();
  }

  Future<void> _loadSenderLocation() async {
    try {
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (senderDoc.exists) {
        final senderData = senderDoc.data() as Map<String, dynamic>;
        if (senderData['location'] != null) {
          setState(() {
            _pickupLocation = LatLng(
              senderData['location'].latitude,
              senderData['location'].longitude,
            );
          });
        }
      }
    } catch (e) {
      print('Error loading sender location: $e');
    }
  }

  Future<void> _selectRecipient() async {
    final recipient = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserListPage(currentUserId: widget.userId)),
    );
    if (recipient != null) {
      setState(() {
        _selectedRecipientId = recipient['id'];
        _selectedRecipientName = recipient['name'];
        _selectedRecipientPhone = recipient['phone'];
        _deliveryLocation = LatLng(
          recipient['location'].latitude,
          recipient['location'].longitude,
        );
      });
    }
  }

  Future<void> _addItem() async {
    final item = await showDialog<DeliveryItem>(
      context: context,
      builder: (BuildContext context) => AddItemDialog(),
    );
    if (item != null) {
      setState(() {
        _items.add(item);
      });
    }
  }

  Future<void> _submitDelivery() async {
    if (_formKey.currentState!.validate() && _selectedRecipientId != null && _pickupLocation != null && _deliveryLocation != null && _items.isNotEmpty) {
      try {
        List<Map<String, dynamic>> itemsData = [];
        for (var item in _items) {
          String? imageUrl;
          if (item.image != null) {
            final ref = FirebaseStorage.instance.ref().child('delivery_images/${DateTime.now().millisecondsSinceEpoch}');
            await ref.putFile(File(item.image!.path));
            imageUrl = await ref.getDownloadURL();
          }
          itemsData.add({
            'description': item.description,
            'imageUrl': imageUrl,
          });
        }

        await FirebaseFirestore.instance.collection('deliveries').add({
          'senderId': widget.userId,
          'recipientId': _selectedRecipientId,
          'recipientName': _selectedRecipientName,
          'recipientPhone': _selectedRecipientPhone,
          'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
          'deliveryLocation': GeoPoint(_deliveryLocation!.latitude, _deliveryLocation!.longitude),
          'items': itemsData,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Success'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: const <Widget>[
                    Icon(Icons.check_circle, color: Colors.green, size: 64),
                    SizedBox(height: 20),
                    Text('Delivery request submitted successfully'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Go Back'),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            );
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting delivery request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Delivery'),
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _selectRecipient,
                    child: Text(_selectedRecipientName != null ? 'Change Recipient' : 'Select Recipient'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (_selectedRecipientName != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recipient: $_selectedRecipientName', style: const TextStyle(color: Colors.white)),
                        Text('Phone: $_selectedRecipientPhone', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  const SizedBox(height: 20),
                  if (_pickupLocation != null && _deliveryLocation != null)
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LocationMapWidget(
                          pickupLocation: _pickupLocation!,
                          deliveryLocation: _deliveryLocation!,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text('Items:', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: item.image != null
                              ? Image.file(File(item.image!.path), width: 50, height: 50, fit: BoxFit.cover)
                              : const Icon(Icons.image),
                          title: Text(item.description),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _items.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  ElevatedButton(
                    onPressed: _addItem,
                    child: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitDelivery,
                    child: const Text('Submit Delivery Request'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserListPage extends StatelessWidget {
  final String currentUserId;

  const UserListPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Recipient')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          // Filter out the current user
          final otherUsers = users.where((user) => user.id != currentUserId).toList();

          if (otherUsers.isEmpty) {
            return const Center(child: Text('No other users found.'));
          }

          return ListView.builder(
            itemCount: otherUsers.length,
            itemBuilder: (context, index) {
              final user = otherUsers[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(user['name'] ?? 'Unknown'),
                subtitle: Text(user['phone'] ?? 'No phone'),
                onTap: () {
                  Navigator.pop(context, {
                    'id': otherUsers[index].id,
                    'name': user['name'],
                    'phone': user['phone'],
                    'location': user['location'],
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}

class AddItemDialog extends StatefulWidget {
  @override
  _AddItemDialogState createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _descriptionController = TextEditingController();
  XFile? _image;

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _image = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Item Description'),
            ),
            const SizedBox(height: 10),
            if (_image != null)
              Image.file(File(_image!.path), height: 100, width: 100, fit: BoxFit.cover)
            else
              const Icon(Icons.image, size: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.camera),
                  child: const Text('Take Photo'),
                ),
                ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  child: const Text('Choose Photo'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_descriptionController.text.isNotEmpty) {
              Navigator.of(context).pop(DeliveryItem(
                description: _descriptionController.text,
                image: _image,
              ));
            }
          },
          child: const Text('Add'),
        ),
      ],
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
          MarkerLayer(
            markers: [
              Marker(
                width: 40.0,
                height: 40.0,
                point: pickupLocation,
                child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
              ),
              Marker(
                width: 40.0,
                height: 40.0,
                point: deliveryLocation,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // in meters
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double lon1 = point1.longitude * pi / 180;
    final double lon2 = point2.longitude * pi / 180;

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double calculateZoomLevel(double distance) {
    if (distance < 1000) return 14;
    if (distance < 5000) return 12;
    if (distance < 10000) return 11;
    if (distance < 50000) return 9;
    return 8;
  }
}
