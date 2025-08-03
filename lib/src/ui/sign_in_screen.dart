import 'package:ble/src/controllers/auth/auth_bloc.dart';
import 'package:ble/src/controllers/auth/auth_event.dart';
import 'package:ble/src/controllers/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _passwordVisible = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        builder: (context, state) => _createView(state),
        listener: (context, state) => _handleState(state),
      ),
    );
  }

  Widget _createView(AuthState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50.0),
                child: Image.asset('assets/images/logo.png'),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextFormField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Username',
                  ),
                  controller: _usernameController,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextFormField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        // Based on passwordVisible state choose the icon
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Theme.of(context).primaryColorDark,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                ),
              ),
              Visibility(
                visible: state.status == AuthStatus.unauthenticated,
                child: Text(state.errorMessage),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50), // NEW
                ),
                onPressed: _onLoginButtonPressed,
                child: const Text(
                  'Sign in',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _handleState(AuthState state) {
    switch (state.status) {
      case AuthStatus.uninitialised:
        EasyLoading.dismiss();
        break;
      case AuthStatus.authenticated:
        EasyLoading.dismiss();
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
        break;
      case AuthStatus.unauthenticated:
        EasyLoading.dismiss();
        break;
      case AuthStatus.loading:
        EasyLoading.show(
            maskType: EasyLoadingMaskType.black, dismissOnTap: false);
        break;
    }
  }

  _onLoginButtonPressed() {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) return;

    BlocProvider.of<AuthBloc>(context)
        .add(Login(username: username, password: password));
  }
}
