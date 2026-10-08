import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/companion/companion_sprite.dart';
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
  final _sprite = GlobalKey<CompanionSpriteState>();
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
    HapticFeedback.lightImpact();
    _sprite.currentState?.celebrate();
    setState(() => _tapped = true);
  }

  void _maybeIntroduce(CompanionService service) {
    final arrivals = service.newArrivals;
    if (_arrivalShown || arrivals.isEmpty) return;
    _arrivalShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showCompanionArrival(context, arrivals.last);
      await service.markAnnounced(arrivals);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CompanionService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final companion = service.selected;
    final now = DateTime.now();
    final mood = companionMoodFor(now: now, todayLog: widget.todayLog);
    final seed = DateUtils.dateOnly(now).millisecondsSinceEpoch ~/ 86400000 + mood.index;
    final line = _tapped ? companionLine(l10n, CompanionMood.happy, seed) : companionLine(l10n, mood, seed);
    final name = companionDisplayName(service, companion, l10n);
    _maybeIntroduce(service);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Row(
          children: [
            CompanionSprite(
              key: _sprite,
              companion: companion,
              mood: mood,
              size: 128,
              onTap: _onTap,
              semanticLabel: l10n.companion_tapHint(name),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        topLeft: Radius.circular(4),
                      ),
                    ),
                    child: Text(line, style: theme.textTheme.bodyMedium),
                  ),
                ],
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
