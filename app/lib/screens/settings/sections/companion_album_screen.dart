import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_card.dart';
import 'package:ruya/companion/companion_scene.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/companion/companion_sprite.dart';
import 'package:ruya/companion/room.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/services/feedback_service.dart';
import 'package:ruya/theme/app_style.dart';
import 'package:ruya/theme/ruya_card.dart';

/// Everything about the companions: the album of cards, their room and wardrobe.
class CompanionAlbumScreen extends StatelessWidget {
  const CompanionAlbumScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.companion_album),
          bottom: TabBar(tabs: [Tab(text: l10n.album_tab), Tab(text: l10n.room_tab), Tab(text: l10n.wardrobe_tab)]),
        ),
        body: const TabBarView(children: [_AlbumTab(), _RoomTab(), _WardrobeTab()]),
      ),
    );
  }
}

// ------------------------------------------------------------------ album

class _AlbumTab extends StatelessWidget {
  const _AlbumTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CompanionService>();
    final theme = Theme.of(context);

    return ListView(
      key: const ValueKey('albumList'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
          childAspectRatio: 0.58,
          children: [for (final c in Companion.values) CompanionCardTile(companion: c)],
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
    );
  }
}

/// A collectible card: the companion on the front, its short story on the back.
class CompanionCardTile extends StatefulWidget {
  const CompanionCardTile({super.key, required this.companion});

  final Companion companion;

  @override
  State<CompanionCardTile> createState() => _CompanionCardTileState();
}

class _CompanionCardTileState extends State<CompanionCardTile> {
  bool _back = false;

  Future<void> _rename(CompanionService service) async {
    final l10n = AppLocalizations.of(context)!;
    final companion = widget.companion;
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
    final companion = widget.companion;
    final unlocked = service.isUnlocked(companion);
    final selected = service.selected == companion;
    final number = (companion.index + 1).toString().padLeft(2, '0');

    if (!unlocked) {
      return RuyaCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: CompanionFrame(
                  companion: companion,
                  frame: CompanionFrames.idle0,
                  size: 112,
                  silhouette: scheme.outlineVariant,
                ),
              ),
            ),
            Text('?', style: displayText(context, size: 20)),
            const SizedBox(height: 4),
            Text(
              l10n.companion_arrivesIn(service.daysUntil(companion)),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );

    final front = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                companionDisplayName(service, companion, l10n),
                style: displayText(context, size: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: () => _rename(service),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined, size: 16, semanticLabel: l10n.companion_rename),
              ),
            ),
            Text(l10n.card_number(number), style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary)),
          ],
        ),
        Expanded(
          child: Center(
            child: CompanionSprite(
              companion: companion,
              mood: CompanionMood.calm,
              size: 104,
              accessory: service.wearing(companion),
            ),
          ),
        ),
        row(l10n.card_trait, companion.trait(l10n)),
        row(l10n.card_likes, companion.likes(l10n)),
        row(l10n.card_arrived, l10n.card_arrivedDay(companion.unlockDay)),
        const SizedBox(height: 6),
        selected
            ? Chip(
                avatar: const Icon(Icons.favorite, size: 16),
                label: Text(l10n.companion_selected),
                visualDensity: VisualDensity.compact,
              )
            : OutlinedButton(onPressed: () => service.select(companion), child: Text(l10n.companion_choose)),
      ],
    );

    final back = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(companionDisplayName(service, companion, l10n), style: displayText(context, size: 17)),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Text(companion.story(l10n), style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
          ),
        ),
        Text(companion.description(l10n), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );

    return Semantics(
      hint: l10n.card_flip,
      child: RuyaCard(
        color: selected ? scheme.primaryContainer : null,
        padding: const EdgeInsets.all(10),
        onTap: () => setState(() => _back = !_back),
        child: _back ? back : front,
      ),
    );
  }
}

// ------------------------------------------------------------------ room

class _RoomTab extends StatefulWidget {
  const _RoomTab();

  @override
  State<_RoomTab> createState() => _RoomTabState();
}

class _RoomTabState extends State<_RoomTab> {
  final _scene = GlobalKey<CompanionSceneState>();
  HideSpot? _hiding;
  String? _message;

  void _startHiding() {
    setState(() {
      _hiding = HideSpot.values[Random().nextInt(HideSpot.values.length)];
      _message = null;
    });
  }

  void _onSpot(HideSpot spot, AppLocalizations l10n) {
    if (_hiding == null) return;
    if (spot == _hiding) {
      context.read<FeedbackService>().celebrate();
      setState(() {
        _hiding = null;
        _message = l10n.hide_found;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scene.currentState?.celebrate());
    } else {
      context.read<FeedbackService>().select();
      setState(() => _message = l10n.hide_notHere);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CompanionService>();
    final theme = Theme.of(context);
    final name = companionDisplayName(service, service.selected, l10n);
    final playing = _hiding != null;

    return Column(
      children: [
        CompanionSceneBand(
          sceneKey: _scene,
          service: service,
          mood: CompanionMood.calm,
          hiding: _hiding,
          onPetTap: playing ? () => _onSpot(_hiding!, l10n) : () => _scene.currentState?.celebrate(),
          onSpotTap: playing ? (s) => _onSpot(s, l10n) : null,
        ),
        Expanded(
          child: ListView(
            key: const ValueKey('roomList'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(l10n.room_intro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              // the button comes first so it stays put while the message changes
              Row(
                children: [
                  playing
                      ? OutlinedButton(onPressed: () => setState(() => _hiding = null), child: Text(l10n.hide_stop))
                      : FilledButton.tonal(onPressed: _startHiding, child: Text(l10n.hide_play)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _message ?? (playing ? l10n.hide_where(name) : ''),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.room_together),
                subtitle: Text(l10n.room_togetherHint),
                value: service.showTogether,
                onChanged: service.unlocked.length > 1 ? service.setShowTogether : null,
              ),
              for (final slot in RoomSlot.values) _SlotPicker(slot: slot),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({required this.slot});

  final RoomSlot slot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CompanionService>();
    final theme = Theme.of(context);
    final current = service.roomItem(slot);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(slot.label(l10n), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PickTile(
                selected: current == null,
                label: l10n.room_empty,
                onTap: () => service.setRoomItem(slot, null),
                child: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
              ),
              for (final item in roomItemsFor(slot))
                _PickTile(
                  selected: current?.id == item.id,
                  locked: !service.isItemUnlocked(item),
                  label: service.isItemUnlocked(item) ? null : l10n.unlock_inDays(service.daysUntilItem(item)),
                  onTap: () => service.setRoomItem(slot, item),
                  child: Image.asset(item.asset, filterQuality: FilterQuality.none, fit: BoxFit.contain),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A square choice tile with an optional caption (room items, accessories).
class _PickTile extends StatelessWidget {
  const _PickTile({required this.child, required this.selected, required this.onTap, this.locked = false, this.label});

  final Widget child;
  final bool selected;
  final bool locked;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = RuyaStyle.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(style.pixel ? 8 : 16);
    return Semantics(
      selected: selected,
      button: true,
      enabled: !locked,
      child: InkWell(
        // the label is part of the target, small pictures are hard to hit
        onTap: locked ? null : onTap,
        borderRadius: radius,
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              Container(
                width: 84,
                height: 72,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
                  borderRadius: radius,
                  border: Border.all(
                    color: selected ? scheme.primary : (style.pixel ? style.ink : scheme.outlineVariant),
                    width: selected ? 3 : (style.pixel ? 2 : 1),
                  ),
                ),
                child: Opacity(opacity: locked ? 0.3 : 1, child: Center(child: child)),
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    label!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ wardrobe

class _WardrobeTab extends StatefulWidget {
  const _WardrobeTab();

  @override
  State<_WardrobeTab> createState() => _WardrobeTabState();
}

class _WardrobeTabState extends State<_WardrobeTab> {
  Companion? _who;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CompanionService>();
    final theme = Theme.of(context);
    final who = _who != null && service.isUnlocked(_who!) ? _who! : service.selected;
    final chosen = service.chosenAccessory(who);

    return ListView(
      key: const ValueKey('wardrobeList'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(l10n.wardrobe_intro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final c in service.unlocked)
              ChoiceChip(
                label: Text(companionDisplayName(service, c, l10n)),
                selected: c == who,
                onSelected: (_) => setState(() => _who = c),
              ),
          ],
        ),
        const SizedBox(height: 8),
        RuyaCard(
          color: theme.colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              CompanionSprite(companion: who, mood: CompanionMood.calm, size: 168, accessory: chosen),
              Text(
                chosen == null ? companionDisplayName(service, who, l10n) : '${companionDisplayName(service, who, l10n)} · ${chosen.label(l10n)}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            _PickTile(
              selected: chosen == null,
              label: l10n.accessory_none,
              onTap: () => service.setWearing(who, null),
              child: CompanionFrame(companion: who, frame: CompanionFrames.idle0, size: 60),
            ),
            for (final a in Accessory.values)
              _PickTile(
                selected: chosen == a,
                locked: !service.isAccessoryUnlocked(a),
                label: service.isAccessoryUnlocked(a)
                    ? a.label(l10n)
                    : (a == Accessory.party ? l10n.accessory_partyHint : l10n.unlock_inDays(service.daysUntilAccessory(a))),
                onTap: () => service.setWearing(who, a),
                child: CompanionFrame(companion: who, frame: CompanionFrames.idle0, size: 60, accessory: a),
              ),
          ],
        ),
      ],
    );
  }
}
