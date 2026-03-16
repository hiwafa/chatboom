import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderID;
  final String receiverID;
  final String text;
  final Timestamp timestamp;
  final bool isDeleted;
  final bool isEdited;

  Message({
    this.id = '', 
    required this.senderID,
    required this.receiverID,
    required this.text,
    required this.timestamp,
    this.isDeleted = false,
    this.isEdited = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'receiverID': receiverID,
      'text': text,
      'timestamp': timestamp,
      'isDeleted': isDeleted,
      'isEdited': isEdited,
    };
  }

  factory Message.fromMap(String docId, Map<String, dynamic> map) {
    return Message(
      id: docId,
      senderID: map['senderID'] ?? '',
      receiverID: map['receiverID'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      isDeleted: map['isDeleted'] ?? false,
      isEdited: map['isEdited'] ?? false,
    );
  }
}