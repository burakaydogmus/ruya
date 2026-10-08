import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_card.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/companion/companion_sprite.dart';
import 'package:ruya/l10n/app_localizations.dart';

/// All companions: the ones that arrived and the ones still on their way.
class CompanionAlbumScreen extends StatelessWidget {
  const CompanionAlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CompanionService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.companion_album)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.companion_albumIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            l10n.companion_daysTogether(service.daysTogether),
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
            children: [for (final c in Companion.values) _CompanionTile(companion: c)],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.companion_showOnToday),
            value: !service.isHidden,
            onChanged: (v) => service.setHidden(!v),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.companion_privacyNote,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CompanionTile extends StatelessWidget {
  const _CompanionTile({required this.companion});

  final Companion companion;

  Future<void> _rename(BuildContext context, CompanionService service) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: companionDisplayName(service, companion, l10n));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.companion_rename),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: CompanionService.maxNameLength,
          decoration: InputDecoration(hintText: companion.defaultName(l10n)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: Text(l10n.companion_resetName)),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l10n.save)),
        ],
      ),
    );
    if (result != null) await service.rename(companion, result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CompanionService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unlocked = service.isUnlocked(companion);
    final selected = service.selected == companion;

    final Widget art = unlocked
        ? CompanionSprite(companion: companion, mood: CompanionMood.calm, size: 112)
        : CompanionFrame(
            companion: companion,
            frame: CompanionFrames.idle0,
            size: 112,
            silhouette: scheme.outlineVariant,
          );

    return Card(
      elevation: 0,
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: selected ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(child: Center(child: art)),
            if (unlocked) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      companionDisplayName(service, companion, l10n),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: l10n.companion_rename,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _rename(context, service),
                  ),
                ],
              ),
              Text(
                companion.description(l10n),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              selected
                  ? Chip(
                      avatar: const Icon(Icons.favorite, size: 16),
                      label: Text(l10n.companion_selected),
                      visualDensity: VisualDensity.compact,
                    )
                  : OutlinedButton(
                      onPressed: () => service.select(companion),
                      child: Text(l10n.companion_choose),
                    ),
            ] else ...[
              Text('?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                l10n.companion_arrivesIn(service.daysUntil(companion)),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
