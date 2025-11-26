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
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _authService = authService ?? AuthService() {
    // Check current auth state immediately
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _firebaseUser = currentUser;
      // Load user profile asynchronously with timeout
      _authService.getUser(currentUser.uid)
          .timeout(const Duration(seconds: 3))
          .then((user) {
        _appUser = user;
        _initializing = false;
        notifyListeners();
      }).catchError((e) {
        debugPrint('Error loading user profile: $e');
        _initializing = false;
        notifyListeners();
      });
    } else {
      _initializing = false;
      notifyListeners();
    }
    
    _authSubscription = _auth.authStateChanges().listen(
      _handleAuthStateChanged,
    );
    
    // Set a timeout to prevent infinite loading
    Future.delayed(const Duration(seconds: 3), () {
      if (_initializing) {
        _initializing = false;
        notifyListeners();
      }
    });
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
        await _auth.signInWithPopup(googleProvider).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Sign-in timed out. Please try again.');
          },
        );
      } else {
        // Ensure GoogleSignIn is initialized
        await _googleSignIn.initialize();
        // Add timeout to prevent hanging
        final googleUser = await _googleSignIn.authenticate().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Sign-in timed out. Please try again.');
          },
        );

        // Get authentication tokens
        final googleAuth = googleUser.authentication;
        
        // Get access token via authorization client if needed
        String? accessToken;
        try {
          final clientAuth = await googleUser.authorizationClient
              .authorizationForScopes(['email', 'profile']).timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
          accessToken = clientAuth?.accessToken;
        } catch (e) {
          debugPrint('Failed to get access token: $e');
          // Continue with just idToken
        }
        
        final credential = GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Sign-in credential verification timed out. Please try again.');
          },
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('Sign-in timeout: $e');
      _errorMessage = e.message ?? 'Sign-in timed out. Please check your internet connection and try again.';
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase auth error: ${e.code} - ${e.message}');
      _errorMessage = e.message ?? 'Authentication failed. Please try again.';
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Sign-in error: $e');
      debugPrint('Stack trace: $stackTrace');
      _errorMessage = 'An error occurred during sign-in. Please try again.';
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
      // Add timeout to prevent hanging on user sync
      _appUser = await _authService.upsertUser(user).timeout(
        const Duration(seconds: 5),
      );
    } on TimeoutException {
      debugPrint('User sync timed out, continuing without sync');
      // If timeout occurs, try to get existing user or leave _appUser as null
      try {
        _appUser = await _authService.getUser(user.uid).timeout(
          const Duration(seconds: 2),
        );
      } catch (e) {
        debugPrint('Failed to get existing user: $e');
        // Leave _appUser as null if we can't get it
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to sync user profile: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't set error message here - user is still authenticated
      // Just log the error and continue
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
