import 'dart:async';
import 'dart:convert';
import 'package:chatboom/models/note.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_calendar/native_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_controller.dart';
import '../screens/chat_screen.dart';
import 'chat_service.dart';

class AppCopilotService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  
  final AppController appController;
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;
  String? _activeChatUserId; 
  StreamSubscription<QuerySnapshot>? _activeChatSubscription;
  DateTime? _chatEnteredTime;
  
  // Callbacks for the UI to show transcriptions or connection status
  Function(String)? onTranscriptionUpdate;
  Function(bool)? onConnectionStateChanged;

  // Track previous state to prevent spamming the AI
  int _lastBroadcastIndex = -1;
  bool _lastBroadcastFlipped = false;

  AppCopilotService({required this.appController}) {
    // Listen to the AppController. Any time state changes (like a swipe or flip), this runs!
    appController.addListener(_onAppStateChanged);
  }

  void _onAppStateChanged() {
    // Only broadcast if we are currently looking at the Study tab AND we have cards loaded
    if (appController.currentTabIndex == 2 && appController.flashcards.isNotEmpty) {
      final currentIndex = appController.currentCardIndex;
      final isFlipped = appController.isCardFlipped;
      
      // Only send the payload if the card ACTUALLY changed or flipped
      if (_lastBroadcastIndex != currentIndex || _lastBroadcastFlipped != isFlipped) {
        _lastBroadcastIndex = currentIndex;
        _lastBroadcastFlipped = isFlipped;
        
        final currentCard = appController.flashcards[currentIndex];
        
        // Add a tiny delay so the UI finishes animating before we tell the AI
        Future.delayed(const Duration(milliseconds: 300), () {
           _broadcastStudyState(currentIndex, currentCard);
        });
      }
    }
  }

  String get _tokenServerUrl {
    return 'https://chatboom-server-349851174448.us-central1.run.app/getToken';
  }

  Future<bool> startCopilot(String currentUserId, String currentUserName) async {
    _currentUserId = currentUserId;
    onConnectionStateChanged?.call(true);

    try {
      // Taking the secure Firebase ID Token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      debugPrint("Copilot fetching token securely...");
      final response = await http.post(
        Uri.parse(_tokenServerUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'currentUserId': currentUserId,
          'receiverId': 'copilot_agent', 
        }),
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      final token = data['token'];
      final url = data['url'];

      // Connect to LiveKit
      _room = Room();
      _listener = _room!.createListener();

      // Listen for AI Commands via Data Channel
      _listener!.on<DataReceivedEvent>((event) {
        final message = utf8.decode(event.data);
        _handleAiCommand(message);
      });

      // Prevent stuttering/duplication
      final Map<String, String> aiTranscriptionSegments = {};

      // Listen for AI Voice Transcription
      _listener!.on<TranscriptionEvent>((event) {
        bool didUpdate = false;
        for (var segment in event.segments) {
          if (segment.text.isNotEmpty && event.participant is RemoteParticipant) {
            aiTranscriptionSegments[segment.id] = segment.text;
            didUpdate = true;
          }
        }

        if (didUpdate) {
          if (aiTranscriptionSegments.length > 3) {
            final keysToKeep = aiTranscriptionSegments.keys.toList().sublist(aiTranscriptionSegments.length - 3);
            aiTranscriptionSegments.removeWhere((key, value) => !keysToKeep.contains(key));
          }

          // Send the perfectly tracked, spaced text to the UI
          onTranscriptionUpdate?.call(aiTranscriptionSegments.values.join("\n\n"));
        }
      });

      await _room!.connect(url, token);
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      // Fetch Contacts List
      final usersSnapshot = await _firestore.collection('users').get();
      List<Map<String, String>> contacts = [];
      for (var doc in usersSnapshot.docs) {
        if (doc.id != currentUserId) {
          contacts.add({"id": doc.id, "name": doc.data()['name'] ?? "Unknown"});
        }
      }

      // Fetch the 12 most recent Notes for the AI to read
      final notesSnapshot = await _firestore.collection('users')
          .doc(currentUserId)
          .collection('notes')
          .orderBy('timestamp', descending: true)
          .limit(12)
          .get();
          
      List<Map<String, dynamic>> recentNotes = [];
      for (var doc in notesSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        recentNotes.add({
          "id": doc.id,
          "otherUserName": data['otherUserName'] ?? 'Unknown',
          "type": data['type'] ?? 'Other',
          "summary": data['summary'] ?? '',
          "date": timestamp != null ? timestamp.toDate().toIso8601String() : DateTime.now().toIso8601String(),
        });
      }

      // Send INIT Payload
      final initPayload = jsonEncode({
        "userName": currentUserName,
        "contacts": contacts,
        "recentNotes": recentNotes,
      });

      await Future.delayed(const Duration(milliseconds: 2000));
      await _room!.localParticipant?.publishData(utf8.encode("INIT_COPILOT:$initPayload"));

      onConnectionStateChanged?.call(false);
      return true;

    } catch (e) {
      debugPrint("🔥 Copilot connection failed: $e");
      onConnectionStateChanged?.call(false);
      await stopCopilot();
      return false;
    }
  }

  // COMMAND ROUTER
  void _handleAiCommand(String jsonString) async {
    try {
      final data = jsonDecode(jsonString);
      final command = data['command'];
      debugPrint("🤖 Copilot Command Received: $command");

      switch (command) {
        case 'navigate':
          _activeChatSubscription?.cancel(); // Turn off listener if we leave the chat
          final tab = data['tab'];
          if (tab == 'chats') appController.changeTab(0);
          else if (tab == 'notes') appController.changeTab(1);
          else if (tab == 'study') {
            final savedTopics = await appController.fetchSavedTopics();
            appController.changeTab(2); 
            final payload = jsonEncode({"mode": "study", "topic": "Main Menu", "savedTopics": savedTopics});
            _room?.localParticipant?.publishData(utf8.encode("SWITCH_MODE:$payload"));
          } else if (tab == 'profile') appController.changeTab(3);
          break;

        case 'open_chat':
          final targetUserId = data['userId'];
          final targetUserName = data['userName'];
          _activeChatUserId = targetUserId;

          //  Check agent status & Open UI
          final doc = await _firestore.collection('users').doc(targetUserId).get();
          final isAgentEnabled = doc.data()?['agentEnabled'] ?? false;
          appController.openChatLocally(ChatScreen(
            receiverID: targetUserId, receiverName: targetUserName, isReceiverAgentEnabled: isAgentEnabled,
          ));

          if (_currentUserId != null) {
            final chatRoomId = [_currentUserId!, targetUserId]..sort();
            final roomDocId = chatRoomId.join('_');

            //  CONTEXT (Fetch last 10 messages)
            final messagesSnap = await _firestore.collection('conversations')
                .doc(roomDocId).collection('messages')
                .orderBy('timestamp', descending: true).limit(10).get();

            List<String> history = [];
            for (var msgDoc in messagesSnap.docs.reversed) {
              final msgData = msgDoc.data();
              if (msgData['isDeleted'] == true) continue;
              final sender = msgData['senderID'] == _currentUserId ? "Me" : targetUserName;
              history.add("$sender: ${msgData['text']}");
            }

            final historyPayload = jsonEncode({"history": history.join("\n")});
            _room?.localParticipant?.publishData(utf8.encode("CHAT_CONTEXT:$historyPayload"));

            //  REAL TIME LISTENER (Watch for new incoming messages)
            _chatEnteredTime = DateTime.now();
            _activeChatSubscription?.cancel(); 
            _activeChatSubscription = _firestore.collection('conversations')
                .doc(roomDocId).collection('messages')
                .orderBy('timestamp', descending: true).limit(1)
                .snapshots().listen((snapshot) {
              
              if (snapshot.docs.isEmpty) return;
              final newMsg = snapshot.docs.first.data();
              final senderID = newMsg['senderID'];
              final msgTime = (newMsg['timestamp'] as Timestamp).toDate();

              // Only interrupt if the message is from the OTHER person AND arrived right now
              if (senderID == targetUserId && msgTime.isAfter(_chatEnteredTime!)) {
                final text = newMsg['text'];
                final newMsgPayload = jsonEncode({"senderName": targetUserName, "text": text});
                _room?.localParticipant?.publishData(utf8.encode("NEW_MESSAGE:$newMsgPayload"));
              }
            });
          }
          break;

        case 'go_back':
          _activeChatSubscription?.cancel(); // Turn off listener if we leave the chat
          appController.goBack();
          break;

        case 'draft_message':
          final text = data['text'];
          appController.setDraftMessage(text);
          break;

        case 'send_message':
          final draftText = appController.draftMessage;
          if (draftText != null && draftText.isNotEmpty && _activeChatUserId != null) {
            await _chatService.sendMessage(_currentUserId!, _activeChatUserId!, draftText);
            appController.clearDraft();
          } else {
            debugPrint("⚠️ Cannot send message: No active draft or chat target.");
          }
          break;
        
        case 'open_note':
          final noteId = data['noteId'];
          // Fast lookup: Fetch the specific note document
          final noteDoc = await _firestore.collection('users').doc(_currentUserId).collection('notes').doc(noteId).get();
          if (noteDoc.exists) {
            final note = Note.fromMap(noteDoc.id, noteDoc.data()!);
            appController.openNoteLocally(note);
          }
          break;
        
        case 'add_to_calendar':
          final title = data['title'];
          final description = data['description'];
          
          // Construct the start time from the AI's exact numbers
          final startTime = DateTime(
            data['year'], 
            data['month'], 
            data['day'], 
            data['hour'], 
            data['minute']
          );
          
          // Let's assume meetings are 1 hour long by default
          final endTime = startTime.add(const Duration(hours: 1));

          final event = CalendarEvent(
            title: title,
            description: description,
            startDate: startTime,
            endDate: endTime,
          );

          // This pops the native OS calendar sheet!
          NativeCalendar.openCalendarWithEvent(event);
          break;
        
        // PROFILE COMMANDS
        case 'toggle_agent':
          if (_currentUserId != null) {
            await _firestore.collection('users').doc(_currentUserId).update({'agentEnabled': data['enable']});
          }
          break;

        case 'set_agent_prompt':
          if (_currentUserId != null) {
            await _firestore.collection('users').doc(_currentUserId).update({'agentPrompt': data['prompt']});
          }
          break;

        case 'set_agent_gender':
          if (_currentUserId != null) {
            await _firestore.collection('users').doc(_currentUserId).update({'agentGender': data['gender']});
          }
          break;

        case 'open_image_picker':
          appController.triggerImagePicker();
          break;

        // STUDY MODE COMMANDS
        case 'study_start_topic':
          final topic = data['topic'];
          appController.startStudyTopic(topic);
          
          // Check if this topic already exists in Firebase!
          if (_currentUserId != null) {
            final doc = await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('study_decks')
                .doc(topic).get();
                
            if (doc.exists && doc.data()!.containsKey('cards')) {
              // Load the previously saved cards into the UI
              final existingCards = doc.data()!['cards'] as List<dynamic>;
              appController.loadFlashcards(existingCards);
            }
          }
          break;

        case 'study_generate_cards':
          // 1. Add the new AI-generated cards to the UI
          appController.addFlashcards(data['cards']);
          
          // 2. Save the entire updated deck to Firebase
          if (_currentUserId != null) {
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('study_decks')
                .doc(appController.studyTopic)
                .set({
              'topic': appController.studyTopic,
              'cards': appController.flashcards, // Saves the complete list
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
          break;

        case 'study_flip_card':
          appController.flipCard();
          break;

        case 'study_next_card':
          appController.nextCard();
          break;
        
        case 'study_prev_card':
          appController.prevCard();
          break;

        case 'exit_study_mode':
          appController.exitStudy();
          // Tell Python to swap back to the Normal Brain!
          final payload = jsonEncode({"mode": "general"});
          _room?.localParticipant?.publishData(utf8.encode("SWITCH_MODE:$payload"));
          break;
      }
    } catch (e) {
      debugPrint("Error parsing AI command: $e");
    }
  }

  Future<void> stopCopilot() async {
    appController.clearDraft();
    _activeChatSubscription?.cancel();
    _activeChatUserId = null;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      await _listener?.dispose();
      await _room?.disconnect();
    } catch (e) {
      debugPrint("Copilot disconnect error: $e");
    }
    _room = null;
    _listener = null;
  }

  // Example of how to send the state when the index changes
  void _broadcastStudyState(int index, dynamic currentCard) {
    if (_room?.localParticipant != null) {
      final payload = jsonEncode({
        "index": index + 1, // +1 so it makes sense to the AI (Card 1, not Card 0)
        "front": currentCard['front'],
        "back": currentCard['back']
      });
      _room!.localParticipant!.publishData(utf8.encode("STUDY_STATE:$payload"));
    }
  }
}