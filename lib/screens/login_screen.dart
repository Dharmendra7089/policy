import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _navy = Color(0xFF0D2D4F);
  static const _blue = Color(0xFF1A6EBD);
  static const _lightBlue = Color(0xFFEAF4FF);
  static const _text = Color(0xFF10233A);
  static const _muted = Color(0xFF66758A);
  static const _error = Color(0xFFB42318);

  bool _checkingSession = true;
  bool _signingIn = false;
  String? _errorMessage;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _checkingSession = false);
      return;
    }

    try {
      await _authorizeAndOpen(user);
    } on _AccessException catch (error) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _checkingSession = false;
          _errorMessage = error.message;
        });
      }
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _checkingSession = false;
          _errorMessage = 'Could not verify your employee access. Try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _employeeProfile(User user) async {
    final normalizedEmail = user.email?.trim().toLowerCase() ?? '';
    for (final collection in const ['admins', 'agents']) {
      final uidMatches = await FirebaseFirestore.instance
          .collection(collection)
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 12));
      if (uidMatches.docs.isNotEmpty) {
        final doc = uidMatches.docs.first;
        final data = doc.data();
        return {
          ...data,
          'role': data['role'] ?? (collection == 'admins' ? 'admin' : 'agent'),
          '_profileCollection': collection,
          '_profileDocId': doc.id,
        };
      }

      final matches = await FirebaseFirestore.instance
          .collection(collection)
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 12));
      if (matches.docs.isEmpty) continue;

      final doc = matches.docs.first;
      final data = doc.data();
      return {
        ...data,
        'role': data['role'] ?? (collection == 'admins' ? 'admin' : 'agent'),
        '_profileCollection': collection,
        '_profileDocId': doc.id,
      };
    }
    return null;
  }

  bool _isActive(Map<String, dynamic> profile) {
    if (profile['is_active'] == false) return false;
    final status = (profile['status'] ?? 'Active').toString().toLowerCase();
    return status != 'inactive' && status != 'disabled';
  }

  Future<void> _authorizeAndOpen(User user) async {
    final email = user.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      throw const _AccessException(
        'The selected Google account does not provide an email address.',
      );
    }

    final profile = await _employeeProfile(user);
    if (profile == null) {
      throw const _AccessException(
        'This Google email is not registered in Employees. Contact an admin.',
      );
    }
    if (!_isActive(profile)) {
      throw const _AccessException(
        'This employee login is inactive. Contact an admin.',
      );
    }

    final collection = profile['_profileCollection'].toString();
    final docId = profile['_profileDocId'].toString();
    await FirebaseFirestore.instance.collection(collection).doc(docId).set({
      'uid': user.uid,
      'loginEmail': email,
      'last_login': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(adminData: {...profile, 'uid': user.uid}),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _signingIn = true;
      _errorMessage = null;
    });

    try {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      final credential = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);
      final user = credential.user;
      if (user == null) {
        throw const _AccessException(
          'Google Sign-In did not return an account.',
        );
      }
      await _authorizeAndOpen(user);
    } on _AccessException catch (error) {
      await FirebaseAuth.instance.signOut();
      if (mounted) setState(() => _errorMessage = error.message);
    } on FirebaseAuthException catch (error) {
      if (_wasCancelled(error.code)) {
        if (mounted) setState(() => _signingIn = false);
        return;
      }
      await FirebaseAuth.instance.signOut();
      if (mounted) setState(() => _errorMessage = _authMessage(error.code));
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _errorMessage = 'Google Sign-In could not be completed. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signInWithCredentials() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password.');
      return;
    }

    setState(() {
      _signingIn = true;
      _errorMessage = null;
    });
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const _AccessException('Sign-in did not return an account.');
      }
      await _authorizeAndOpen(user);
    } on _AccessException catch (error) {
      await FirebaseAuth.instance.signOut();
      if (mounted) setState(() => _errorMessage = error.message);
    } on FirebaseAuthException catch (error) {
      await FirebaseAuth.instance.signOut();
      if (mounted) setState(() => _errorMessage = _authMessage(error.code));
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(
          () => _errorMessage = 'Sign-in could not be completed. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  bool _wasCancelled(String code) => {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-canceled',
    'canceled',
  }.contains(code);

  String _authMessage(String code) => switch (code) {
    'operation-not-allowed' =>
      'This sign-in method is not enabled for this Firebase project.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Incorrect email or password.',
    'invalid-email' => 'Enter a valid email address.',
    'user-disabled' => 'This login has been disabled. Contact an admin.',
    'account-exists-with-different-credential' =>
      'This email already uses another sign-in method. Contact an admin.',
    'network-request-failed' =>
      'Network connection failed. Check your internet and try again.',
    'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
    _ => 'Sign-in failed ($code). Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_navy, Color(0xFF0F4D82), _blue],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: -90,
                right: -70,
                child: _GlowCircle(size: 270),
              ),
              const Positioned(
                bottom: -130,
                left: -100,
                child: _GlowCircle(size: 330),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(34, 32, 34, 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3300162D),
                            blurRadius: 36,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 74,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: _lightBlue,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.asset(
                              'assets/images/Makk-Finsol-logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Welcome to Makk Finsol',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _text,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Sign in with the credentials provided by your administrator or use an approved Google account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, height: 1.5),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: _error,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: _error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          TextField(
                            controller: _emailController,
                            enabled: !_signingIn,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: const Icon(
                                Icons.alternate_email_rounded,
                              ),
                              filled: true,
                              fillColor: _lightBlue,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            enabled: !_signingIn,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) {
                              if (!_signingIn) _signInWithCredentials();
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              filled: true,
                              fillColor: _lightBlue,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _signingIn
                                  ? null
                                  : _signInWithCredentials,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _blue.withValues(
                                  alpha: 0.65,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _signingIn
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : const Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or',
                                  style: TextStyle(color: _muted),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _signingIn ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _text,
                                side: const BorderSide(
                                  color: Color(0xFFD0D5DD),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _GoogleMark(),
                                  SizedBox(width: 12),
                                  Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 16,
                                color: _muted,
                              ),
                              SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  'Only active emails in Employees can sign in',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _muted, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;

  const _GlowCircle({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.06),
    ),
  );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _AccessException implements Exception {
  final String message;

  const _AccessException(this.message);
}
