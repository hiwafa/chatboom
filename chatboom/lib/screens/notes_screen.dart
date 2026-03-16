import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
import '../models/note.dart';
import 'note_detail_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  final Set<String> _selectedNoteIds = {};
  late Stream<QuerySnapshot> _notesStream;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _notesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notes')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  void _toggleSelection(String noteId) {
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  Future<void> _deleteSelectedNotes() async {
    if (currentUser == null || _selectedNoteIds.isEmpty) return;

    final notesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notes');

    final noteIdsList = _selectedNoteIds.toList();

    for (var i = 0; i < noteIdsList.length; i += 100) {
      final batch = FirebaseFirestore.instance.batch();
      
      final end = (i + 100 < noteIdsList.length) ? i + 100 : noteIdsList.length;
      final chunk = noteIdsList.sublist(i, end);

      for (String noteId in chunk) {
        batch.delete(notesRef.doc(noteId));
      }

      await batch.commit();
    }

    setState(() {
      _selectedNoteIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selected notes deleted', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blueAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold();

    return Scaffold(
      appBar: _selectedNoteIds.isNotEmpty
          ? AppBar(
              backgroundColor: const Color(0xFF1E1E1E),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _selectedNoteIds.clear()),
              ),
              title: Text('${_selectedNoteIds.length} Selected', style: const TextStyle(color: Colors.white)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        title: const Text('Delete Notes?', style: TextStyle(color: Colors.white)),
                        content: Text('Are you sure you want to permanently delete these ${_selectedNoteIds.length} notes?', style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteSelectedNotes();
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            )
          : AppBar(
              title: const Text('AI Conversation Notes'),
            ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notesStream, 
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading notes', style: TextStyle(color: Colors.white54)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No notes yet. Call an AI agent!', style: TextStyle(color: Colors.white54)));

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), 
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final note = Note.fromMap(docs[index].id, docs[index].data() as Map<String, dynamic>);
              final date = note.timestamp.toDate();
              final dateString = "${date.month}/${date.day}/${date.year}";
              final bool isSelected = _selectedNoteIds.contains(note.id);

              return GestureDetector(
                onLongPress: () {
                  if (_selectedNoteIds.isEmpty) {
                    _toggleSelection(note.id);
                  }
                },
                onTap: () {
                  if (_selectedNoteIds.isNotEmpty) {
                    _toggleSelection(note.id);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
                    );
                  }
                },
                child: Container(
                  color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.transparent,
                  child: Dismissible(
                    key: Key(note.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24.0),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.shade400,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white, size: 28),
                    ),
                    confirmDismiss: (direction) async {
                      if (_selectedNoteIds.isNotEmpty) return false; 
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text('Delete Note?', style: TextStyle(color: Colors.white)),
                          content: const Text('Are you sure you want to permanently delete this note?', style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser!.uid)
                          .collection('notes')
                          .doc(note.id)
                          .delete();
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: isSelected ? 0 : 4,
                      color: const Color(0xFF1E1E1E), // Dark card surface
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isSelected ? const BorderSide(color: Colors.blueAccent, width: 2) : const BorderSide(color: Colors.white10),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          child: Icon(_getIconForType(note.type), color: Colors.blueAccent),
                        ),
                        title: Text(
                          'Call with ${note.otherUserName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${note.type} • $dateString\n${note.summary}', 
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, height: 1.3),
                          ),
                        ),
                        isThreeLine: true,
                        trailing: _selectedNoteIds.isNotEmpty 
                            ? Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_unchecked, 
                                color: isSelected ? Colors.blueAccent : Colors.white38,
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
              ).animate().fade(delay: (50 * index).ms, duration: 300.ms).slideX(begin: 0.05); 
            },
          );
        },
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Meeting': return Icons.groups;
      case 'Travel': return Icons.flight;
      case 'Invitation': return Icons.event;
      case 'Reminder': return Icons.alarm;
      default: return Icons.note;
    }
  }
}