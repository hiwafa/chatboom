import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate a unique, consistent chat room ID between two users
  String _getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort(); // Sorting ensures the ID is the same regardless of who sends first
    return ids.join('_');
  }

  // Send a message
  Future<void> sendMessage(String currentUserId, String receiverId, String text) async {
    final String chatRoomId = _getChatRoomId(currentUserId, receiverId);
    
    final message = Message(
      senderID: currentUserId,
      receiverID: receiverId,
      text: text,
      timestamp: Timestamp.now(),
    );

    // Add message to the specific conversation's subcollection
    await _firestore
        .collection('conversations')
        .doc(chatRoomId)
        .collection('messages')
        .add(message.toMap());
  }

  // Real-time listener for messages
  Stream<QuerySnapshot> getMessages(String currentUserId, String otherUserId) {
    final String chatRoomId = _getChatRoomId(currentUserId, otherUserId);

    return _firestore
        .collection('conversations')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots(); // .snapshots() provides the real-time stream
  }

  // Add this inside ChatService
  Future<void> saveSummaryAsNoteAndMessage(
    String noteOwnerId, 
    String callerId,   
    String callerName,  
    String summaryText
  ) async {

    final String chatRoomId = _getChatRoomId(noteOwnerId, callerId);
    await sendMessage(noteOwnerId, callerId, "🤖 AI Call Summary:\n\n$summaryText");

    String noteType = 'Other';
    final types = ['Meeting', 'Reminder', 'Call', 'Invitation', 'Travel'];
    for (var t in types) {
      if (summaryText.toLowerCase().contains(t.toLowerCase())) {
        noteType = t;
        break;
      }
    }

    await _firestore
        .collection('users')
        .doc(noteOwnerId)
        .collection('notes')
        .add({
      'otherUserId': callerId,
      'otherUserName': callerName,
      'chatRoomId': chatRoomId,
      'summary': summaryText,
      'type': noteType,
      'timestamp': Timestamp.now(),
    });
  }

  // Soft Delete a message for everyone
  Future<void> deleteMessage(String currentUserId, String otherUserId, String messageId) async {
    final String chatRoomId = _getChatRoomId(currentUserId, otherUserId);
    
    await _firestore
        .collection('conversations')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isDeleted': true,
      'text': '🚫 This message was deleted',
    });
  }

  // Edit a message for everyone
  Future<void> editMessage(String currentUserId, String otherUserId, String messageId, String newText) async {
    final String chatRoomId = _getChatRoomId(currentUserId, otherUserId);
    
    await _firestore
        .collection('conversations')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true, // Flag it as edited
    });
  }

  // Delete multiple messages at once
  Future<void> deleteMultipleMessages(String currentUserId, String otherUserId, List<String> messageIds) async {
    final String chatRoomId = _getChatRoomId(currentUserId, otherUserId);
    
    // Chunks of 100
    for (var i = 0; i < messageIds.length; i += 100) {
      final batch = _firestore.batch();
      
      // Get the next chunk safely
      final end = (i + 100 < messageIds.length) ? i + 100 : messageIds.length;
      final chunk = messageIds.sublist(i, end);

      for (String msgId in chunk) {
        final docRef = _firestore
            .collection('conversations')
            .doc(chatRoomId)
            .collection('messages')
            .doc(msgId);

        batch.update(docRef, {
          'isDeleted': true,
          'text': '🚫 This message was deleted',
        });
      }

      await batch.commit();
    }
  }

}