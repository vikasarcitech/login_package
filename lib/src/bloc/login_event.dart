abstract class LoginEvent {}

class LoginSubmited extends LoginEvent {
  final String email;
  final String password;
  LoginSubmited({required this.email, required this.password});
}