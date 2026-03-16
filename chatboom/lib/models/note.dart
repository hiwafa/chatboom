import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String chatRoomId;
  final String summary;
  final String type;
  final Timestamp timestamp;

  Note({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    required this.chatRoomId,
    required this.summary,
    required this.type,
    required this.timestamp,
  });

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      otherUserId: map['otherUserId'] ?? '',
      otherUserName: map['otherUserName'] ?? 'Unknown',
      chatRoomId: map['chatRoomId'] ?? '',
      summary: map['summary'] ?? '',
      type: map['type'] ?? 'Other',
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }
}