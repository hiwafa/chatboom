import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';

class VoiceService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  final ChatService _chatService = ChatService();

  Function(List<String>)? onUiActionReceived;
  Function(String)? onTextReceived;
  Completer<void>? _summaryCompleter;
  Function()? onCallEnded;

  String? _currentUserId;
  String? _receiverId;
  String? _receiverName;

  bool _isSummarizing = false;
  bool _isDisposed = false;
  final Map<String, String> _aiTranscriptionSegments = {};

  String get _tokenServerUrl {
    return 'https://chatboom-server-349851174448.us-central1.run.app/getToken';
  }

  Future<bool> startCall(String currentUserId, String receiverId, String receiverName) async {
    _currentUserId = currentUserId;
    _receiverId = receiverId;
    _receiverName = receiverName;
    _isDisposed = false;
    _isSummarizing = false;
    _aiTranscriptionSegments.clear();

    try {
      // Grabing the secure Firebase ID Token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      // Ask the Python backend for a LiveKit Room Token securely
      debugPrint("Fetching WebRTC token from $_tokenServerUrl...");
      final response = await http.post(
        Uri.parse(_tokenServerUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken', 
        },
        body: jsonEncode({
          'currentUserId': currentUserId,
          'receiverId': receiverId,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("❌ Failed to get token: ${response.body}");
        return false;
      }

      final data = jsonDecode(response.body);
      final token = data['token'];
      final url = data['url'];

      // Initialize and Connect to the LiveKit Room
      debugPrint("🔌 Connecting to LiveKit Room...");
      _room = Room();
      _listener = _room!.createListener();

      // Listen for incoming UI buttons or Summaries via Data Channels
      _listener!.on<DataReceivedEvent>((event) {
        final message = utf8.decode(event.data);
        _handleIncomingData(message);
      });

      // Listen for Native AI Text Transcriptions
      _listener!.on<TranscriptionEvent>((event) {
        bool didUpdate = false;
        for (var segment in event.segments) {
          // Only capture what the AI says (ignoring local user transcription)
          if (segment.text.isNotEmpty && event.participant is RemoteParticipant) {
            // Overwrite interim updates so words don't duplicate
            _aiTranscriptionSegments[segment.id] = segment.text;
            didUpdate = true;
          }
        }

        if (didUpdate) {

          if (_aiTranscriptionSegments.length > 5) {
            final keysToKeep = _aiTranscriptionSegments.keys.toList().sublist(_aiTranscriptionSegments.length - 5);
            _aiTranscriptionSegments.removeWhere((key, value) => !keysToKeep.contains(key));
          }

          // Send the perfectly tracked, spaced text to the UI
          onTextReceived?.call(_aiTranscriptionSegments.values.join("\n\n"));
        }
      });

      await _room!.connect(url, token);
      debugPrint("🎙️ Connected! Turning on microphone...");
      
      // Turn on the microphone
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      // Fetch AI Persona Data & Labeled Chat Context
      final receiverDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
      final agentPrompt = receiverDoc.data()?['agentPrompt'] ?? "Busy, Just take a note for me.";
      final agentGender = receiverDoc.data()?['agentGender'] ?? "Female";
      
      final chatRoomId = [currentUserId, receiverId]..sort();

      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(chatRoomId.join('_'))
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(12)
          .get();

      List<String> scriptMemory = [];
      
      // We reverse the list so it reads chronologically (oldest to newest)
      for (var doc in messagesSnapshot.docs.reversed) {
        final data = doc.data(); // Access the map data
        final text = data['text'] ?? '';
        final senderID = data['senderID'] ?? '';
        final isDeleted = data['isDeleted'] ?? false;

        // Skip deleted messages so the AI doesn't read "🚫 This message was deleted"
        if (isDeleted) continue;

        // 🏷️ THE MAGIC: Labeling the speakers!
        if (senderID == currentUserId) {
          scriptMemory.add("Caller: $text");
        } else {
          scriptMemory.add("$receiverName: $text");
        }
      }

      // Fetch the caller's name to pass to the AI
      final callerName = FirebaseAuth.instance.currentUser?.displayName ?? "Caller";

      final initPayload = jsonEncode({
        "ownerName": receiverName,
        "callerName": callerName,
        "agentPrompt": agentPrompt,
        "agentGender": agentGender,
        "recentContext": scriptMemory.join("\n"), 
      });
      
      // We also need to let the UI know which gender to display
      onUiActionReceived?.call(["GENDER:$agentGender"]);

      // 5. Send the INIT context to the Python Agent
      debugPrint("⏳ Waiting for AI to enter the room...");
      
      // Check if the AI is already in the room
      bool agentReady = _room!.remoteParticipants.isNotEmpty;

      // If not, explicitly wait for the connection event (up to 15 seconds)
      if (!agentReady) {
        await _listener!.waitFor<ParticipantConnectedEvent>(
          duration: const Duration(seconds: 21),
          onTimeout: () {
            debugPrint("⚠️ AI Agent took too long to join.");
            return () {} as ParticipantConnectedEvent; // Exit gracefully
          },
        );
      }

      debugPrint("⏳ Stabilizing Data Channel...");
      await Future.delayed(const Duration(milliseconds: 1500));
      
      debugPrint("🚀 AI Joined! Sending INIT payload via Data Channel...");
      await _room!.localParticipant?.publishData(utf8.encode("INIT:$initPayload"));

      return true;
    } catch (e) {
      debugPrint("🔥 Fatal error in startCall: $e");
      await forceDisconnect();
      return false;
    }
  }

  void _handleIncomingData(String message) {
    debugPrint("📥 Received Data: $message");

    if (message == "CLEAR_TEXT") {
      _aiTranscriptionSegments.clear();
      onTextReceived?.call("CLEAR_TEXT");
    } else if (message.startsWith("SUMMARY:")) {
      String summaryText = message.substring("SUMMARY:".length);
      debugPrint("📝 Summary Received! Text: $summaryText");
      
      final callerName = FirebaseAuth.instance.currentUser?.displayName ?? "Caller";
      
      _chatService
          .saveSummaryAsNoteAndMessage(_receiverId!, _currentUserId!, callerName, summaryText)
          .catchError((e) => debugPrint("Local save fallback error: $e"));

      if (_summaryCompleter != null && !_summaryCompleter!.isCompleted) {
        _summaryCompleter!.complete();
      }

      onCallEnded?.call();
      forceDisconnect();
      
    } else if (message.startsWith("[UI:") && message.endsWith("]")) {
      debugPrint("🎯 UI Payload detected!");
      final optionsString = message.substring(4, message.length - 1);
      final optionsList = optionsString.split('|').map((e) => e.trim()).toList();
      onUiActionReceived?.call(optionsList);
    }
  }

  void sendUiSelection(String selection) async {
    debugPrint("👆 User tapped UI option: $selection");
    await _room?.localParticipant?.publishData(utf8.encode("UI_SELECT:$selection"));
  }

  Future<void> endCallAndSummarize() async {
    if (_isSummarizing) return;
    debugPrint("⏳ Ending call and requesting summary from Gemini...");

    _isSummarizing = true;
    _summaryCompleter = Completer<void>();

    try {
      // Mute microphone immediately so user isn't recorded while waiting
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      
      // Tell Python backend we hung up
      await _room?.localParticipant?.publishData(utf8.encode("END_CALL"));
    } catch(e) {
      debugPrint("Error sending END_CALL: $e");
    }

    Timer(const Duration(seconds: 30), () async {
      if (_summaryCompleter != null && !_summaryCompleter!.isCompleted) {
        debugPrint("⚠️ Summary timed out. Saving fallback note locally.");
        if (_currentUserId != null && _receiverId != null && _receiverName != null) {
          final callerName = FirebaseAuth.instance.currentUser?.displayName ?? "Caller";
          
          _chatService
              .saveSummaryAsNoteAndMessage(
                _receiverId!, _currentUserId!, callerName, "Call ended. AI processing took too long.")
              .catchError((e) => debugPrint("Fallback save error: $e"));
        }
        _summaryCompleter!.complete(); 
        await forceDisconnect();
      }
    });

    return _summaryCompleter!.future;
  }

  Future<void> forceDisconnect() async {
    if (_isDisposed) return;
    _isDisposed = true; 
    debugPrint("🧹 Cleaning up LiveKit resources...");
    
    _isSummarizing = false;
    
    try {
      await _listener?.dispose();
      await _room?.disconnect();
      await _room?.dispose();
    } catch (e) {
      debugPrint("Room cleanup error: $e");
    }

    _room = null;
    _listener = null;
  }
}