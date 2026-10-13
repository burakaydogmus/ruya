import 'package:flutter/material.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_sprite.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:provider/provider.dart';
import 'package:ruya/home_widget/widget_content.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/services/widget_controller.dart';

/// Settings › Home screen widget: size, content, background and a live preview.
class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> with WidgetsBindingObserver {
  WidgetSize _size = WidgetSize.medium;
  bool _pinSupported = false;
  Map<WidgetSize, int> _installed = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLauncherState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // After the launcher's "add widget" dialog the app resumes: refresh counts.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadLauncherState();
  }

  Future<void> _loadLauncherState() async {
    final controller = context.read<WidgetController>();
    final pin = await controller.isPinSupported();
    final installed = await controller.installedCounts();
    if (!mounted) return;
    setState(() {
      _pinSupported = pin;
      _installed = installed;
    });
  }

  Future<void> _update(HomeWidgetOptions options) async {
    final settings = context.read<SettingsService>();
    final periods = context.read<PeriodService>();
    final controller = context.read<WidgetController>();
    final l10n = AppLocalizations.of(context)!;
    await settings.setWidgetOptions(options);
    await periods.refreshWidgets(l10n, controller);
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (!_pinSupported) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.widgetSettings_addManual)));
      return;
    }
    // Make sure the new widget has fresh content as soon as it appears.
    await context.read<PeriodService>().refreshWidgets(l10n, context.read<WidgetController>());
    if (!mounted) return;
    await context.read<WidgetController>().requestPin(_size);
    messenger.showSnackBar(SnackBar(content: Text(l10n.widgetSettings_addRequested)));
  }

  String _sizeName(AppLocalizations l10n, WidgetSize s) => switch (s) {
        WidgetSize.small => l10n.widgetSize_small,
        WidgetSize.medium => l10n.widgetSize_medium,
        WidgetSize.large => l10n.widgetSize_large,
        WidgetSize.sticker => l10n.widgetSize_sticker,
      };

  String _themeName(AppLocalizations l10n, WidgetTheme t) => switch (t) {
        WidgetTheme.system => l10n.widgetTheme_system,
        WidgetTheme.light => l10n.widgetTheme_light,
        WidgetTheme.dark => l10n.widgetTheme_dark,
        WidgetTheme.transparent => l10n.widgetTheme_transparent,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsService>();
    final periods = context.watch<PeriodService>();
    context.watch<CompanionService>(); // the preview shows the chosen companion
    final o = settings.widgetOptions;
    final payload = periods.buildWidgetPayload(l10n, options: o);
    final discrete = settings.isDiscreteModeEnabled;

    Widget toggle(String title, bool value, HomeWidgetOptions Function(bool) next,
            {bool enabled = true, String? subtitle}) =>
        SwitchListTile(
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: value,
          onChanged: enabled && !discrete ? (v) => _update(next(v)) : null,
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.widgetSettings_title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l10n.widgetSettings_intro, style: theme.textTheme.bodyMedium),
          ),
          _Header(l10n.widgetSettings_size),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<WidgetSize>(
              segments: [
                for (final s in WidgetSize.values)
                  ButtonSegment(value: s, label: Text(_sizeName(l10n, s), textAlign: TextAlign.center)),
              ],
              selected: {_size},
              showSelectedIcon: false,
              // The theme's onSecondaryContainer reads as disabled on the light scheme.
              style: SegmentedButton.styleFrom(
                selectedForegroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              onSelectionChanged: (s) => setState(() => _size = s.first),
            ),
          ),
          _Header(l10n.widgetSettings_preview),
          Center(child: WidgetPreview(size: _size, payload: payload)),
          if (_size == WidgetSize.sticker)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(l10n.widgetSettings_stickerNote, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FilledButton.icon(
              icon: const Icon(Icons.add_to_home_screen),
              label: Text(l10n.widgetSettings_add),
              onPressed: _add,
            ),
          ),
          if ((_installed[_size] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.widgetSettings_placed(_installed[_size]!),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (discrete)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHigh,
                child: ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text(l10n.widgetSettings_discreteNote),
                ),
              ),
            ),
          _Header(l10n.widgetSettings_content),
          toggle(l10n.widgetSettings_ring, o.showRing, (v) => o.copyWith(showRing: v)),
          toggle(l10n.widgetSettings_nextDate, o.showNextDate, (v) => o.copyWith(showNextDate: v)),
          toggle(l10n.widgetSettings_phase, o.showPhase, (v) => o.copyWith(showPhase: v)),
          toggle(l10n.widgetSettings_cycleDay, o.showCycleDay, (v) => o.copyWith(showCycleDay: v)),
          toggle(l10n.widgetSettings_fertility, o.showFertility, (v) => o.copyWith(showFertility: v)),
          toggle(l10n.widgetSettings_quickLog, o.showQuickLog, (v) => o.copyWith(showQuickLog: v)),
          toggle(l10n.widgetSettings_companion, o.showCompanion, (v) => o.copyWith(showCompanion: v),
              subtitle: l10n.widgetSettings_companionNote),
          _Header(l10n.widgetSettings_theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final t in WidgetTheme.values)
                  ChoiceChip(
                    label: Text(_themeName(l10n, t)),
                    selected: o.theme == t,
                    onSelected: (_) => _update(o.copyWith(theme: t)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(l10n.widgetSettings_privacyNote, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
}

/// Flutter mock of the Android widget layouts, driven by the same payload.
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({super.key, required this.size, required this.payload});

  final WidgetSize size;
  final WidgetPayload payload;

  static const Color accent = Color(0xFF7C5CD6);

  @override
  Widget build(BuildContext context) {
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark = switch (payload.theme) {
      WidgetTheme.dark => true,
      WidgetTheme.light => false,
      WidgetTheme.system => platformDark,
      WidgetTheme.transparent => true,
    };
    final transparent = payload.theme == WidgetTheme.transparent;
    final bg = transparent ? Colors.transparent : (dark ? const Color(0xFF221E2B) : Colors.white);
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final muted = dark ? Colors.white70 : const Color(0xFF6B6870);
    final day = payload.days.first;
    final lines = [day.phase, day.cycleDay, day.nextDate, day.fertility].whereType<String>().toList();

    Widget ring(double d, double fontSize) => SizedBox(
          width: d,
          height: d,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (payload.showRing)
                SizedBox(
                  width: d,
                  height: d,
                  child: CircularProgressIndicator(
                    value: day.max == 0 ? 0 : day.progress / day.max,
                    strokeWidth: d / 12,
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.18),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(day.big, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: fg)),
                  Text(day.unit, style: TextStyle(fontSize: fontSize * 0.36, color: muted)),
                ],
              ),
            ],
          ),
        );

    Widget quickLog() => payload.showQuickLog
        ? Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: accent, shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          )
        : const SizedBox.shrink();

    Widget text(String s, {bool head = false}) => Text(
          s,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: head ? fg : muted,
            fontSize: head ? 14 : 12,
            fontWeight: head ? FontWeight.w600 : FontWeight.normal,
          ),
        );

    final companion = payload.companion;
    // Same rule as PetArt.pose on the Android side.
    final hour = DateTime.now().hour;
    final petFrame = switch (day.petMood) {
      'comfort' => CompanionFrames.comfort0,
      'cozy' => CompanionFrames.cozy0,
      _ when hour >= 22 || hour < 6 => CompanionFrames.sleep0,
      _ when hour < 10 => CompanionFrames.happy0,
      _ when hour >= 18 => CompanionFrames.tea0,
      _ => CompanionFrames.idle0,
    };
    final accessory = Accessory.byName(day.petAccessory) ?? payload.accessory;
    Widget pet(double d, [Companion? c]) =>
        CompanionFrame(companion: c ?? companion!, frame: petFrame, size: d, accessory: accessory);

    if (size == WidgetSize.sticker) {
      final sticker = payload.sticker;
      return Container(
        width: 160,
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: [Color(0xFF3A3F5C), Color(0xFF6B5B95)]),
        ),
        child: sticker != null
            ? pet(144, sticker)
            : Icon(payload.neutral ? Icons.event_note : Icons.pets, size: 64, color: Colors.white70),
      );
    }

    final Widget child = switch (size) {
      WidgetSize.small => Stack(children: [
          Center(child: ring(120, 34)),
          Positioned(right: 0, bottom: 0, child: quickLog()),
        ]),
      WidgetSize.medium => Row(children: [
          if (companion != null) pet(116) else ring(116, 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day.headline.isNotEmpty) text(day.headline, head: true),
                for (final l in lines.take(3)) Padding(padding: const EdgeInsets.only(top: 4), child: text(l)),
              ],
            ),
          ),
          Align(alignment: Alignment.topRight, child: quickLog()),
        ]),
      WidgetSize.large => Column(children: [
          Row(children: [
            Text(payload.title, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
            const Spacer(),
            quickLog(),
          ]),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (companion != null) pet(116),
                ring(128, 36),
              ]),
              const SizedBox(height: 8),
              if (day.headline.isNotEmpty) text(day.headline, head: true),
              for (final l in lines) Padding(padding: const EdgeInsets.only(top: 3), child: text(l)),
            ]),
          ),
        ]),
      WidgetSize.sticker => const SizedBox.shrink(),
    };

    final (w, h) = switch (size) {
      WidgetSize.small => (160.0, 160.0),
      WidgetSize.medium => (330.0, 160.0),
      WidgetSize.large => (330.0, 300.0),
      WidgetSize.sticker => (160.0, 160.0),
    };
    return Container(
      width: w,
      height: h,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: transparent ? null : bg,
        borderRadius: BorderRadius.circular(22),
        border: transparent ? Border.all(color: Colors.grey.withValues(alpha: 0.5)) : null,
        gradient: transparent
            ? const LinearGradient(colors: [Color(0xFF3A3F5C), Color(0xFF6B5B95)])
            : null,
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26, offset: Offset(0, 2))],
      ),
      // Scale down instead of overflowing when the system font is large.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: w - 28,
          height: size == WidgetSize.small ? h - 28 : null,
          child: child,
        ),
      ),
    );
  }
}
