abstract class AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email, password;
  LoginRequested(this.email, this.password);
}

class RegisterRequested extends AuthEvent {
  final String email, password;
  RegisterRequested(this.email, this.password);
}

class SignoutRequested extends AuthEvent {}


class CheckEmailVerified extends AuthEvent {}

class ResendEmailVerification extends AuthEvent {}

class DeleteAccountRequested extends AuthEvent {}