import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user?.sendEmailVerification();
  }
  Future<void> sendEmailVerification() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && !user.emailVerified) {
    await user.sendEmailVerification();
  }}

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } on FirebaseException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  }

  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete(); // ⚠️ User must have recently reauthenticated
    } else {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No user currently signed in.',
      );
    }
  }
}
