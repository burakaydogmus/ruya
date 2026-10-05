import 'package:flutter/material.dart';
import 'package:ruya/screens/main_screen.dart';

/// Entry point after onboarding.
///
/// Menstrudel asked for device authentication here on cold start only. RUYA
/// replaces that with [AppLockGate] (PIN + optional biometrics, re-locks after
/// the configured background timeout), which wraps the whole app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => const MainScreen();
}
