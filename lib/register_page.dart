import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_storage/firebase_storage.dart';

class RegisterPage extends StatefulWidget {
  final String? userPhone;
  final bool isRider;

  const RegisterPage({Key? key, this.userPhone, required this.isRider}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  XFile? _userImage;
  LatLng? _selectedLocation;
  String? _currentImageUrl;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.userPhone != null;
    if (_isEditMode) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(widget.isRider ? 'riders' : 'users')
          .doc(widget.userPhone)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _phoneController.text = userData['phone'] ?? '';
          _nameController.text = userData['name'] ?? '';
          _addressController.text = userData['address'] ?? '';
          _currentImageUrl = userData['imageUrl'];
          if (userData['location'] != null) {
            _selectedLocation = LatLng(
              userData['location'].latitude,
              userData['location'].longitude,
            );
          }
          if (widget.isRider) {
            _vehicleTypeController.text = userData['vehicleType'] ?? '';
            _licenseNumberController.text = userData['licenseNumber'] ?? '';
          }
        });
      }
    } catch (e) {
      developer.log('Error loading user data: $e', name: 'RegisterPage');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user data. Please try again.')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _userImage = image;
        });
      }
    } on MissingPluginException catch (e) {
      developer.log('Error picking image: $e', name: 'RegisterPage');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: const Text('Image picker plugin not available. Please check your configuration.')),
      );
    } catch (e) {
      developer.log('Error picking image: $e', name: 'RegisterPage');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image. Please try again.')),
      );
    }
  }

  Future<void> _selectLocation() async {
    try {
      final LatLng? result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MapSelectionPage()),
      );
      if (result != null) {
        setState(() {
          _selectedLocation = result;
        });
      }
    } catch (e) {
      developer.log('Error selecting location: $e', name: 'RegisterPage');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to select location. Please try again.')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate() && (_userImage != null || _currentImageUrl != null) && _selectedLocation != null) {
      try {
        String imageUrl = _currentImageUrl ?? '';
        if (_userImage != null) {
          final storageRef = FirebaseStorage.instance.ref().child('user_images/${_phoneController.text}');
          final uploadTask = storageRef.putFile(File(_userImage!.path));
          final snapshot = await uploadTask.whenComplete(() {});
          imageUrl = await snapshot.ref.getDownloadURL();
        }

        final userData = {
          'phone': _phoneController.text,
          'password': _passwordController.text,
          'name': _nameController.text,
          'address': _addressController.text,
          'imageUrl': imageUrl,
          'location': GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        };

        if (widget.isRider) {
          userData['vehicleType'] = _vehicleTypeController.text;
          userData['licenseNumber'] = _licenseNumberController.text;
        }

        await FirebaseFirestore.instance
            .collection(widget.isRider ? 'riders' : 'users')
            .doc(_phoneController.text)
            .set(userData, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        developer.log('Error saving profile: $e', name: 'RegisterPage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Profile' : 'Register ${widget.isRider ? 'Rider' : 'User'}'),
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
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Choose Image Source'),
                            content: SingleChildScrollView(
                              child: ListBody(
                                children: <Widget>[
                                  GestureDetector(
                                    child: const Text('Camera'),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _pickImage(ImageSource.camera);
                                    },
                                  ),
                                  const Padding(padding: EdgeInsets.all(8.0)),
                                  GestureDetector(
                                    child: const Text('Gallery'),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _pickImage(ImageSource.gallery);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _userImage != null
                          ? Image.file(File(_userImage!.path), fit: BoxFit.cover)
                          : (_currentImageUrl != null
                              ? Image.network(_currentImageUrl!, fit: BoxFit.cover)
                              : const Icon(Icons.add_a_photo, size: 50, color: Colors.purple)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(_phoneController, 'Phone Number', enabled: !_isEditMode),
                  _buildTextField(_passwordController, 'Password', isPassword: true),
                  _buildTextField(_nameController, 'Name'),
                  _buildTextField(_addressController, 'Address'),
                  if (widget.isRider) ...[
                    _buildTextField(_vehicleTypeController, 'Vehicle Type'),
                    _buildTextField(_licenseNumberController, 'License Number'),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _selectLocation,
                    child: Text(_selectedLocation != null ? 'Change Location' : 'Select Location'),
                    style: _buttonStyle(),
                  ),
                  if (_selectedLocation != null)
                    Text(
                      'Selected Location: ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    child: Text(_isEditMode ? 'Save Changes' : 'Register'),
                    style: _buttonStyle(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool enabled = true, bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        enabled: enabled,
        obscureText: isPassword,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your $label';
          }
          return null;
        },
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      foregroundColor: Colors.purple,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class MapSelectionPage extends StatefulWidget {
  const MapSelectionPage({Key? key}) : super(key: key);

  @override
  _MapSelectionPageState createState() => _MapSelectionPageState();
}

class _MapSelectionPageState extends State<MapSelectionPage> {
  LatLng? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: const LatLng(13.7563, 100.5018), // Bangkok coordinates
          initialZoom: 10.0,
          onTap: (tapPosition, point) {
            setState(() {
              _selectedLocation = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: _selectedLocation != null
                ? [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _selectedLocation!,
                      child: const Icon(Icons.location_pin, color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context, _selectedLocation);
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}
