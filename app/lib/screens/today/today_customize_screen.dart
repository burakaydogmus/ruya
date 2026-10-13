import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/services/settings_service.dart';

String todayTileLabel(TodayTile tile, AppLocalizations l10n) => switch (tile) {
      TodayTile.companion => l10n.tile_companion,
      TodayTile.countdown => l10n.tile_countdown,
      TodayTile.phase => l10n.tile_phase,
      TodayTile.bag => l10n.tile_bag,
      TodayTile.mood => l10n.tile_mood,
      TodayTile.pattern => l10n.tile_pattern,
      TodayTile.quickLog => l10n.tile_quickLog,
    };

IconData _tileIcon(TodayTile tile) => switch (tile) {
      TodayTile.companion => Icons.pets_outlined,
      TodayTile.countdown => Icons.water_drop_outlined,
      TodayTile.phase => Icons.brightness_2_outlined,
      TodayTile.bag => Icons.backpack_outlined,
      TodayTile.mood => Icons.mood_outlined,
      TodayTile.pattern => Icons.auto_awesome_outlined,
      TodayTile.quickLog => Icons.edit_note_outlined,
    };

/// Order and visibility of the Today tiles. The countdown always stays on:
/// it is the one thing the screen exists for.
class TodayCustomizeScreen extends StatelessWidget {
  const TodayCustomizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsService>();
    // Discrete mode never shows these, so it must not list them either.
    final discrete = settings.isDiscreteModeEnabled;
    bool listed(TodayTile t) => !(discrete && (t == TodayTile.companion || t == TodayTile.bag));
    final order = settings.todayTiles;
    final hidden = settings.hiddenTodayTiles;
    final shown = [for (final t in order) if (listed(t)) t];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.today_customize)),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        buildDefaultDragHandles: false,
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            l10n.today_customizeHint,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        itemCount: shown.length,
        onReorderItem: (from, to) {
          final next = List.of(shown);
          next.insert(to, next.removeAt(from));
          // tiles that are not listed keep their place at the end
          settings.setTodayTiles([...next, ...order.where((t) => !listed(t))], hidden);
        },
        itemBuilder: (context, i) {
          final tile = shown[i];
          final fixed = tile == TodayTile.countdown;
          return ListTile(
            key: ValueKey(tile),
            leading: ReorderableDragStartListener(
              index: i,
              child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator)),
            ),
            title: Row(
              children: [
                Icon(_tileIcon(tile), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(todayTileLabel(tile, l10n))),
              ],
            ),
            trailing: Switch(
              value: !hidden.contains(tile),
              onChanged: fixed
                  ? null
                  : (on) => settings.setTodayTiles(order, on ? ({...hidden}..remove(tile)) : {...hidden, tile}),
            ),
          );
        },
      ),
    );
  }
}
