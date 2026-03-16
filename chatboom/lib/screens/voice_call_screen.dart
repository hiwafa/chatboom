import 'dart:async';

import 'package:flutter/material.dart';
import '../services/voice_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String agentName;
  final String currentUserId;
  final String receiverId;

  const VoiceCallScreen({
    super.key, 
    required this.agentName,
    required this.currentUserId,
    required this.receiverId,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> with SingleTickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  bool _isConnecting = true;
  bool _isFinishing = false;
  bool _isAiTalking = false;
  Timer? _talkingTimer;
  late AnimationController _pulseController;
  final ScrollController _textScrollController = ScrollController();
  List<String> _currentUiOptions = [];
  String _aiTranscription = "";
  String _agentGender = "Female";
  bool _isRTL(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _voiceService.onUiActionReceived = (options) {
      if (mounted) {
        setState(() {
          // Intercept the hidden gender tag from VoiceService
          if (options.isNotEmpty && options.first.startsWith("GENDER:")) {
            _agentGender = options.first.split(":")[1];
            return;
          }
          _currentUiOptions = options;
        });
      }
    };

    _voiceService.onCallEnded = () {
      if (mounted && !_isFinishing) {
        setState(() => _isFinishing = true);
        Navigator.pop(context);
      }
    };

    // Listen for text transcriptions
    _voiceService.onTextReceived = (text) {
      if (mounted) {
        setState(() {
          if (text == "CLEAR_TEXT") {
            _aiTranscription = ""; // Clear on interruption
            _isAiTalking = false; // Reset talking state if interrupted
            _talkingTimer?.cancel();
          } else {
            _aiTranscription = text;
            _isAiTalking = true;

            _talkingTimer?.cancel();
            _talkingTimer = Timer(const Duration(milliseconds: 800), () {
              // If 800ms pass without a new word, the AI has stopped talking
              if (mounted) setState(() => _isAiTalking = false);
            });

            // auto scroll bottom smoothly
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_textScrollController.hasClients) {
                _textScrollController.animateTo(
                  _textScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
      }
    };
    
    _initiateCall();
  }

  void _initiateCall() async {
    bool success = await _voiceService.startCall(widget.currentUserId, widget.receiverId, widget.agentName);
    
    if (mounted) {
      if (success) {
        setState(() => _isConnecting = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to the AI Agent.')),
        );
        Navigator.pop(context); 
      }
    }
  }

  void _handleUiSelection(String selection) {
    _voiceService.sendUiSelection(selection);
    setState(() {
      _currentUiOptions = []; 
    });
  }

  void _endCall() async {
    if (_isFinishing) return; 
    
    setState(() {
      _isFinishing = true;
      _currentUiOptions = []; 
      _isAiTalking = false;
    }); 
    
    // Wait for the backend to generate and save the text summary
    await _voiceService.endCallAndSummarize();
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _talkingTimer?.cancel();
    _pulseController.dispose();
    _voiceService.forceDisconnect(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // Clean header with Lottie Animation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  // Lottie Avatar
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      double pulse = _pulseController.value;
                      double spread = _isAiTalking ? (8 * pulse) : 2.0;
                      double blur = _isAiTalking ? (20 * pulse + 10) : 10.0;
                      
                      Color baseColor = _isFinishing 
                          ? Colors.orange 
                          : (_isAiTalking ? Colors.blueAccent : Colors.tealAccent);
                      
                      Color glowColor = _isFinishing 
                          ? Colors.orangeAccent.withOpacity(0.5) 
                          : (_isAiTalking ? Colors.blueAccent.withOpacity(0.6 * pulse + 0.2) : Colors.tealAccent.withOpacity(0.2));

                      return Transform.translate(
                        offset: const Offset(8, 8), 
                        child: Container(
                          width: 80, 
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05), 
                            border: Border.all(
                              color: baseColor.withOpacity(0.8), 
                              width: _isAiTalking ? 2 + (2 * pulse) : 2,
                            ),
                            boxShadow: [
                              // Outer Glow
                              BoxShadow(
                                color: glowColor,
                                blurRadius: blur,
                                spreadRadius: spread,
                              ),
                              // Inner intense core glow when talking
                              if (_isAiTalking)
                                BoxShadow(
                                  color: Colors.purpleAccent.withOpacity(0.3 * pulse),
                                  blurRadius: 15,
                                  spreadRadius: -2,
                                ),
                            ],
                          ),
                          child: _isConnecting
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                              : Center(
                                  // The physical "Core" that expands and contracts
                                  child: Container(
                                    width: 40 + (10 * pulse),
                                    height: 40 + (10 * pulse),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: baseColor.withOpacity(_isAiTalking ? 0.9 : 0.4),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  // AI Status Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.agentName}'s AI",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        // DYNAMIC STATUS TEXT
                        Text(
                          _isFinishing 
                            ? "Wrapping up notes..." 
                            : (_isConnecting 
                                ? "Connecting..." 
                                : (_isAiTalking ? "AI is talking..." : "Listening...")),
                          style: TextStyle(
                            fontSize: 14, 
                            color: _isFinishing 
                                ? Colors.orange 
                                : (_isAiTalking ? Colors.blueAccent : Colors.greenAccent)
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // fixed Size Transcription Box (Smaller to save space)
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                controller: _textScrollController,
                physics: const BouncingScrollPhysics(),
                child: Text(
                  _aiTranscription.isEmpty && !_isConnecting ? "Say hello..." : _aiTranscription,
                  textAlign: _isRTL(_aiTranscription) ? TextAlign.right : TextAlign.left,
                  textDirection: _isRTL(_aiTranscription) ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 16, // Slightly smaller text to fit more words
                    color: _aiTranscription.isEmpty ? Colors.white38 : Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            // bottom expanded Area for Buttons (Lots of space!)
            Expanded(
              child: _currentUiOptions.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: SingleChildScrollView( 
                        physics: const BouncingScrollPhysics(),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: _currentUiOptions.map((option) {
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600, 
                                foregroundColor: Colors.white,
                                elevation: 4, 
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () => _handleUiSelection(option),
                              child: Text(
                                option, 
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
              
            // HANG UP BUTTON
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
              child: FloatingActionButton(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                onPressed: _endCall,
                child: const Icon(Icons.call_end, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}