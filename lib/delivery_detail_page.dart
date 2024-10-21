import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DeliveryDetailPage extends StatelessWidget {
  final Map<String, dynamic> delivery;

  const DeliveryDetailPage({Key? key, required this.delivery}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdAt = (delivery['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy HH:mm').format(createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recipient: ${delivery['recipientName']}', style: Theme.of(context).textTheme.titleLarge),
              Text('Phone: ${delivery['recipientPhone']}'),
              Text('Status: ${delivery['status']}'),
              Text('Date: $formattedDate'),
              const SizedBox(height: 20),
              Text('Items:', style: Theme.of(context).textTheme.titleLarge),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (delivery['items'] as List).length,
                itemBuilder: (context, index) {
                  final item = delivery['items'][index];
                  return ListTile(
                    title: Text(item['description']),
                    leading: item['imageUrl'] != null
                        ? Image.network(item['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.image),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Locations:', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(
                height: 300,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      (delivery['pickupLocation'].latitude + delivery['deliveryLocation'].latitude) / 2,
                      (delivery['pickupLocation'].longitude + delivery['deliveryLocation'].longitude) / 2,
                    ),
                    initialZoom: 12,
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
                          point: LatLng(delivery['pickupLocation'].latitude, delivery['pickupLocation'].longitude),
                          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                        ),
                        Marker(
                          width: 40.0,
                          height: 40.0,
                          point: LatLng(delivery['deliveryLocation'].latitude, delivery['deliveryLocation'].longitude),
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
