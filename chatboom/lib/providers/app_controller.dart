import 'package:chatboom/models/note.dart';
import 'package:chatboom/screens/note_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppController extends ChangeNotifier {
  // allow us to navigate from ANYWHERE, even without context.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // tab Navigation State
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  void changeTab(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      
      // If we are deep inside a chat or note, pop back to the main tabs first
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      
      notifyListeners();
    }
  }

  // Command Execution
  // This will be called by the AI to open a specific user's chat
  void openChatLocally(Widget chatScreenWidget) {
    // Ensure we are on the home tab first (Chats tab)
    changeTab(0); 
    
    // Push the chat screen
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => chatScreenWidget),
    );
  }

  // go Back Navigation
  void goBack() {
    // Check if there is a screen to pop (like a chat screen)
    if (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState?.pop();
    } else {
      // If we are already at the root, ensure we are on the home tab
      changeTab(0);
    }
  }

  // open a spcific note visually
  void openNoteLocally(Note note) {
    // Switch to the Notes tab first
    changeTab(1); 
    
    // Push the Note Detail screen
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
    );
  }

  // Draft State
  String? _draftMessage;
  String? get draftMessage => _draftMessage;

  void setDraftMessage(String text) {
    _draftMessage = text;
    notifyListeners();
  }

  void clearDraft() {
    _draftMessage = null;
    notifyListeners();
  }

  // Global Copilot Overlay State
  bool _isCopilotActive = false;
  bool get isCopilotActive => _isCopilotActive;

  void showCopilot() {
    _isCopilotActive = true;
    notifyListeners();
  }

  void hideCopilot() {
    _isCopilotActive = false;
    clearDraft();
    notifyListeners();
  }

  // Profile Actions
  Function()? openImagePickerCallback;

  void triggerImagePicker() {
    changeTab(3); // Instantly navigate to Profile tab
    Future.delayed(const Duration(milliseconds: 300), () {
      openImagePickerCallback?.call(); 
    });
  }

  // STUDY MODE STATE
  String _studyTopic = "General";
  String get studyTopic => _studyTopic;

  List<dynamic> _flashcards = [];
  List<dynamic> get flashcards => _flashcards;

  // Store the user's saved categories for the UI
  List<String> _savedTopics = [];
  List<String> get savedTopics => _savedTopics;

  int _currentCardIndex = 0;
  int get currentCardIndex => _currentCardIndex;

  bool _isCardFlipped = false;
  bool get isCardFlipped => _isCardFlipped;

  void setSavedTopics(List<String> topics) {
    _savedTopics = topics;
    notifyListeners();
  }

  void removeSavedTopic(String topic) {
    _savedTopics.remove(topic);
    notifyListeners();
  }

  Future<List<String>> fetchSavedTopics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('study_decks')
          .get();
          
      _savedTopics = snapshot.docs.map((d) => d.id).toList();
      notifyListeners(); // Updates the UI instantly
      return _savedTopics;
    }
    return [];
  }

  void startStudyTopic(String topic) {
    _studyTopic = topic;
    _flashcards = [];
    _currentCardIndex = 0;
    _isCardFlipped = false;
    changeTab(2);
    notifyListeners();
  }

  void loadFlashcards(List<dynamic> cards) {
    _flashcards = cards;
    _currentCardIndex = 0;
    _isCardFlipped = false;
    notifyListeners();
  }

  void addFlashcards(List<dynamic> newCards) {
    // 1. Calculate where the new cards will begin
    int newStartIndex = _flashcards.length; 
    
    // 2. Add them to the deck
    _flashcards.addAll(newCards);
    
    // 3. Jump the screen directly to the newly generated cards!
    _currentCardIndex = newStartIndex; 
    _isCardFlipped = false;
    notifyListeners();
  }

  // Toggle for manual UI clicking
  void toggleCardFlip() {
    _isCardFlipped = !_isCardFlipped;
    notifyListeners();
  }

  // Used by AI
  void flipCard() {
    _isCardFlipped = true;
    notifyListeners();
  }

  void nextCard() {
    if (_currentCardIndex < _flashcards.length - 1) {
      _currentCardIndex++;
      _isCardFlipped = false;
      notifyListeners();
    }
  }

  // manual previos card navigation
  void prevCard() {
    if (_currentCardIndex > 0) {
      _currentCardIndex--;
      _isCardFlipped = false;
      notifyListeners();
    }
  }

  // Return to the Categories Grid
  void closeDeck() {
    _flashcards = [];
    _studyTopic = "General";
    notifyListeners();
  }

  void exitStudy() {
    changeTab(0); // return to home/chats
    notifyListeners();
  }

}