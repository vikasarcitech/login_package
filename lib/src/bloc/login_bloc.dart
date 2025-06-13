import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:login_package/src/bloc/login_event.dart';
import 'package:login_package/src/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(LoginInitial()) {
    on<LoginSubmited>((event, emit) {
      
    });
  }
}