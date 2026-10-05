import 'package:flutter/material.dart';
import 'package:ruya/screens/gates/auth_gate.dart';
import 'package:ruya/screens/onboarding/onboarding_screen.dart';
import 'package:ruya/services/user_service.dart';
import 'package:provider/provider.dart';

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = context.watch<UserService>();

    if (userService.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (userService.user == null) {
      return const OnboardingScreen();
    }
    return const AuthGate(); 
  }
}