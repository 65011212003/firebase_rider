import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'delivery_detail_page.dart';

class ReceiveDeliveryPage extends StatefulWidget {
  final String userId;
  final String userName;

  const ReceiveDeliveryPage({Key? key, required this.userId, required this.userName}) : super(key: key);

  @override
  _ReceiveDeliveryPageState createState() => _ReceiveDeliveryPageState();
}

class _ReceiveDeliveryPageState extends State<ReceiveDeliveryPage> {
  late Stream<QuerySnapshot> _deliveriesStream;

  @override
  void initState() {
    super.initState();
    _deliveriesStream = FirebaseFirestore.instance
        .collection('deliveries')
        .where('recipientId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Incoming Deliveries'),
        backgroundColor: Colors.purple.shade400,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _deliveriesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final deliveries = snapshot.data!.docs;

          if (deliveries.isEmpty) {
            return const Center(child: Text('No incoming deliveries found.'));
          }

          return ListView.builder(
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index].data() as Map<String, dynamic>;
              final deliveryId = deliveries[index].id;
              return IncomingDeliveryItem(
                delivery: delivery,
                deliveryId: deliveryId,
                recipientName: widget.userName,
              );
            },
          );
        },
      ),
    );
  }
}

class IncomingDeliveryItem extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final String deliveryId;
  final String recipientName;

  const IncomingDeliveryItem({
    Key? key,
    required this.delivery,
    required this.deliveryId,
    required this.recipientName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdAt = (delivery['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy HH:mm').format(createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text('From: ${delivery['senderName'] ?? 'Unknown Sender'}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${delivery['status']}'),
            Text('Date: $formattedDate'),
            Text('Items: ${(delivery['items'] as List).length}'),
            Text('To: $recipientName'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryDetailPage(deliveryId: deliveryId),
            ),
          );
        },
      ),
    );
  }
}
