import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/note.dart';
import 'chat_screen.dart';

class NoteDetailScreen extends StatelessWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  void _navigateToChat(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E), // Dark Dialog
        title: const Text('Open Conversation?', style: TextStyle(color: Colors.white)),
        content: const Text('This will take you to the original chat thread.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Open Chat')
          ),
        ],
      ),
    ) ?? false;

    if (!confirm || !context.mounted) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(note.otherUserId).get();
    final isAgentEnabled = doc.data()?['agentEnabled'] ?? false;

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            receiverID: note.otherUserId,
            receiverName: note.otherUserName,
            isReceiverAgentEnabled: isAgentEnabled,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note Details'),
       
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(note.type, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)), 
                  backgroundColor: Colors.blueAccent.withOpacity(0.15),
                  side: BorderSide.none,
                ).animate().fade(duration: 300.ms).scaleXY(begin: 0.9),
                
                const Spacer(),
                
                Text(
                  "${note.timestamp.toDate().month}/${note.timestamp.toDate().day}/${note.timestamp.toDate().year}",
                  style: const TextStyle(color: Colors.white54),
                ).animate().fade(delay: 100.ms),
              ],
            ),
            const SizedBox(height: 24),
            
            Text(
              'Outcome from call with ${note.otherUserName}:', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)
            ).animate().fade(delay: 200.ms).slideX(begin: 0.05),
            
            const SizedBox(height: 12),
            
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), // Sleek dark card
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    note.summary, 
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70)
                  ),
                ),
              ).animate().fade(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05),
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text('Go to Original Conversation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                onPressed: () => _navigateToChat(context),
              ),
            ).animate().fade(delay: 400.ms).scaleXY(begin: 0.95),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}