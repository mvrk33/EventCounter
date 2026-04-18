import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        // serverClientId must match the client_type:3 (Web client) OAuth ID
        // from your google-services.json. This is required for Firebase Auth
        // to receive a valid idToken on Android (prevents ApiException 10).
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: <String>['email', 'profile'],
              serverClientId: _googleServerClientId,
            );

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  User? get currentUser {
    if (!_firebaseReady) {
      return null;
    }
    return _auth.currentUser;
  }

  bool get isSignedIn => currentUser != null;

  Stream<User?> get authStateChanges {
    if (!_firebaseReady) {
      return Stream<User?>.value(null);
    }
    return _auth.authStateChanges();
  }

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  // Starts Google OAuth and signs into Firebase when available.
  Future<UserCredential?> signInWithGoogle() async {
    if (!_firebaseReady) {
      throw StateError('Firebase is not configured.');
    }

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
        'Firebase console and that google-services.json is up to date.',
      );
    }

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    await _upsertProfile(userCredential.user);
    return userCredential;
  }

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (!_firebaseReady) {
      throw StateError('Firebase is not configured.');
    }

    final String normalizedEmail = email.trim();
    final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    await _upsertProfile(userCredential.user);
    return userCredential;
  }

  Future<UserCredential> createAccountWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!_firebaseReady) {
      throw StateError('Firebase is not configured.');
    }

    final String normalizedEmail = email.trim();
    final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final User? user = userCredential.user;
    final String trimmedName = (displayName ?? '').trim();
    if (user != null && trimmedName.isNotEmpty) {
      await user.updateDisplayName(trimmedName);
      await user.reload();
    }

    await _upsertProfile(_auth.currentUser ?? userCredential.user);
    return userCredential;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!_firebaseReady) {
      throw StateError('Firebase is not configured.');
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Uses Apple credential with Firebase OAuth provider.
  Future<UserCredential?> signInWithApple() async {
    if (!_firebaseReady) {
      throw StateError('Firebase is not configured.');
    }

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

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    await _upsertProfile(userCredential.user);
    return userCredential;
  }

  Future<void> signOut() async {
    if (!_firebaseReady) {
      return;
    }
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore provider-specific sign out failures; Firebase sign-out already completed.
    }
  }

  // Deletes cloud data first, then deletes the auth user.
  Future<void> deleteAccount() async {
    if (!_firebaseReady) {
      return;
    }

    final User? user = _auth.currentUser;
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
