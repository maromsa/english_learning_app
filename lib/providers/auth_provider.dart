import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    AuthService? authService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(),
       _authService = authService ?? AuthService() {
    _authSubscription = _auth.authStateChanges().listen(
      _handleAuthStateChanged,
    );
  }

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  User? _firebaseUser;
  AppUser? _appUser;
  bool _initializing = true;
  bool _busy = false;
  String? _errorMessage;

  bool get initializing => _initializing;
  bool get isBusy => _busy;
  bool get isAuthenticated => _firebaseUser != null;
  User? get firebaseUser => _firebaseUser;
  AppUser? get currentUser => _appUser;
  String? get errorMessage => _errorMessage;

  Future<void> signInWithGoogle() async {
    _setBusy(true);
    _errorMessage = null;

    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters(const {'prompt': 'select_account'});
        await _auth.signInWithPopup(googleProvider);
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw FirebaseAuthException(
            code: 'aborted-by-user',
            message: 'Sign-in aborted by user',
          );
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Authentication failed.';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _setBusy(true);
    try {
      await _auth.signOut();
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> refreshUserProfile() async {
    final user = _firebaseUser;
    if (user == null) {
      return;
    }
    _setBusy(true);
    try {
      _appUser = await _authService.getUser(user.uid);
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    _firebaseUser = user;

    if (user == null) {
      _appUser = null;
      if (_initializing) {
        _initializing = false;
      }
      notifyListeners();
      return;
    }

    try {
      _appUser = await _authService.upsertUser(user);
    } catch (e) {
      _errorMessage = 'Failed to sync user profile: $e';
    }

    if (_initializing) {
      _initializing = false;
    }
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_busy == value) {
      return;
    }
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
