import 'package:chatboom/screens/voice_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/chat_service.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final String receiverID;
  final String receiverName;
  final bool isReceiverAgentEnabled;

  const ChatScreen({
    super.key,
    required this.receiverID,
    required this.receiverName,
    required this.isReceiverAgentEnabled,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Set<String> _selectedMessageIds = {};
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.getMessages(
      FirebaseAuth.instance.currentUser!.uid, 
      widget.receiverID,
    );
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      await _chatService.sendMessage(
        _auth.currentUser!.uid,
        widget.receiverID,
        _messageController.text.trim(),
      );
      _messageController.clear();
    }
  }

  void _startAgentCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          agentName: widget.receiverName,
          currentUserId: _auth.currentUser!.uid, 
          receiverId: widget.receiverID, 
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserID = _auth.currentUser!.uid;

    return Scaffold(
      appBar: _selectedMessageIds.isNotEmpty
          ? AppBar(
              backgroundColor: const Color(0xFF1E1E1E), 
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _selectedMessageIds.clear()),
              ),
              title: Text('${_selectedMessageIds.length} Selected', style: const TextStyle(color: Colors.white)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    _chatService.deleteMultipleMessages(
                        currentUserID, widget.receiverID, _selectedMessageIds.toList());
                    setState(() => _selectedMessageIds.clear());
                  },
                ),
              ],
            )
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.receiverName),
                  if (widget.isReceiverAgentEnabled)
                    const Text(
                      '🤖 AI Assistant Active', 
                      style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              actions: [
                if (widget.isReceiverAgentEnabled)
                  Center( 
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.withOpacity(0.15),
                            foregroundColor: Colors.blueAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.record_voice_over, size: 16),
                          label: const Text("Call Agent", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: _startAgentCall,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("FIRESTORE ERROR: ${snapshot.error}"); 
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white54)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) return const Center(child: Text('Say hello!', style: TextStyle(color: Colors.white54)));

                return ListView.builder(
                  itemCount: messages.length,
                  reverse: true, 
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final message = Message.fromMap(messages[index].id, data);
                    final isMe = message.senderID == currentUserID;

                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(Message message, bool isMe) {
    final DateTime date = message.timestamp.toDate();
    final String timeString = "${date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
    final bool isSelected = _selectedMessageIds.contains(message.id);

    return GestureDetector(
      onTap: () {
        if (_selectedMessageIds.isNotEmpty && isMe && !message.isDeleted) {
          _toggleSelection(message.id);
        }
      },
      onLongPress: () {
        if (isMe && !message.isDeleted) {
          if (_selectedMessageIds.isNotEmpty) {
            _toggleSelection(message.id);
            return;
          }
          
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF1E1E1E), 
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.checklist, color: Colors.greenAccent),
                    title: const Text('Select Multiple', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context); 
                      _toggleSelection(message.id); 
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blueAccent),
                    title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context); 
                      _showEditDialog(message); 
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.redAccent),
                    title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context); 
                      _chatService.deleteMessage(_auth.currentUser!.uid, widget.receiverID, message.id);
                    },
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Container(
        color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75, 
                ),
                margin: const EdgeInsets.only(bottom: 4, top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.isDeleted 
                      ? Colors.white12 
                      : (isMe ? Colors.blueAccent : const Color(0xFF2A2A2A)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: message.isDeleted ? Colors.white38 : Colors.white, 
                    fontSize: 15,
                    fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited && !message.isDeleted)
                      const Text(
                        "(edited)  ",
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    Text(
                      timeString,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
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

  void _showEditDialog(Message message) {
    final TextEditingController editController = TextEditingController(text: message.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E), 
        title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          maxLines: null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: "Update your message...",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != message.text) {
                _chatService.editMessage(_auth.currentUser!.uid, widget.receiverID, message.id, newText);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A), 
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blueAccent,
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20), 
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1.0, duration: 400.ms, curve: Curves.easeOut).fade(); 
  }
}