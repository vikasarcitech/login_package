abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

class AuthResetPrompt extends AuthState {
  final String email;
  AuthResetPrompt(this.email);
}

class AuthSignout extends AuthState {}

class AuthSignoutFailed extends AuthState {}

class AuthEmailUnverified extends AuthState {}

class DeleteAccountSuccess extends AuthState {}

class DeleteAccountFailure extends AuthState {
  final String message;
  DeleteAccountFailure(this.message);
}