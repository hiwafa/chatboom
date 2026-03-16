import 'package:chatboom/providers/app_controller.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppController>().openImagePickerCallback = _pickAndUploadImage;
    });
  }

  Future<void> _toggleAgent(bool value) async {
    if (currentUser == null) return;
    
    await _firestore.collection('users').doc(currentUser!.uid).update({
      'agentEnabled': value,
    });
  }

  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    if (currentUser == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 50,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return; 

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final storageRef = FirebaseStorage.instance.ref().child('profile_images/${currentUser!.uid}.jpg');
      await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();

      await _firestore.collection('users').doc(currentUser!.uid).update({
        'avatar': downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated!', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.greenAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final bool isAgentEnabled = userData['agentEnabled'] ?? false;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickAndUploadImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: const Color(0xFF2A2A2A),
                          backgroundImage: (userData['avatar'] != null && userData['avatar'].toString().isNotEmpty)
                              ? NetworkImage(userData['avatar'])
                              : null,
                          child: (userData['avatar'] == null || userData['avatar'].toString().isEmpty)
                              ? const Icon(Icons.person, size: 50, color: Colors.white38)
                              : null,
                        ),
                      ),
                      if (_isUploading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(color: Colors.blueAccent),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent, 
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF121212), width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 400.ms).scaleXY(begin: 0.8),
              
              const SizedBox(height: 24),
              
              // --- Name ---
              Text(
                userData['name'] ?? 'User',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
              ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 40),
              
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: const Text('Enable AI Agent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: const Text('Allow your AI to answer voice calls when you are away.', style: TextStyle(color: Colors.white54, height: 1.3)),
                      value: isAgentEnabled,
                      activeColor: Colors.blueAccent,
                      onChanged: _toggleAgent,
                    ),
                    
                    if (isAgentEnabled) ...[
                      const Divider(color: Colors.white10, height: 1),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: userData['agentGender'] ?? 'Female',
                              dropdownColor: const Color(0xFF2A2A2A),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'AI Voice Gender',
                                labelStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF121212),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Female', child: Text('Female Voice')),
                                DropdownMenuItem(value: 'Male', child: Text('Male Voice')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _firestore.collection('users').doc(currentUser!.uid).update({
                                    'agentGender': value,
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              key: ValueKey(userData['agentPrompt']),
                              initialValue: userData['agentPrompt'] ?? '',
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'What should your AI tell callers?',
                                labelStyle: const TextStyle(color: Colors.white54),
                                hintText: 'e.g., I am traveling and will be back...',
                                hintStyle: const TextStyle(color: Colors.white24),
                                filled: true,
                                fillColor: const Color(0xFF121212), 
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                helperText: 'Press "Done/Enter" on your keyboard to save.',
                                helperStyle: const TextStyle(color: Colors.white38),
                              ),
                              maxLines: 3,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (value) {
                                _firestore.collection('users').doc(currentUser!.uid).update({
                                  'agentPrompt': value,
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('AI Prompt saved successfully!', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.blueAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 300.ms).slideY(begin: -0.1), 
                    ]
                  ],
                ),
              ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 40),
              
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () async {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  context.read<AppController>().changeTab(0);
                  await AuthService().signOut();
                },
              ).animate().fade(delay: 300.ms).scaleXY(begin: 0.95),
            ],
          );
        },
      ),
    );
  }
}