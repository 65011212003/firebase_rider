import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// ignore: unused_import
import 'location_service.dart';

class DeliveryItem {
  String description;
  String quantity;
  XFile? image;
  String? imageUrl;
  String status; // Add status field
  LatLng? riderLocation; // Add rider location
  String? riderId; // Add rider ID

  DeliveryItem({
    required this.description, 
    required this.quantity, 
    this.image, 
    this.imageUrl,
    this.status = 'pending',
    this.riderLocation,
    this.riderId,
  });
}

class SendDeliveryPage extends StatefulWidget {
  final String senderId;
  final String recipientId;
  final String recipientName;
  final String recipientAddress;
  final String recipientPhone;

  const SendDeliveryPage({
    Key? key,
    required this.senderId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAddress,
    required this.recipientPhone,
  }) : super(key: key);

  @override
  _SendDeliveryPageState createState() => _SendDeliveryPageState();
}

class _SendDeliveryPageState extends State<SendDeliveryPage> {
  final _formKey = GlobalKey<FormState>();
  List<DeliveryItem> _items = [];
  XFile? _allItemsImage;
  int _currentStep = 0;
  StreamSubscription<QuerySnapshot>? _deliverySubscription;
  Map<String, LatLng> _riderLocations = {};

  @override
  void initState() {
    super.initState();
    _setupDeliveryListener();
  }

  void _setupDeliveryListener() {
    _deliverySubscription = FirebaseFirestore.instance
        .collection('deliveries')
        .where('senderId', isEqualTo: widget.senderId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final delivery = change.doc.data() as Map<String, dynamic>;
        if (delivery['riderLocation'] != null) {
          final GeoPoint location = delivery['riderLocation'];
          setState(() {
            _riderLocations[change.doc.id] = LatLng(
              location.latitude,
              location.longitude,
            );
          });
        }
      }
    });
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

  Future<void> _takeAllItemsPhoto() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _allItemsImage = image;
        _currentStep = 2;
      });
    }
  }

  Future<void> _submitDelivery() async {
    if (_formKey.currentState!.validate() && _items.isNotEmpty && _allItemsImage != null) {
      try {
        // Get sender location from users collection
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.senderId)
            .get();
        
        // Get recipient location from users collection  
        final recipientDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.recipientId)
            .get();

        if (!senderDoc.exists || !recipientDoc.exists) {
          throw Exception('Sender or recipient location not found');
        }

        final senderData = senderDoc.data() as Map<String, dynamic>;
        final recipientData = recipientDoc.data() as Map<String, dynamic>;

        // Get locations from user data
        final senderLocation = senderData['location'] as GeoPoint?;
        final recipientLocation = recipientData['location'] as GeoPoint?;

        if (senderLocation == null || recipientLocation == null) {
          throw Exception('Sender or recipient location not set');
        }

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
            'quantity': item.quantity,
            'imageUrl': imageUrl,
          });
        }

        final allItemsRef = FirebaseStorage.instance.ref().child('all_items_images/${DateTime.now().millisecondsSinceEpoch}');
        await allItemsRef.putFile(File(_allItemsImage!.path));
        final allItemsImageUrl = await allItemsRef.getDownloadURL();

        final deliveryRef = await FirebaseFirestore.instance.collection('deliveries').add({
          'senderId': widget.senderId,
          'senderName': senderData['name'],
          'senderPhone': senderData['phone'],
          'senderAddress': senderData['address'],
          'pickupLocation': senderLocation,  // Add pickup location
          'recipientId': widget.recipientId,
          'recipientName': widget.recipientName,
          'recipientPhone': widget.recipientPhone,
          'recipientAddress': widget.recipientAddress,
          'deliveryLocation': recipientLocation,  // Add delivery location
          'items': itemsData,
          'allItemsImageUrl': allItemsImageUrl,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'riderLocation': null,
          'riderId': null,
        });

        // Setup real-time listener for this delivery
        deliveryRef.snapshots().listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            if (data['riderLocation'] != null) {
              final GeoPoint location = data['riderLocation'];
              setState(() {
                _riderLocations[snapshot.id] = LatLng(
                  location.latitude,
                  location.longitude,
                );
              });
            }
          }
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('ส่งสินค้าสำเร็จ'),
              content: const SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Icon(Icons.check_circle, color: Colors.green, size: 64),
                    SizedBox(height: 20),
                    Text('คำขอจัด่งของคุณได้รับการยืนยันเรียบร้อยแล้ว'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('กลับหน้าหลัก'),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            );
          },
        );
      } catch (e) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('เกิดข้อผิดพลาด'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 20),
                    Text('เกิดข้อผิดพลาดในการส่งคำขอจัดส่ง: $e'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('ตกลง'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วนและถ่ายภาพสินค้าทั้งหมด')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อมูลการจัดส่งสินค้า'),
        backgroundColor: Colors.purple.shade400,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Existing form and delivery progress
            if (_riderLocations.isNotEmpty) _buildRidersMap(),
            // Rest of the existing UI
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RecipientInfoCard(
                      name: widget.recipientName,
                      address: widget.recipientAddress,
                      phone: widget.recipientPhone,
                    ),
                    const SizedBox(height: 20),
                    DeliveryProgressIndicator(currentStep: _currentStep),
                    const SizedBox(height: 20),
                    if (_currentStep == 0) _buildItemsList(),
                    if (_currentStep == 1) _buildAllItemsPhotoStep(),
                    if (_currentStep == 2) _buildConfirmationStep(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('รายการจัดส่ง (${_items.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return DeliveryItemCard(
              item: item,
              onDelete: () {
                setState(() {
                  _items.removeAt(index);
                });
              },
            );
          },
        ),
        ElevatedButton(
          onPressed: _addItem,
          child: const Text('+ เพิ่ม'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        if (_items.isNotEmpty)
          ElevatedButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text('ถัดไป'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
      ],
    );
  }

  Widget _buildAllItemsPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ถ่ายภาพสินค้าทั้งหมด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        if (_allItemsImage != null)
          Image.file(File(_allItemsImage!.path), height: 200, width: double.infinity, fit: BoxFit.cover)
        else
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey[300],
            child: Icon(Icons.camera_alt, size: 50, color: Colors.grey[600]),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _takeAllItemsPhoto,
          child: Text(_allItemsImage == null ? 'ถ่ายภาพ' : 'ถ่ายภาพใหม่'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ยืนยันการส่ง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Text('จำนวนรายการ: ${_items.length}'),
        const SizedBox(height: 10),
        Text('ผู้รับ: ${widget.recipientName}'),
        const SizedBox(height: 10),
        Text('ที่อยู่: ${widget.recipientAddress}'),
        const SizedBox(height: 20),
        if (_allItemsImage != null)
          Image.file(File(_allItemsImage!.path), height: 200, width: double.infinity, fit: BoxFit.cover),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _submitDelivery,
          child: const Text('ยืนยันการส่ง'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildRidersMap() {
    if (_riderLocations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 300,
      child: FlutterMap(
        options: MapOptions(
          center: _riderLocations.values.first, // Changed from initialCenter
          zoom: 13, // Changed from initialZoom
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: _riderLocations.entries.map((entry) {
              return Marker(
                width: 40,
                height: 40,
                point: entry.value,
                child: const Icon(
                  Icons.delivery_dining,
                  color: Colors.red,
                  size: 40,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _deliverySubscription?.cancel();
    super.dispose();
  }
}

class RecipientInfoCard extends StatelessWidget {
  final String name;
  final String address;
  final String phone;

  const RecipientInfoCard({
    Key? key,
    required this.name,
    required this.address,
    required this.phone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundImage: AssetImage('assets/images/user_placeholder.png'),
                ),
                const SizedBox(width: 10),
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text('ท��่อยู่ผู้รับ: $address'),
            Text('โทรศัพท์: $phone'),
          ],
        ),
      ),
    );
  }
}

class DeliveryProgressIndicator extends StatelessWidget {
  final int currentStep;

  const DeliveryProgressIndicator({Key? key, required this.currentStep}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildProgressItem(Icons.list, 'รายการส่ง', currentStep >= 0),
        _buildProgressItem(Icons.camera_alt, 'ภาพประกอบสินค้า', currentStep >= 1),
        _buildProgressItem(Icons.check_circle, 'ยืนยัน', currentStep >= 2),
      ],
    );
  }

  Widget _buildProgressItem(IconData icon, String label, bool isActive) {
    return Column(
      children: [
        Icon(icon, color: isActive ? Colors.purple : Colors.grey),
        Text(label, style: TextStyle(color: isActive ? Colors.purple : Colors.grey)),
      ],
    );
  }
}

class DeliveryItemCard extends StatelessWidget {
  final DeliveryItem item;
  final VoidCallback onDelete;

  const DeliveryItemCard({
    Key? key,
    required this.item,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: item.image != null
            ? Image.file(File(item.image!.path), width: 50, height: 50, fit: BoxFit.cover)
            : const Icon(Icons.image),
        title: Text(item.description),
        subtitle: Text('จำนวน: ${item.quantity}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
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
  final _quantityController = TextEditingController();
  XFile? _image;

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request camera permission
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status.isDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required')),
          );
          return;
        }
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85, // Add image quality compression
        maxWidth: 1024,   // Limit max width
        maxHeight: 1024,  // Limit max height
      );
      
      if (image != null) {
        setState(() {
          _image = image;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มสินค้า'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, color: Colors.purple),
                          label: const Text('เลือกรูป', style: TextStyle(color: Colors.purple)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.purple),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, color: Colors.purple),
                          label: const Text('ถ่ายรูป', style: TextStyle(color: Colors.purple)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.purple),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_image!.path),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'รายละเอียดสินค้า',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'จำนวน',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            if (_descriptionController.text.isNotEmpty && _quantityController.text.isNotEmpty) {
              Navigator.of(context).pop(DeliveryItem(
                description: _descriptionController.text,
                quantity: _quantityController.text,
                image: _image,
              ));
            }
          },
          child: const Text('เพิ่ม', style: TextStyle(color: Colors.purple)),
        ),
      ],
    );
  }
}
