import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class DeliveryItem {
  String description;
  String quantity;
  XFile? image;
  String? imageUrl;

  DeliveryItem({required this.description, required this.quantity, this.image, this.imageUrl});
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

  // Remove any methods related to location data

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
        _currentStep = 2; // Move to the next step after taking the photo
      });
    }
  }

  Future<void> _submitDelivery() async {
    if (_formKey.currentState!.validate() && _items.isNotEmpty && _allItemsImage != null) {
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
            'quantity': item.quantity,
            'imageUrl': imageUrl,
          });
        }

        // Upload the all items image
        final allItemsRef = FirebaseStorage.instance.ref().child('all_items_images/${DateTime.now().millisecondsSinceEpoch}');
        await allItemsRef.putFile(File(_allItemsImage!.path));
        final allItemsImageUrl = await allItemsRef.getDownloadURL();

        await FirebaseFirestore.instance.collection('deliveries').add({
          'senderId': widget.senderId,
          'recipientId': widget.recipientId,
          'recipientName': widget.recipientName,
          'recipientPhone': widget.recipientPhone,
          'recipientAddress': widget.recipientAddress,
          'items': itemsData,
          'allItemsImageUrl': allItemsImageUrl,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('ส่งสินค้าสำเร็จ'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: const <Widget>[
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
        // Show error dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('เกิดข้อผิดพลาด'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Icon(Icons.error, color: Colors.red, size: 64),
                    SizedBox(height: 20),
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
        child: Padding(
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
      ),
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('รายการจัดส่ง (${_items.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              minimumSize: Size(double.infinity, 50),
            ),
          ),
      ],
    );
  }

  Widget _buildAllItemsPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ถ่ายภาพสินค้าทั้งหมด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            minimumSize: Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ยืนยันการส่ง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            minimumSize: Size(double.infinity, 50),
          ),
        ),
      ],
    );
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
                CircleAvatar(
                  backgroundImage: AssetImage('assets/images/user_placeholder.png'),
                ),
                SizedBox(width: 10),
                Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 10),
            Text('ที่อยู่ผู้รับ: $address'),
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
            : Icon(Icons.image),
        title: Text(item.description),
        subtitle: Text('จำนวน: ${item.quantity}'),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
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
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _image = image;
      });
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
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'รายละเอียดสินค้า'),
            ),
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(labelText: 'จำนวน'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text('ถ่ายรูป'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo_library),
                  label: Text('เลือกรูป'),
                ),
              ],
            ),
            SizedBox(height: 10),
            if (_image != null)
              Image.file(File(_image!.path), height: 100, width: 100, fit: BoxFit.cover),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('ยกเลิก'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('เพิ่ม'),
          onPressed: () {
            if (_descriptionController.text.isNotEmpty && _quantityController.text.isNotEmpty) {
              Navigator.of(context).pop(DeliveryItem(
                description: _descriptionController.text,
                quantity: _quantityController.text,
                image: _image,
              ));
            }
          },
        ),
      ],
    );
  }
}
