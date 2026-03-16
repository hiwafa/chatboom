import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 1: Use the new Singleton instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email & Password Sign Up
  Future<UserCredential?> signUpWithEmail(String email, String password, String name) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _createUserProfile(credential.user!, name);
    return credential;
  }

  // Email & Password Login
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    UserCredential credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    
    // Guarantee the profile exists even on standard logins
    await _createUserProfile(credential.user!, credential.user!.displayName ?? 'User');
    
    return credential;
  }

  // Google Sign-In (Updated for v7.0.0+)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        
        UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        await _createUserProfile(userCredential.user!, userCredential.user!.displayName ?? 'User');
        return userCredential;
        
      } else {
        const String webClientId = '214593941438-vr8mi3ei2vo7gvbbm9ecll4j35ihr9v9.apps.googleusercontent.com';
        await _googleSignIn.initialize(clientId: webClientId);

        // 1. Authenticate (Gets the ID Token)
        final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
        if (googleUser == null) return null; 

        // 2. Authorize (Gets the Access Token)
        final GoogleSignInClientAuthorization clientAuth = 
            await googleUser.authorizationClient.authorizeScopes(['email']);

        // 3. Combine them for Firebase
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: clientAuth.accessToken,
          idToken: googleUser.authentication.idToken, 
        );

        UserCredential userCredential = await _auth.signInWithCredential(credential);
        await _createUserProfile(userCredential.user!, googleUser.displayName ?? 'User');
        return userCredential;
      }
    } catch (e) {
      debugPrint("🔥 Google Auth Error: $e");
      rethrow;
    }
  }

  // Create/Ensure Firestore Profile Exists
  Future<void> _createUserProfile(User user, String name) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      final appUser = AppUser(
        userID: user.uid,
        name: name,
        email: user.email ?? '',
        avatar: user.photoURL ?? '',
        agentEnabled: false,
      );
      await userDoc.set(appUser.toMap());
    }
  }

  Future<void> signOut() async => await _auth.signOut();
}