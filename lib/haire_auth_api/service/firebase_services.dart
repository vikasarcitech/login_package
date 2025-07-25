import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirebaseServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<void> registerWithEmailPassword(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      // Fluttertoast.showToast(msg: "Please fill in both fields.");
      return;
    }
    try {
      print("@@@ Registering new user with email and password");
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print("Error : $e");
    }
  }
}