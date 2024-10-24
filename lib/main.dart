import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'login_page.dart';
import 'firebase_options.dart';
import 'register_page.dart';
import 'delivery_history_page.dart';
import 'receive_delivery_page.dart';
import 'select_recipient_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'good2go',
      theme: ThemeData(
        primarySwatch: MaterialColor(0xFF5300F9, {
          50: Color(0xFFEDE7FF),
          100: Color(0xFFD1C4FF),
          200: Color(0xFFB39DFF),
          300: Color(0xFF9575FF),
          400: Color(0xFF7E57FF),
          500: Color(0xFF5300F9),
          600: Color(0xFF4A00E5),
          700: Color(0xFF4200D1),
          800: Color(0xFF3900BD),
          900: Color(0xFF2E0099),
        }),
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.itimTextTheme(),
      ),
      home: const LoginPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String phone;
  final bool isRider;

  const MyHomePage({super.key, required this.phone, required this.isRider});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<DocumentSnapshot> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUserData();
  }

  Future<DocumentSnapshot> _fetchUserData() async {
    final collection = widget.isRider ? 'riders' : 'users';
    return FirebaseFirestore.instance
        .collection(collection)
        .doc(widget.phone)
        .get();
  }

  void _editProfile() {
    // Navigate to edit profile page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterPage(
          userPhone: widget.phone,
          isRider: widget.isRider,
        ),
      ),
    ).then((_) {
      // Refresh user data after returning from edit profile
      setState(() {
        _userFuture = _fetchUserData();
      });
    });
  }

  void _signOut() {
    // Implement sign out logic here
    // For now, we'll just navigate back to the login page
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  void _navigateToSendDelivery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectRecipientPage(senderId: widget.phone),
      ),
    );
  }

  void _navigateToReceiveDelivery() async {
    try {
      final userSnapshot = await _userFuture;
      final userData = userSnapshot.data() as Map<String, dynamic>?;
      final userName = userData?['name'] ?? 'User';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiveDeliveryPage(
            userId: widget.phone,
            userName: userName,
            key: ValueKey(widget.phone), // Add this line
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to Receive Delivery: $e');
      // You might want to show an error message to the user here
    }
  }

  void _navigateToDeliveryHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryHistoryPage(userId: widget.phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('good2go', style: GoogleFonts.lobster(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.grey[200],
              child: Icon(Icons.person, color: Colors.black),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _editProfile();
              } else if (value == 'signout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Text('Edit Profile', style: GoogleFonts.itim()),
              ),
              PopupMenuItem<String>(
                value: 'signout',
                child: Text('Sign Out', style: GoogleFonts.itim()),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: GoogleFonts.itim()));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
                child: Text('User data not found', style: GoogleFonts.itim()));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final userName = userData['name'] ?? 'User';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $userName!',
                    style: GoogleFonts.itim(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Order your favourite food!',
                    style: GoogleFonts.itim(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  DeliveryBanner(),
                  const SizedBox(height: 24),
                  Text(
                    'Menus',
                    style: GoogleFonts.itim(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Start of Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMenuButton(
                        context,
                        Icons.local_shipping,
                        'Send',
                        Color(0xFF5300F9),
                        _navigateToSendDelivery,
                      ),
                      _buildMenuButton(
                        context,
                        Icons.history_rounded,
                        'Sent and Received',
                        Colors.indigo,
                        _navigateToDeliveryHistory,
                      ),
                      _buildMenuButton(
                        context,
                        Icons.map,
                        'Map',
                        Colors.green,
                        _navigateToMap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.itim(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapPage(phone: widget.phone)),
    );
  }
}

class MapPage extends StatelessWidget {
  final String phone;

  MapPage({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Map (Pending)', style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF5300F9),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('deliveries')
            .where('status', isEqualTo: 'pending')
            .where('senderId', isEqualTo: phone) // Use the passed phone parameter
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No pending deliveries found.'));
          }

          final deliveries = snapshot.data!.docs;

          return FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(13.7563, 100.5018), // Centered around Bangkok
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: deliveries.map((delivery) {
                  final data = delivery.data() as Map<String, dynamic>;
                  final pickupLocation = data['pickupLocation'];
                  if (pickupLocation is GeoPoint) {
                    return Marker(
                      width: 80.0,
                      height: 80.0,
                      point: LatLng(pickupLocation.latitude, pickupLocation.longitude),
                      child: Icon(Icons.location_on, color: Colors.red, size: 40),
                    );
                  } else {
                    return Marker(
                      width: 80.0,
                      height: 80.0,
                      point: LatLng(0, 0), // Default location in case of error
                      child: Icon(Icons.error, color: Colors.red, size: 40),
                    );
                  }
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DeliveryBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/banner.png',
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }
}
