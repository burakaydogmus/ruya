import 'package:flutter/material.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/companion/companion_sprite.dart';
import 'package:ruya/companion/room.dart';

/// Where the chosen companion can hide during hide and seek.
enum HideSpot { plant, light, window }

/// The companions' room: wall, floor, furniture in fixed slots and the
/// companion(s). Everything is laid out on a 160×100 pixel grid that is scaled
/// by a whole number of device pixels, so the art stays crisp.
class CompanionScene extends StatefulWidget {
  const CompanionScene({
    super.key,
    required this.service,
    required this.mood,
    this.night,
    this.hiding,
    this.onPetTap,
    this.onSpotTap,
  });

  final CompanionService service;

  /// Mood of the chosen companion; the others stay calm (or asleep at night).
  final CompanionMood mood;

  /// Force day or night; by default night follows the dark theme and the clock.
  final bool? night;

  /// When set, the chosen companion is tucked behind this spot.
  final HideSpot? hiding;
  final VoidCallback? onPetTap;

  /// Taps on the hide-and-seek spots (only wired while a round is on).
  final ValueChanged<HideSpot>? onSpotTap;

  static const double artWidth = 160;
  static const double artHeight = 100;
  static const double floorY = 76;

  static bool isNight(BuildContext context, [DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    return Theme.of(context).brightness == Brightness.dark || hour >= 21 || hour < 6;
  }

  @override
  State<CompanionScene> createState() => CompanionSceneState();
}

class CompanionSceneState extends State<CompanionScene> {
  final Map<Companion, GlobalKey<CompanionSpriteState>> _keys = {
    for (final c in Companion.values) c: GlobalKey<CompanionSpriteState>(),
  };

  /// Makes the chosen companion hop (used for taps and celebrations).
  void celebrate() => _keys[widget.service.selected]?.currentState?.celebrate();

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final night = widget.night ?? CompanionScene.isNight(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final k = (constraints.maxWidth * dpr / CompanionScene.artWidth).floor().clamp(1, 16);
        final u = k / dpr;

        Positioned at(double x, double y, double w, double h, Widget child) =>
            Positioned(left: x * u, top: y * u, width: w * u, height: h * u, child: child);
        Widget art(RoomItemArt item) => Image.asset(
              item.asset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              isAntiAlias: false,
              excludeFromSemantics: true,
            );
        Positioned bottomCenter(RoomItemArt i, double cx, double bottom) =>
            at(cx - i.width / 2, bottom - i.height, i.width.toDouble(), i.height.toDouble(), art(i));

        final window = service.roomItem(RoomSlot.window);
        final wall = service.roomItem(RoomSlot.wall);
        final light = service.roomItem(RoomSlot.light);
        final plant = service.roomItem(RoomSlot.plant);
        final rug = service.roomItem(RoomSlot.rug);
        final cushion = service.roomItem(RoomSlot.cushion);

        const windowX = 10.0, windowY = 8.0;
        final selected = service.selected;
        final hiding = widget.hiding;

        Widget pet(Companion c, CompanionMood mood, {VoidCallback? onTap}) => CompanionSprite(
              key: _keys[c],
              companion: c,
              mood: mood,
              size: 64 * u,
              exact: true,
              accessory: service.wearing(c),
              onTap: onTap ?? () => _keys[c]?.currentState?.celebrate(),
            );
        Positioned petAt(Companion c, double cx, double feet, CompanionMood mood, {VoidCallback? onTap}) =>
            at(cx - 32, feet - 60, 64, 64, pet(c, mood, onTap: onTap));
        Positioned spot(HideSpot s, double x, double y, double w, double h) => at(
              x, y, w, h,
              GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => widget.onSpotTap?.call(s)),
            );

        // Who stands where: the chosen companion in the middle and in front.
        final others = service.showTogether && hiding == null
            ? [for (final c in service.unlocked) if (c != selected) c]
            : const <Companion>[];
        final restMood = night ? CompanionMood.sleepy : CompanionMood.calm;
        final spacing = others.isEmpty ? 0.0 : (124 / others.length).clamp(18.0, 30.0);
        final placed = <(Companion, double)>[
          for (var i = 0; i < others.length; i++)
            (others[i], 80 + spacing * ((i ~/ 2) + 1) * (i.isEven ? -1 : 1)),
        ]..sort((a, b) => (b.$2 - 80).abs().compareTo((a.$2 - 80).abs()));

        final children = <Widget>[
          // wall and floor
          at(0, 0, 160, CompanionScene.floorY, ColoredBox(color: night ? const Color(0xFF1B1740) : const Color(0xFFE9DEFC))),
          at(0, CompanionScene.floorY, 160, 100 - CompanionScene.floorY,
              ColoredBox(color: night ? const Color(0xFF2A2360) : const Color(0xFFD8C3A5))),
          at(0, CompanionScene.floorY, 160, 2, ColoredBox(color: night ? const Color(0xFF15113A) : const Color(0xFFB79F82))),
          if (window != null) ...[
            at(windowX + 3, windowY + 3, window.width - 6, window.height - 6,
                CustomPaint(painter: _SkyPainter(night: night, unit: u))),
            if (hiding == HideSpot.window)
              at(windowX + 3, windowY + 3, window.width - 6, window.height - 6,
                  ClipRect(
                    child: OverflowBox(
                      maxWidth: 64 * u,
                      maxHeight: 64 * u,
                      alignment: Alignment.topCenter,
                      child: Transform.translate(offset: Offset(0, 8 * u), child: pet(selected, CompanionMood.calm, onTap: widget.onPetTap)),
                    ),
                  )),
            at(windowX, windowY, window.width.toDouble(), window.height.toDouble(), art(window)),
          ],
          if (wall != null) at(120 - wall.width / 2, 28 - wall.height / 2, wall.width.toDouble(), wall.height.toDouble(), art(wall)),
          if (light != null && light.id == 'lights') at(5, 1, light.width.toDouble(), light.height.toDouble(), art(light)),
          if (rug != null) at(80 - rug.width / 2, 90 - rug.height / 2, rug.width.toDouble(), rug.height.toDouble(), art(rug)),
          if (hiding == HideSpot.plant) petAt(selected, 24, 90, CompanionMood.calm, onTap: widget.onPetTap),
          if (hiding == HideSpot.light) petAt(selected, 138, 90, CompanionMood.calm, onTap: widget.onPetTap),
          if (light != null && light.id != 'lights') ...[
            if (night)
              at(148 - 22, 90 - light.height + 6 - 22, 44, 44,
                  const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFE27A)))),
            bottomCenter(light, 148, 90),
          ],
          if (plant != null) bottomCenter(plant, 13, 92),
          for (final (c, x) in placed) petAt(c, x, 90, restMood),
          if (cushion != null) bottomCenter(cushion, 80, 98),
          if (hiding == null) petAt(selected, 80, 94, widget.mood, onTap: widget.onPetTap),
          if (widget.onSpotTap != null) ...[
            spot(HideSpot.plant, 0, 44, 44, 56),
            spot(HideSpot.light, 118, 40, 42, 60),
            spot(HideSpot.window, windowX, windowY, 52, 50),
          ],
        ];

        return SizedBox(
          width: CompanionScene.artWidth * u,
          height: CompanionScene.artHeight * u,
          child: ClipRect(child: Stack(clipBehavior: Clip.none, children: children)),
        );
      },
    );
  }
}

/// Sky seen through the window: a cloud by day, moon and stars at night.
class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.night, required this.unit});

  final bool night;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    canvas.drawRect(Offset.zero & size, paint..color = night ? const Color(0xFF1D1848) : const Color(0xFFBFE7FF));
    void px(double x, double y, double w, double h, Color c) =>
        canvas.drawRect(Rect.fromLTWH(x * unit, y * unit, w * unit, h * unit), paint..color = c);
    if (night) {
      for (final (x, y) in const [(4.0, 6.0), (12.0, 22.0), (20.0, 4.0), (8.0, 30.0), (30.0, 28.0), (26.0, 14.0)]) {
        px(x, y, 1, 1, Colors.white);
      }
      const moon = Color(0xFFFFE9A0);
      for (final (x, y, w) in const [(28.0, 5.0, 3.0), (27.0, 6.0, 3.0), (26.0, 7.0, 3.0), (26.0, 8.0, 3.0), (26.0, 9.0, 3.0), (27.0, 10.0, 3.0), (28.0, 11.0, 3.0)]) {
        px(x, y, w, 1, moon);
      }
    } else {
      const cloud = Colors.white;
      px(8, 10, 12, 3, cloud);
      px(10, 8, 6, 2, cloud);
      px(22, 22, 10, 3, cloud);
      px(24, 20, 5, 2, cloud);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.night != night || old.unit != unit;
}

/// The scene centred on a full-width band whose wall and floor continue to the
/// edges, so it fills a card of any width.
class CompanionSceneBand extends StatelessWidget {
  const CompanionSceneBand({
    super.key,
    required this.service,
    required this.mood,
    this.sceneKey,
    this.night,
    this.hiding,
    this.onPetTap,
    this.onSpotTap,
  });

  final CompanionService service;
  final CompanionMood mood;
  final GlobalKey<CompanionSceneState>? sceneKey;
  final bool? night;
  final HideSpot? hiding;
  final VoidCallback? onPetTap;
  final ValueChanged<HideSpot>? onSpotTap;

  @override
  Widget build(BuildContext context) {
    final isNight = night ?? CompanionScene.isNight(context);
    const split = CompanionScene.floorY / CompanionScene.artHeight;
    final wall = isNight ? const Color(0xFF1B1740) : const Color(0xFFE9DEFC);
    final floor = isNight ? const Color(0xFF2A2360) : const Color(0xFFD8C3A5);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [wall, wall, floor, floor],
          stops: const [0, split, split, 1],
        ),
      ),
      child: Center(
        child: CompanionScene(
          key: sceneKey,
          service: service,
          mood: mood,
          night: isNight,
          hiding: hiding,
          onPetTap: onPetTap,
          onSpotTap: onSpotTap,
        ),
      ),
    );
  }
}
