import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/companion/companion_sprite.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/theme/app_style.dart';

/// A one-second hello when the app starts: the chosen companion hops and the
/// name appears. Discrete mode shows only the neutral name, and reduced motion
/// skips the screen entirely.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done || _timer != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _done = true;
      return;
    }
    _timer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _done ? widget.child : const _Splash(key: ValueKey('splash')),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final discrete = context.select<SettingsService, bool>((s) => s.isDiscreteModeEnabled);
    final companions = context.watch<CompanionService>();
    final theme = Theme.of(context);
    final style = RuyaStyle.of(context);
    final showPet = !discrete && companions.isLoaded && !companions.isHidden;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPet)
              CompanionSprite(
                companion: companions.selected,
                mood: CompanionMood.happy,
                size: 192,
                accessory: companions.wearing(companions.selected),
              ),
            const SizedBox(height: 12),
            Text(
              discrete ? l10n.discrete_appName : 'RUYA',
              style: TextStyle(
                fontFamily: style.displayFont,
                fontSize: discrete ? 28 : 44,
                fontWeight: FontWeight.w700,
                letterSpacing: discrete ? 0 : 3,
                color: discrete ? theme.colorScheme.onSurface : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
