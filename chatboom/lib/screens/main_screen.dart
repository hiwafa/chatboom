import 'package:chatboom/screens/study_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:flutter_animate/flutter_animate.dart'; 
import '../providers/app_controller.dart'; 
import 'home_screen.dart'; 
import 'notes_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _pages = [
    const HomeScreen(), 
    const NotesScreen(),
    const StudyScreen(),
    const ProfileScreen()
  ];

  @override
  Widget build(BuildContext context) {
    final int currentIndex = context.watch<AppController>().currentTabIndex;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            context.read<AppController>().changeTab(index);
            
            if (index == 2) {
              context.read<AppController>().fetchSavedTopics();
            }
          },
          backgroundColor: const Color(0xFF1A1A1A), 
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          elevation: 0, 
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chats'),
            BottomNavigationBarItem(icon: Icon(Icons.note_alt_outlined), activeIcon: Icon(Icons.note_alt), label: 'Notes'),
            BottomNavigationBarItem(icon: Icon(Icons.school_outlined), activeIcon: Icon(Icons.school), label: 'Study'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile')
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<AppController>().showCopilot();
        },
        backgroundColor: Colors.blueAccent,
        elevation: 8,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text("My AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 600.ms, duration: 500.ms, curve: Curves.easeOutBack),
    );
  }
}