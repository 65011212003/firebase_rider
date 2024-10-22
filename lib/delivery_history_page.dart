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

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery History'),
        backgroundColor: Colors.purple.shade400,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sent'),
            Tab(text: 'Received'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Sent deliveries
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('deliveries')
                .where('senderId', isEqualTo: widget.userId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final deliveries = snapshot.data!.docs;

              if (deliveries.isEmpty) {
                return const Center(child: Text('No sent deliveries found.'));
              }

              return ListView.builder(
                itemCount: deliveries.length,
                itemBuilder: (context, index) {
                  final delivery = deliveries[index].data() as Map<String, dynamic>;
                  final deliveryId = deliveries[index].id;
                  return DeliveryHistoryItem(
                    delivery: delivery,
                    deliveryId: deliveryId,
                    isSender: true,
                  );
                },
              );
            },
          ),
          // Received deliveries
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('deliveries')
                .where('recipientId', isEqualTo: widget.userId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final deliveries = snapshot.data!.docs;

              if (deliveries.isEmpty) {
                return const Center(child: Text('No received deliveries found.'));
              }

              return ListView.builder(
                itemCount: deliveries.length,
                itemBuilder: (context, index) {
                  final delivery = deliveries[index].data() as Map<String, dynamic>;
                  final deliveryId = deliveries[index].id;
                  return DeliveryHistoryItem(
                    delivery: delivery,
                    deliveryId: deliveryId,
                    isSender: false,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class DeliveryHistoryItem extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final String deliveryId;
  final bool isSender;

  const DeliveryHistoryItem({
    Key? key,
    required this.delivery,
    required this.deliveryId,
    required this.isSender,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdAt = (delivery['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy HH:mm').format(createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(isSender ? delivery['recipientId'] : delivery['senderId'])
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text('${isSender ? "To" : "From"}: Unknown');
            }
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            return Text(
              '${isSender ? "To" : "From"}: ${userData['name'] ?? 'Unknown'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
          },
        ),
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
            MaterialPageRoute(
              builder: (context) => DeliveryDetailPage(deliveryId: deliveryId),
            ),
          );
        },
      ),
    );
  }
}
