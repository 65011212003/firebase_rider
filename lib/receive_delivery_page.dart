import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'delivery_detail_page.dart';

class ReceiveDeliveryPage extends StatelessWidget {
  final String userId;

  const ReceiveDeliveryPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Delivery'),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('deliveries')
              .where('recipientId', isEqualTo: userId)
              .where('status', whereIn: ['pending', 'accepted', 'picked_up', 'delivering'])
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final deliveries = snapshot.data!.docs;

            if (deliveries.isEmpty) {
              return const Center(child: Text('No incoming deliveries found.', style: TextStyle(color: Colors.white)));
            }

            return ListView.builder(
              itemCount: deliveries.length,
              itemBuilder: (context, index) {
                final delivery = deliveries[index].data() as Map<String, dynamic>;
                final deliveryId = deliveries[index].id;
                return IncomingDeliveryItem(delivery: delivery, deliveryId: deliveryId);
              },
            );
          },
        ),
      ),
    );
  }
}

class IncomingDeliveryItem extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final String deliveryId;

  const IncomingDeliveryItem({
    Key? key,
    required this.delivery,
    required this.deliveryId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdAt = (delivery['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy HH:mm').format(createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.white.withOpacity(0.9),
      child: ListTile(
        title: Text('From: ${delivery['senderName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${delivery['status']}'),
            Text('Date: $formattedDate'),
            Text('Items: ${(delivery['items'] as List).length}'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DeliveryDetailPage(deliveryId: deliveryId)),
          );
        },
      ),
    );
  }
}
