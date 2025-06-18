import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;

  AuthBloc(this.authService) : super(AuthInitial()) {
    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authService.login(event.email, event.password);
        emit(AuthSuccess());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password') {
          emit(AuthResetPrompt(event.email));
        } else {
          emit(AuthFailure(e.code ?? 'Login failed'));
        }
      }
    });

    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authService.register(event.email, event.password);
        emit(AuthSuccess());
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });
  }
}
