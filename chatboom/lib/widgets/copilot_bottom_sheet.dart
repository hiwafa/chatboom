import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_controller.dart';
import '../services/app_copilot_service.dart';

class CopilotBottomSheet extends StatefulWidget {
  const CopilotBottomSheet({super.key});

  @override
  State<CopilotBottomSheet> createState() => _CopilotBottomSheetState();
}

class _CopilotBottomSheetState extends State<CopilotBottomSheet> with SingleTickerProviderStateMixin {
  late AppCopilotService _copilotService;
  late AnimationController _pulseController;
  final ScrollController _textScrollController = ScrollController(); 
  
  bool _isConnecting = true;
  String _transcription = "Listening...";
  bool _isAiTalking = false;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    final appController = Provider.of<AppController>(context, listen: false);
    _copilotService = AppCopilotService(appController: appController);

    _copilotService.onConnectionStateChanged = (isConnecting) {
      if (mounted) setState(() => _isConnecting = isConnecting);
    };

    _copilotService.onTranscriptionUpdate = (text) {
      if (mounted) {
        setState(() {
          _transcription = text;
          _isAiTalking = true;
        });
        
        // Auto-scroll to bottom when new text arrives
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_textScrollController.hasClients) {
            _textScrollController.animateTo(
              _textScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _isAiTalking = false);
        });
      }
    };

    _startAI();
  }

  void _startAI() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _copilotService.startCopilot(user.uid, user.displayName ?? "User");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textScrollController.dispose();
    _copilotService.stopCopilot(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draftMessage = context.watch<AppController>().draftMessage;

    // Align allows touches to pass through the invisible parts of the screen!
    return Align(
      alignment: _isMinimized ? Alignment.bottomRight : Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        child: _isMinimized
            ? _buildMinimizedBubble()
            : _buildExpandedSheet(draftMessage, context),
      ),
    );
  }

  // THE NEW MINIMIZED FLOATING ORB
  Widget _buildMinimizedBubble() {
    return GestureDetector(
      key: const ValueKey('minimized'), // Keys are required for AnimatedSwitcher
      onTap: () => setState(() => _isMinimized = false), // Tap to expand
      child: Container(
        margin: const EdgeInsets.only(right: 24, bottom: 100), // Hover above the nav bar
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            double pulse = _pulseController.value;
            return Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: const Color(0xFF1E1E1E), // Solid dark background
                border: Border.all(color: Colors.white10, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _isConnecting ? Colors.orangeAccent.withOpacity(0.3) : Colors.blueAccent.withOpacity(0.5 * pulse + 0.3),
                    blurRadius: 20, spreadRadius: _isAiTalking ? (12 * pulse) : 4,
                  ),
                ],
              ),
              child: Center(
                child: _isConnecting
                    ? const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)
                    : Icon(_isAiTalking ? Icons.graphic_eq : Icons.auto_awesome, color: Colors.blueAccent.shade100, size: 28),
              ),
            );
          },
        ),
      ),
    ).animate().scaleXY(begin: 0.5, duration: 300.ms, curve: Curves.easeOutBack);
  }

  // THE ORIGINAL EXPANDED SHEET (With a Minimize Button)
  Widget _buildExpandedSheet(String? draftMessage, BuildContext context) {
    return Material(
      key: const ValueKey('expanded'), // Keys are required for AnimatedSwitcher
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity, 
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          top: false, 
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. The New Minimize Button
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 32),
                  onPressed: () => setState(() => _isMinimized = true), // Tap to shrink
                ),
              ),

              // 2. Your Original UI Stack
              Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      double pulse = _pulseController.value;
                      return Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: Colors.white.withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(
                              color: _isConnecting ? Colors.orangeAccent.withOpacity(0.3) : Colors.blueAccent.withOpacity(0.5 * pulse + 0.2),
                              blurRadius: 20, spreadRadius: _isAiTalking ? (10 * pulse) : 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isConnecting
                              ? const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)
                              : Icon(Icons.graphic_eq, color: Colors.blueAccent.shade100, size: 30),
                        ),
                      );
                    },
                  ).animate().fade(duration: 400.ms).scaleXY(begin: 0.8), 
                  
                  const SizedBox(height: 16),

                  Container(
                    height: 100, 
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      controller: _textScrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        _transcription,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
                      ),
                    ),
                  ).animate().fade(delay: 100.ms, duration: 400.ms), 
                  
                  const SizedBox(height: 16),

                  if (draftMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A), 
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Draft Message", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text(draftMessage, style: const TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent.shade100, 
                                    side: BorderSide(color: Colors.redAccent.shade100),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => context.read<AppController>().clearDraft(),
                                  child: const Text("Cancel"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    context.read<AppController>().clearDraft();
                                  },
                                  child: const Text("Send"),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ).animate().fade(duration: 300.ms).slideY(begin: 0.1), 
                  ],
                  
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.read<AppController>().hideCopilot(),
                    child: const Text("Close AI", style: TextStyle(color: Colors.redAccent)),
                  ).animate().fade(delay: 200.ms), 
                ],
              ),
            ],
          ),
        ),
      ).animate().slideY(begin: 1.0, duration: 300.ms, curve: Curves.easeOutCubic), 
    );
  }
}