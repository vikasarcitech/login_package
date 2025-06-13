import 'package:firebase_auth/firebase_auth.dart';
import 'package:login_package/login_package.dart';

class FirebaseAuthService extends AuthService {
  FirebaseAuth _auth = FirebaseAuth.instance;
  @override
  Future<bool> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    }
    catch (e) {
      return false;
    }
  }
}