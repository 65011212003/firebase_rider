import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'send_delivery_page.dart';

class SelectRecipientPage extends StatelessWidget {
  final String senderId;

  const SelectRecipientPage({Key? key, required this.senderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เบอร์โทรศัพท์ผู้รับ'),
        backgroundColor: Colors.purple.shade400,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // TODO: Implement search functionality
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(user['imageUrl'] ?? 'https://via.placeholder.com/150'),
                        ),
                        title: Text(user['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ที่อยู่ผู้รับ: ${user['address'] ?? 'Not provided'}'),
                            Text('โทรศัพท์: ${user['phone'] ?? 'Not provided'}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          child: Text('ส่งสินค้า'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SendDeliveryPage(
                                  senderId: senderId,
                                  recipientId: userId,
                                  recipientName: user['name'] ?? 'Unknown',
                                  recipientAddress: user['address'] ?? 'Not provided',
                                  recipientPhone: user['phone'] ?? 'Not provided',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
