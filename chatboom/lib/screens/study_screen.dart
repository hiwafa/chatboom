import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_controller.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = context.watch<AppController>();
    final cards = appController.flashcards;
    final topics = appController.savedTopics;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(cards.isEmpty ? 'My Study Decks' : appController.studyTopic),
        leading: cards.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => appController.closeDeck(), 
              )
            : null,
      ),
      body: cards.isEmpty
          ? _buildCategoriesGrid(context, topics)
          : _buildFlashcardView(context, cards, appController),
    );
  }

  // THE CATEGORIES GRID
  Widget _buildCategoriesGrid(BuildContext context, List<String> topics) {
    if (topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 60, color: Colors.blueAccent.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text("No decks yet.", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Ask 'My AI' to generate flashcards!", style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      ).animate().fade(duration: 400.ms).slideY(begin: 0.1);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        return GestureDetector(
          onTap: () => _openDeckManually(context, topic),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_special, size: 40, color: Colors.blueAccent),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          topic,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _confirmDeleteDeck(context, topic),
                  ),
                ),
              ],
            ),
          ).animate().fade(delay: (50 * index).ms, duration: 300.ms).scaleXY(begin: 0.9),
        );
      },
    );
  }

  void _openDeckManually(BuildContext context, String topic) async {
    final appController = context.read<AppController>();
    appController.startStudyTopic(topic);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('study_decks').doc(topic).get();
      if (doc.exists && doc.data()!.containsKey('cards')) {
        appController.loadFlashcards(doc.data()!['cards'] as List<dynamic>);
      }
    }
  }

  void _confirmDeleteDeck(BuildContext context, String topic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Delete Deck?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '$topic'? This cannot be undone.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Cancel", style: TextStyle(color: Colors.white54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx); 
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('study_decks').doc(topic).delete();
                if (context.mounted) {
                  context.read<AppController>().removeSavedTopic(topic);
                }
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // THE FLASHCARD UI
  Widget _buildFlashcardView(BuildContext context, List<dynamic> cards, AppController appController) {
    final currentIndex = appController.currentCardIndex;  

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Progress Tracker
          Text("Card ${currentIndex + 1} of ${cards.length}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white54))
              .animate().fade(duration: 300.ms),
          
          const SizedBox(height: 24),
          
          // The Interactive Card
          Expanded(
            child: GestureDetector(
              onTap: () => appController.toggleCardFlip(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final rotateAnim = Tween(begin: 3.14, end: 0.0).animate(animation);
                  return AnimatedBuilder(
                    animation: rotateAnim,
                    child: child,
                    builder: (context, widget) {
                      final isUnder = (ValueKey(!appController.isCardFlipped) != widget?.key);
                      var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                      tilt *= isUnder ? -1.0 : 1.0;
                      final value = isUnder ? min(rotateAnim.value, 3.14 / 2) : rotateAnim.value;
                      return Transform(
                        transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                        alignment: Alignment.center,
                        child: widget,
                      );
                    },
                  );
                },
                child: Container(
                  key: ValueKey(appController.isCardFlipped),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Builder(
                    builder: (context) {
                      final card = cards[currentIndex];
                      final isFront = !appController.isCardFlipped;
                      final isNewFormat = card['front'] is Map;

                      if (isFront) {
                        if (isNewFormat) {
                          final frontData = card['front'] as Map<String, dynamic>;
                          final word = frontData['word']?.toString() ?? '';
                          final sentence = frontData['sentence']?.toString() ?? '';

                          return Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(word, textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                                  if (sentence.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(sentence, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white70)),
                                  ]
                                ],
                              ),
                            ),
                          );
                        } else {
                          return Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(card['front'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          );
                        }
                      } else {
                        if (isNewFormat) {
                          final backData = card['back'] as Map<String, dynamic>;
                          final m1 = backData['first_meaning']?.toString() ?? '';
                          final s1 = backData['first_sentence_meaning']?.toString() ?? '';
                          final m2 = backData['second_meaning']?.toString() ?? '';
                          final s2 = backData['second_sentence_meaning']?.toString() ?? '';

                          List<Widget> backWidgets = [];
                          
                          if (m1.isNotEmpty) backWidgets.add(Text(m1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)));
                          if (s1.isNotEmpty) backWidgets.add(Padding(padding: const EdgeInsets.only(top: 8, bottom: 16), child: Text(s1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white70))));
                          
                          if (m2.isNotEmpty) {
                            backWidgets.add(const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white24, thickness: 2)));
                            backWidgets.add(Text(m2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)));
                          }
                          if (s2.isNotEmpty) backWidgets.add(Padding(padding: const EdgeInsets.only(top: 8), child: Text(s2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white70))));

                          return Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: backWidgets,
                              ),
                            ),
                          );
                        } else {
                          final normalizedText = card['back'].toString().replaceAll('\\\\n', '\n').replaceAll('\\n', '\n').replaceAll('\r\n', '\n');
                          final backTextLines = normalizedText.split('\n');
                          final mainTranslation = backTextLines.first;
                          final exampleText = backTextLines.length > 1 ? backTextLines.sublist(1).join('\n') : "";

                          return Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(mainTranslation, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                                  if (exampleText.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(exampleText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white70, height: 1.4)),
                                  ]
                                ],
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
          ).animate().fade(duration: 400.ms).scaleXY(begin: 0.95),
          
          const SizedBox(height: 32),

          // Manual Navigation Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 48, color: currentIndex > 0 ? Colors.white : Colors.white24,
                icon: const Icon(Icons.arrow_circle_left_outlined),
                onPressed: currentIndex > 0 ? () => appController.prevCard() : null,
              ),
              const SizedBox(width: 40),
              IconButton(
                iconSize: 48, color: currentIndex < cards.length - 1 ? Colors.blueAccent : Colors.white24,
                icon: const Icon(Icons.arrow_circle_right),
                onPressed: currentIndex < cards.length - 1 ? () => appController.nextCard() : null,
              ),
            ],
          ).animate().fade(delay: 200.ms), 
          
          const SizedBox(height: 48), 
        ],
      ),
    );
  }
}