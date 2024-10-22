import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'delivery_detail_page.dart';

class DeliveryHistoryPage extends StatefulWidget {
  final String userId;

  const DeliveryHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  _DeliveryHistoryPageState createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery History'),
        backgroundColor: Colors.purple.shade400,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('deliveries')
            .where('senderId', isEqualTo: widget.userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final deliveries = snapshot.data!.docs;

          if (deliveries.isEmpty) {
            return const Center(child: Text('No deliveries found.', style: TextStyle(color: Colors.white)));
          }

          return ListView.builder(
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index].data() as Map<String, dynamic>;
              final deliveryId = deliveries[index].id;
              return DeliveryHistoryItem(delivery: delivery, deliveryId: deliveryId);
            },
          );
        },
      ),
    );
  }
}

class DeliveryHistoryItem extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final String deliveryId;

  const DeliveryHistoryItem({
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
        title: Text('To: ${delivery['recipientName'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
