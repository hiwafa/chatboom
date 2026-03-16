import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _searchQuery = ''; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. The Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase(); 
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: -0.2),
          
          const SizedBox(height: 8),

          // 2. The Filtered User List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').limit(100).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading users', style: TextStyle(color: Colors.white54)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                }

                final users = snapshot.data!.docs;
                
                final filteredUsers = users.where((doc) {
                  if (doc.id == currentUser?.uid) return false;

                  final userData = doc.data() as Map<String, dynamic>;
                  final name = (userData['name'] ?? '').toString().toLowerCase();
                  final email = (userData['email'] ?? '').toString().toLowerCase();

                  if (_searchQuery.isEmpty) return true;
                  return name.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(child: Text('No users found.', style: TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Padding so the FAB doesn't cover the last item
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final userData = filteredUsers[index].data() as Map<String, dynamic>;
                    final isAgentEnabled = userData['agentEnabled'] ?? false;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(0.2), 
                          backgroundImage: (userData['avatar'] != null && userData['avatar'].toString().isNotEmpty)
                              ? NetworkImage(userData['avatar'])
                              : null,
                          child: (userData['avatar'] == null || userData['avatar'].toString().isEmpty)
                              ? Text(userData['name'][0].toUpperCase(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        title: Text(
                          userData['name'] ?? 'Unknown User',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(userData['email'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  isAgentEnabled ? Icons.smart_toy : Icons.chat_bubble_outline,
                                  size: 14,
                                  color: isAgentEnabled ? Colors.blueAccent : Colors.white38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAgentEnabled ? 'AI Agent Active' : 'Available for text',
                                  style: TextStyle(
                                    color: isAgentEnabled ? Colors.blueAccent : Colors.white38,
                                    fontWeight: isAgentEnabled ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                receiverID: userData['userID'],
                                receiverName: userData['name'],
                                isReceiverAgentEnabled: isAgentEnabled,
                              ),
                            ),
                          );
                        },
                      ),
                    ).animate().fade(delay: (50 * index).ms, duration: 300.ms).slideX(begin: 0.05); 
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