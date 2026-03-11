import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await ensureUserDoc(cred.user);
    return cred;
  }

  Future<UserCredential> signUpEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await ensureUserDoc(cred.user);
    return cred;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      await ensureUserDoc(cred.user);
      return cred;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled.');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    await ensureUserDoc(cred.user);
    return cred;
  }

  Future<UserCredential> signInWithApple() async {
    if (kIsWeb) {
      throw Exception('Apple sign-in is not enabled on web in this build.');
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw Exception('Apple sign-in is only available on iOS in this build.');
    }

    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );

    final oauth = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      accessToken: apple.authorizationCode,
    );

    final cred = await _auth.signInWithCredential(oauth);
    await ensureUserDoc(cred.user);
    return cred;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // ignore
      }
    }
    await _auth.signOut();
  }

  /// Deletes the Firebase Auth user + best-effort cleanup of /users/{uid}.
  /// Note: may throw FirebaseAuthException(code: requires-recent-login).
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Best-effort: delete user profile doc (do not block auth deletion).
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (_) {
      // ignore
    }

    // Delete Auth account (authoritative)
    await user.delete();

    // After deletion, ensure local sign-out state is clean
    await signOut();
  }

  Future<void> ensureUserDoc(User? user) async {
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();
    final providerIds = user.providerData.map((p) => p.providerId).toList();

    final defaults = <String, dynamic>{
      'displayName': user.displayName ?? '',
      'photoUrl': user.photoURL ?? '',
      'email': user.email ?? '',
      'isAnonymous': user.isAnonymous,
      'providerIds': providerIds,
      'notificationsEnabled': true,
      'stats': {
        'eventsCreated': 0,
        'eventsJoined': 0,
        'messagesSent': 0,
        'messagesReceived': 0,
      },
      'createdAt': now,
      'lastActiveAt': now,
    };

    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(defaults);
      return;
    }

    // Merge so existing values aren't wiped, but new keys get added.
    final data = snap.data() ?? <String, dynamic>{};

    await ref.set(
      {
        'lastActiveAt': now,
        'isAnonymous': user.isAnonymous,
        'providerIds': providerIds,
        'notificationsEnabled': (data['notificationsEnabled'] is bool) ? data['notificationsEnabled'] : true,
        'stats': (data['stats'] is Map) ? data['stats'] : defaults['stats'],
      },
      SetOptions(merge: true),
    );
  }
}