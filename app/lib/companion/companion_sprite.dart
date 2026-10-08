import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ruya/companion/companion.dart';

/// Draws one frame of a companion's sprite sheet with crisp pixels, scaled by
/// a whole number of device pixels so every art pixel has the same size.
class CompanionFrame extends StatelessWidget {
  const CompanionFrame({
    super.key,
    required this.companion,
    required this.frame,
    required this.size,
    this.silhouette,
  });

  final Companion companion;
  final int frame;

  /// Wanted logical size; the actual size snaps down to a whole pixel scale.
  final double size;

  /// Draw a flat silhouette in this colour (locked companions).
  final Color? silhouette;

  static const int artSize = 64;

  static double snappedSize(BuildContext context, double size) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final scale = (size * dpr / artSize).floor().clamp(1, 64);
    return scale * artSize / dpr;
  }

  @override
  Widget build(BuildContext context) {
    final s = snappedSize(context, size);
    Widget image = Image.asset(
      companion.asset,
      width: s * CompanionFrames.count,
      height: s,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    if (silhouette != null) {
      image = ColorFiltered(colorFilter: ColorFilter.mode(silhouette!, BlendMode.srcIn), child: image);
    }
    return SizedBox(
      width: s,
      height: s,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: s * CompanionFrames.count,
          child: Transform.translate(offset: Offset(-frame * s, 0), child: image),
        ),
      ),
    );
  }
}

/// Plays the mood's loop. A tap triggers a short happy hop. With reduced
/// motion (system setting) it shows a single still frame.
class CompanionSprite extends StatefulWidget {
  const CompanionSprite({
    super.key,
    required this.companion,
    required this.mood,
    required this.size,
    this.onTap,
    this.semanticLabel,
  });

  final Companion companion;
  final CompanionMood mood;
  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<CompanionSprite> createState() => CompanionSpriteState();
}

class CompanionSpriteState extends State<CompanionSprite> {
  Timer? _timer;
  int _step = 0;
  int _hops = 0;
  bool _animate = true;

  CompanionMood get _current => _hops > 0 ? CompanionMood.happy : widget.mood;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate != _animate) {
      _animate = animate;
      _restart();
    } else if (_timer == null && _animate) {
      _restart();
    }
  }

  @override
  void didUpdateWidget(CompanionSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood || oldWidget.companion != widget.companion) _restart();
  }

  /// Plays a short celebration (also used when a new friend arrives).
  void celebrate({int hops = 4}) {
    if (!_animate) return;
    _hops = hops * 2;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    _step = 0;
    if (!_animate) {
      _hops = 0;
      if (mounted) setState(() {});
      return;
    }
    _schedule();
  }

  void _schedule() {
    final loop = CompanionFrames.loop(_current);
    final ms = loop[_step % loop.length].$2;
    _timer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() {
        if (_hops > 0) {
          _hops--;
          _step = _hops == 0 ? 0 : _step + 1;
        } else {
          _step++;
        }
      });
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = _current;
    final loop = CompanionFrames.loop(mood);
    final frame = _animate ? loop[_step % loop.length].$1 : CompanionFrames.still(mood);
    final child = CompanionFrame(companion: widget.companion, frame: frame, size: widget.size);
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: GestureDetector(onTap: widget.onTap, behavior: HitTestBehavior.opaque, child: child),
    );
  }
}
