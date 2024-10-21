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
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('deliveries')
            .where('senderId', isEqualTo: widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final deliveries = snapshot.data!.docs;

          if (deliveries.isEmpty) {
            return const Center(child: Text('No deliveries found.'));
          }

          // Sort the deliveries by createdAt in descending order
          deliveries.sort((a, b) {
            final aDate = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp;
            final bDate = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp;
            return bDate.compareTo(aDate);
          });

          return ListView.builder(
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index].data() as Map<String, dynamic>;
              return DeliveryHistoryItem(delivery: delivery);
            },
          );
        },
      ),
    );
  }
}

class DeliveryHistoryItem extends StatelessWidget {
  final Map<String, dynamic> delivery;

  const DeliveryHistoryItem({
    Key? key,
    required this.delivery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdAt = (delivery['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy HH:mm').format(createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text('To: ${delivery['recipientName']}'),
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
            MaterialPageRoute(builder: (context) => DeliveryDetailPage(deliveryId: delivery['id'])),
          );
        },
      ),
    );
  }
}
