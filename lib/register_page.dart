import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_storage/firebase_storage.dart';
import 'location_service.dart';

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
  final _confirmPasswordController = TextEditingController();
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
        const SnackBar(content: Text('Image picker plugin not available. Please check your configuration.')),
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

  Future<bool> _isPhoneNumberUnique(String phoneNumber) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(widget.isRider ? 'riders' : 'users')
          .doc(phoneNumber)
          .get();
      return !userDoc.exists;
    } catch (e) {
      developer.log('Error checking phone number: $e', name: 'RegisterPage');
      return false;
    }
  }

  Future<void> _getLocationFromAddress() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an address first')),
      );
      return;
    }

    try {
      final location = await LocationService.getCoordinatesFromAddress(_addressController.text);
      if (location != null) {
        setState(() {
          _selectedLocation = location;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find location for this address')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error getting location from address')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields correctly')),
      );
      return;
    }

    // Check for unique phone number only in non-edit mode
    if (!_isEditMode) {
      final isUnique = await _isPhoneNumberUnique(_phoneController.text);
      if (!isUnique) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This phone number is already registered')),
        );
        return;
      }
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_userImage == null && _currentImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a profile image')),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your location')),
      );
      return;
    }

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
                  _buildTextField(_confirmPasswordController, 'Confirm Password', 
                    isPassword: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  _buildTextField(_nameController, 'Name'),
                  _buildTextField(_addressController, 'Address'),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _getLocationFromAddress,
                          child: const Text('Get Location from Address'),
                          style: _buttonStyle(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectLocation,
                          child: const Text('Select on Map'),
                          style: _buttonStyle(),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedLocation != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      height: 200,
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
                            center: _selectedLocation!,
                            zoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: _selectedLocation!,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selected Location: ${_selectedLocation!.latitude.toStringAsFixed(4)}, '
                      '${_selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                  if (widget.isRider) ...[
                    _buildTextField(_vehicleTypeController, 'Vehicle Type'),
                    _buildTextField(_licenseNumberController, 'License Number'),
                  ],
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

  Widget _buildTextField(
    TextEditingController controller, 
    String label, {
    bool enabled = true, 
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
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
          errorStyle: const TextStyle(color: Colors.white),
        ),
        enabled: enabled,
        obscureText: isPassword,
        validator: validator ?? (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your $label';
          }
          if (label == 'Phone Number' && !RegExp(r'^\d{10}$').hasMatch(value)) {
            return 'Please enter a valid 10-digit phone number';
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
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: const LatLng(13.7563, 100.5018), // Bangkok coordinates
          zoom: 10.0,
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
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                      ),
                    ),
                  ]
                : [],
          ),
        ],
      ),
      floatingActionButton: Container(
        padding: const EdgeInsets.only(left: 30.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: 'currentLocationButton',
              onPressed: () async {
                final location = await LocationService().getCurrentLocation();
                final currentLocation = LatLng(location.latitude, location.longitude);
                setState(() {
                  _selectedLocation = currentLocation;
                });
                _mapController.move(currentLocation, 15.0);
              },
              child: const Icon(Icons.my_location),
            ),
            FloatingActionButton(
              heroTag: 'confirmLocationButton',
              onPressed: () {
                Navigator.pop(context, _selectedLocation);
              },
              child: const Icon(Icons.check),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
