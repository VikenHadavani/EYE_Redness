import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Once signed in, return the UserCredential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // Register with email and password
  Future<User?> registerWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    try {
      // Create auth user
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Store additional user info in Firestore
      if (result.user != null) {
        await _firestore.collection('users').doc(result.user!.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // Update user display name
  Future<void> updateDisplayName(String name) async {
    try {
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updateDisplayName(name);

        // Also update in Firestore
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {'name': name.trim()},
        );
      }
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Get user display name from Firestore
  Future<String> getUserDisplayName() async {
    try {
      if (_auth.currentUser != null) {
        final doc =
            await _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .get();

        if (doc.exists && doc.data() != null) {
          return doc.data()!['name'] ?? '';
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // Password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Helper to handle Firebase Auth exceptions
  Exception _handleAuthException(FirebaseAuthException e) {
    String message;

    switch (e.code) {
      case 'user-not-found':
        message = 'No user found with this email.';
        break;
      case 'wrong-password':
        message = 'Incorrect password.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email.';
        break;
      case 'weak-password':
        message = 'The password provided is too weak.';
        break;
      case 'invalid-email':
        message = 'The email address is invalid.';
        break;
      case 'operation-not-allowed':
        message = 'This operation is not allowed.';
        break;
      default:
        message = e.message ?? 'An unknown error occurred.';
    }

    return Exception(message);
  }

  // Helper to handle generic Auth errors
  String _handleAuthError(dynamic error) {
    return error.toString();
  }
}
