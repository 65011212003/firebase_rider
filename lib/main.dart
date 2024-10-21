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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(isRider ? 'riders' : 'users')
            .doc(phone)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;

          if (userData == null) {
            return const Center(child: Text('User data not found'));
          }

          return Center(
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
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                Text('Phone: ${userData['phone'] ?? 'N/A'}'),
                Text('Address: ${userData['address'] ?? 'N/A'}'),
                if (userData['location'] != null)
                  Text('Location: ${userData['location'].latitude}, ${userData['location'].longitude}'),
                if (isRider) ...[
                  Text('Vehicle Type: ${userData['vehicleType'] ?? 'N/A'}'),
                  Text('License Number: ${userData['licenseNumber'] ?? 'N/A'}'),
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
          );
        },
      ),
    );
  }
}
