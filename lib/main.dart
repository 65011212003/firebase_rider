import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'firebase_options.dart';
import 'register_page.dart';
import 'send_delivery_page.dart';
import 'delivery_history_page.dart';
import 'rider_home_page.dart';

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
      title: 'Firebase Firestore Demo',
      theme: _buildAppTheme(),
      home: const LoginPage(),
    );
  }

  ThemeData _buildAppTheme() {
    final ThemeData base = ThemeData.light();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: Colors.purple,
        secondary: Colors.purpleAccent,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.purple,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      scaffoldBackgroundColor: Colors.purple[50],
    );
  }

  TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      headlineSmall: base.headlineSmall!.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.purple[800],
      ),
      bodyLarge: base.bodyLarge!.copyWith(
        fontSize: 16,
        color: Colors.black87,
      ),
      bodyMedium: base.bodyMedium!.copyWith(
        fontSize: 14,
        color: Colors.black54,
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.phone, required this.isRider});

  final String phone;
  final bool isRider;

  @override
  Widget build(BuildContext context) {
    if (isRider) {
      return RiderHomePage(riderId: phone);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('User Profile'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade200, Colors.purple.shade400],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection(isRider ? 'riders' : 'users')
              .doc(phone)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>?;

            if (userData == null) {
              return const Center(child: Text('User data not found', style: TextStyle(color: Colors.white)));
            }

            return SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (userData['imageUrl'] != null)
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(userData['imageUrl']),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome, ${userData['name'] ?? phone}!',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      _buildInfoText(context, 'Phone', userData['phone'] ?? 'N/A'),
                      _buildInfoText(context, 'Address', userData['address'] ?? 'N/A'),
                      if (userData['location'] != null)
                        _buildInfoText(context, 'Location', '${userData['location'].latitude}, ${userData['location'].longitude}'),
                      if (isRider) ...[
                        _buildInfoText(context, 'Vehicle Type', userData['vehicleType'] ?? 'N/A'),
                        _buildInfoText(context, 'License Number', userData['licenseNumber'] ?? 'N/A'),
                      ],
                      const SizedBox(height: 20),
                      if (!isRider) ...[
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SendDeliveryPage(userId: phone)),
                            );
                          },
                          child: const Text('Send Delivery'),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => DeliveryHistoryPage(userId: phone)),
                            );
                          },
                          child: const Text('Delivery History'),
                        ),
                        const SizedBox(height: 20),
                      ],
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                        child: const Text('Sign Out'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RegisterPage(userPhone: phone, isRider: isRider)),
                          );
                        },
                        child: const Text('Edit Profile'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoText(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
