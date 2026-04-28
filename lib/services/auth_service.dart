import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  String get _currentPlatform {
    if (kIsWeb) return 'web';
    // Platform detection for native
    try {
      // Will be replaced with dart:io Platform check in native builds
      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Register new user - always tagged as source: evora_app
  Future<UserCredential> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (displayName != null) {
      await credential.user?.updateDisplayName(displayName);
    }

    // Write user doc with app source tag
    await _db.collection('users').doc(credential.user!.uid).set({
      'email': email,
      'displayName': displayName,
      'source': 'evora_app',           // KEY: tag for email sequence
      'platform': _currentPlatform,
      'registeredAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'connectedDevices': [],
      'emailSequence': 'onboarding',   // trigger field for sequences
      'emailSequenceEnrolledAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  /// Login existing user - update lastLoginAt
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last login
    await _db.collection('users').doc(credential.user!.uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Password reset
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Get user doc from Firestore
  Future<EvoraUser?> getUserDoc(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return EvoraUser.fromFirestore(doc);
  }

  /// Stream user doc
  Stream<EvoraUser?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return EvoraUser.fromFirestore(doc);
    });
  }
}
