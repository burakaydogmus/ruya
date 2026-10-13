import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya/theme/ruya_card.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_scene.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/companion/companion_sprite.dart';
import 'package:ruya/services/feedback_service.dart';
import 'package:ruya/services/user_service.dart';
import 'package:ruya/widgets/effects/confetti.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/screens/settings/sections/companion_album_screen.dart';

String companionDisplayName(CompanionService service, Companion c, AppLocalizations l10n) =>
    service.nickname(c) ?? c.defaultName(l10n);

/// The chosen companion on the Today screen with one gentle line.
class CompanionCard extends StatefulWidget {
  const CompanionCard({super.key, required this.todayLog});

  final LogDay? todayLog;

  @override
  State<CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<CompanionCard> with WidgetsBindingObserver {
  final _scene = GlobalKey<CompanionSceneState>();
  bool _tapped = false;
  bool _arrivalShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CompanionService>().refreshDay();
    }
  }

  void _onTap() {
    context.read<FeedbackService>().pet();
    _scene.currentState?.celebrate();
    setState(() => _tapped = true);
  }

  void _maybeIntroduce(CompanionService service) {
    final arrivals = service.newArrivals;
    final special = service.hasUnseenSpecialDay;
    if (_arrivalShown || (arrivals.isEmpty && !special)) return;
    _arrivalShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final feedback = context.read<FeedbackService>();
      if (special) {
        feedback.celebrate();
        Confetti.burst(context);
        await showSpecialDay(context, service);
        await service.markSpecialDaySeen();
      }
      if (arrivals.isNotEmpty && mounted) {
        feedback.celebrate();
        Confetti.burst(context);
        await showCompanionArrival(context, arrivals.last);
        await service.markAnnounced(arrivals);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CompanionService>();
    final theme = Theme.of(context);
    final companion = service.selected;
    final now = DateTime.now();
    final mood = companionMoodFor(now: now, todayLog: widget.todayLog);
    final seed = DateUtils.dateOnly(now).millisecondsSinceEpoch ~/ 86400000 + mood.index;
    final line = _tapped ? companionLine(l10n, CompanionMood.happy, seed) : companionLine(l10n, mood, seed);
    final name = companionDisplayName(service, companion, l10n);
    service.birthDate = context.watch<UserService>().user?.birthDate;
    _maybeIntroduce(service);

    return RuyaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CompanionSceneBand(
            sceneKey: _scene,
            service: service,
            mood: mood,
            onPetTap: _onTap,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: l10n.companion_tapHint(name),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(line, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.companion_album,
                  icon: const Icon(Icons.pets_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CompanionAlbumScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Introduces a companion that just arrived. Never shown in discrete mode.
Future<void> showCompanionArrival(BuildContext context, Companion companion) {
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<CompanionService>();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.companion_arrivedTitle, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompanionSprite(companion: companion, mood: CompanionMood.happy, size: 144),
          const SizedBox(height: 8),
          Text(companion.defaultName(l10n), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(companion.description(l10n), textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.companion_later)),
        FilledButton(
          onPressed: () {
            service.select(companion);
            Navigator.pop(ctx);
          },
          child: Text(l10n.companion_makeFriend),
        ),
      ],
    ),
  );
}

/// Greets the user on her birthday or on the anniversary of the first day.
Future<void> showSpecialDay(BuildContext context, CompanionService service) {
  final l10n = AppLocalizations.of(context)!;
  final companion = service.selected;
  final name = companionDisplayName(service, companion, l10n);
  final years = service.anniversaryYears;
  final birthday = service.isBirthday;
  final firstGift = !service.isAccessoryUnlocked(Accessory.party);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        birthday ? l10n.special_birthdayTitle : l10n.special_anniversaryTitle(years ?? 1),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompanionSprite(companion: companion, mood: CompanionMood.happy, size: 144, accessory: Accessory.party),
          const SizedBox(height: 8),
          Text(
            birthday ? l10n.special_birthdayBody(name) : l10n.special_anniversaryBody(name),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (firstGift)
            Text(l10n.special_gift, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodySmall),
        ],
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.special_open))],
    ),
  );
}
