import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'send_delivery_page.dart';

class SelectRecipientPage extends StatefulWidget {
  final String senderId;

  const SelectRecipientPage({Key? key, required this.senderId}) : super(key: key);

  @override
  _SelectRecipientPageState createState() => _SelectRecipientPageState();
}

class _SelectRecipientPageState extends State<SelectRecipientPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เบอร์โทรศัพท์ผู้รับ', style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF5300F9),
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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
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
                final filteredUsers = users.where((user) {
                  final userData = user.data() as Map<String, dynamic>;
                  final name = (userData['name'] ?? '').toLowerCase();
                  final phone = (userData['phone'] ?? '').toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index].data() as Map<String, dynamic>;
                    final userId = filteredUsers[index].id;

                    // Skip the current user
                    if (userId == widget.senderId) {
                      return const SizedBox.shrink();
                    }

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
                          child: Text('ส่งสินค้า', style: TextStyle(color: Colors.white),),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF5300F9),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SendDeliveryPage(
                                  senderId: widget.senderId,
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
