import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (Ref ref) => AuthService(),
);

final StreamProvider<User?> authStateChangesProvider = StreamProvider<User?>((Ref ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  static const String _googleServerClientId =
      '469114218525-l169tmdmmg0uavkk5q6svuq9c4m72isv.apps.googleusercontent.com';

  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _auth = firebaseAuth ??
            (Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null),
        // serverClientId must match the client_type:3 (Web client) OAuth ID
        // from your google-services.json. This is required for Firebase Auth
        // to receive a valid idToken on Android (prevents ApiException 10).
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: <String>['email', 'profile'],
              serverClientId: _googleServerClientId,
            );

  final FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuth _requireAuth() {
    final FirebaseAuth? auth = _auth;
    if (auth == null || !_firebaseReady) {
      throw StateError('Firebase is not configured.');
    }
    return auth;
  }

  User? get currentUser {
    if (!_firebaseReady) {
      return null;
    }
    return _auth?.currentUser;
  }

  bool get isSignedIn => currentUser != null;

  Stream<User?> get authStateChanges {
    if (!_firebaseReady) {
      return Stream<User?>.value(null);
    }
    return _auth?.authStateChanges() ?? Stream<User?>.value(null);
  }

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  Future<User> _awaitAuthenticatedUser({String? expectedUid}) async {
    final FirebaseAuth auth = _requireAuth();

    User? currentUser = auth.currentUser;
    if (currentUser == null ||
        (expectedUid != null && currentUser.uid != expectedUid)) {
      currentUser = await auth
          .authStateChanges()
          .where((User? value) =>
              value != null && (expectedUid == null || value.uid == expectedUid))
          .cast<User>()
          .first
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw StateError(
              'Timed out waiting for Firebase Authentication state to settle.',
            ),
          );
    }

    // Force-refresh once so Firestore gets an authenticated request.auth context.
    await currentUser.getIdToken(true);
    return currentUser;
  }

  // Starts Google OAuth and signs into Firebase when available.
  Future<UserCredential?> signInWithGoogle() async {
    final FirebaseAuth auth = _requireAuth();

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled the sign-in flow.
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await account.authentication;

      // idToken is null when the SHA-1 fingerprint is not registered in the
      // Firebase console or when google-services.json is misconfigured.
      if (googleAuth.idToken == null) {
        await _googleSignIn.signOut();
        throw StateError(
          'Google Sign-In returned a null idToken. '
          'Make sure the SHA-1 certificate fingerprint is registered in the '
          'Firebase console and that google-services.json is up to date. '
          'Error: DEVELOPER_ERROR typically means certificate SHA-1 mismatch. '
          'Debug keystore: ~/.android/debug.keystore',
        );
      }


      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await auth.signInWithCredential(credential);
      final User user =
          await _awaitAuthenticatedUser(expectedUid: userCredential.user?.uid);
      await _upsertProfile(user);
      return userCredential;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final FirebaseAuth auth = _requireAuth();

    final String normalizedEmail = email.trim();
    final UserCredential userCredential =
        await auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    final User user =
        await _awaitAuthenticatedUser(expectedUid: userCredential.user?.uid);
    await _upsertProfile(user);
    return userCredential;
  }

  Future<UserCredential> createAccountWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final FirebaseAuth auth = _requireAuth();

    final String normalizedEmail = email.trim();
    final UserCredential userCredential = await auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final User? createdUser = userCredential.user;
    final String trimmedName = (displayName ?? '').trim();
    if (createdUser != null && trimmedName.isNotEmpty) {
      await createdUser.updateDisplayName(trimmedName);
      await createdUser.reload();
    }

    final User user =
        await _awaitAuthenticatedUser(expectedUid: userCredential.user?.uid);
    await _upsertProfile(user);
    return userCredential;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final FirebaseAuth auth = _requireAuth();
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  // Uses Apple credential with Firebase OAuth provider.
  Future<UserCredential?> signInWithApple() async {
    final FirebaseAuth auth = _requireAuth();

    final bool appleAvailable = await SignInWithApple.isAvailable();
    if (!appleAvailable) {
      throw StateError('Apple Sign-In is only available on supported Apple platforms.');
    }

    final AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: <AppleIDAuthorizationScopes>[
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    if (appleCredential.identityToken == null || appleCredential.authorizationCode.isEmpty) {
      throw StateError('Apple Sign-In did not return a valid identity token.');
    }

    final OAuthProvider provider = OAuthProvider('apple.com');
    final OAuthCredential credential = provider.credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final UserCredential userCredential =
        await auth.signInWithCredential(credential);
    final User user =
        await _awaitAuthenticatedUser(expectedUid: userCredential.user?.uid);
    await _upsertProfile(user);
    return userCredential;
  }

  Future<void> signOut() async {
    final FirebaseAuth? auth = _auth;
    if (!_firebaseReady || auth == null) {
      return;
    }
    await auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore provider-specific sign out failures; Firebase sign-out already completed.
    }
  }

  // Deletes cloud data first, then deletes the auth user.
  Future<void> deleteAccount() async {
    final FirebaseAuth? auth = _auth;
    if (!_firebaseReady || auth == null) {
      return;
    }

    final User? user = auth.currentUser;
    if (user == null) {
      return;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final WriteBatch batch = firestore.batch();

    final CollectionReference<Map<String, dynamic>> eventsRef =
        firestore.collection('users').doc(user.uid).collection('events');
    final CollectionReference<Map<String, dynamic>> habitsRef =
        firestore.collection('users').doc(user.uid).collection('habits');
    final CollectionReference<Map<String, dynamic>> profileRef =
        firestore.collection('users').doc(user.uid).collection('profile');

    final QuerySnapshot<Map<String, dynamic>> events = await eventsRef.get();
    final QuerySnapshot<Map<String, dynamic>> habits = await habitsRef.get();
    final QuerySnapshot<Map<String, dynamic>> profiles = await profileRef.get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in events.docs) {
      batch.delete(doc.reference);
    }
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in habits.docs) {
      batch.delete(doc.reference);
    }
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in profiles.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    await user.delete();
  }

  Future<void> _upsertProfile(User? user) async {
    if (user == null) {
      return;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('profile')
        .doc(user.uid)
        .set(<String, dynamic>{
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
