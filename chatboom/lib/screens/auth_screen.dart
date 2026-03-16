import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLogin = true;
  bool _isLoading = false;
  
  String _email = '';
  String _password = '';
  String _name = '';

  void _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signInWithEmail(_email, _password);
      } else {
        await _authService.signUpWithEmail(_email, _password, _name);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)), 
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // use the global theme colors defined in main.dart natively
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: ConstrainedBox(
            // Keeps the form from stretching too wide on Web/Tablets
            constraints: const BoxConstraints(maxWidth: 450),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10), 
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 15)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header ---
                    Icon(Icons.auto_awesome, size: 48, color: Colors.blueAccent.withOpacity(0.8))
                        .animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin ? 'Welcome Back' : 'Join Chatboom',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin ? 'Sign in to continue to your AI' : 'Create an account to get started',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                    const SizedBox(height: 32),

                    // Input Fields (Animated sequentially) ---
                    Column(
                      children: [
                        if (!_isLogin) ...[
                          TextFormField(
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                            validator: (val) => val!.trim().isEmpty ? 'Please enter your name' : null,
                            onSaved: (val) => _name = val!.trim(),
                          ).animate().fade(duration: 400.ms).slideX(begin: 0.05),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) => val!.isEmpty || !val.contains('@') ? 'Enter a valid email' : null,
                          onSaved: (val) => _email = val!.trim(),
                        ).animate().fade(delay: 100.ms, duration: 400.ms).slideX(begin: 0.05),
                        const SizedBox(height: 16),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                          obscureText: true,
                          validator: (val) => val!.length < 6 ? 'Password must be at least 6 characters' : null,
                          onSaved: (val) => _password = val!.trim(),
                        ).animate().fade(delay: 200.ms, duration: 400.ms).slideX(begin: 0.05),
                      ],
                    ),
                    
                    const SizedBox(height: 32),

                    // Action Buttons ---
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                    else ...[
                      ElevatedButton(
                        onPressed: _submitAuthForm,
                        child: Text(_isLogin ? 'Login' : 'Sign Up', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ).animate().fade(delay: 300.ms).scaleXY(begin: 0.95),
                      
                      const SizedBox(height: 16),
                      
                      OutlinedButton.icon(
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: _signInWithGoogle,
                      ).animate().fade(delay: 400.ms).scaleXY(begin: 0.95),
                    ],

                    const SizedBox(height: 24),

                    //  Toggle Login/Signup ---
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: RichText(
                        text: TextSpan(
                          text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                          style: const TextStyle(color: Colors.white54),
                          children: [
                            TextSpan(
                              text: _isLogin ? "Sign Up" : "Log In",
                              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(delay: 500.ms),
                  ],
                ),
              ),
            ),
          ).animate().fade(duration: 600.ms, curve: Curves.easeOut).slideY(begin: 0.05),
        ),
      ),
    );
  }
}