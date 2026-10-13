import 'dart:math';

import 'package:flutter/material.dart';

/// A short burst of pixel confetti over the whole screen. Used only for rare,
/// happy moments (a new friend, a special day, a new look) and skipped when
/// the system asks for reduced motion.
class Confetti {
  Confetti._();

  static void burst(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ConfettiLayer(onDone: () => entry.remove()));
    overlay.insert(entry);
  }
}

class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward().whenComplete(widget.onDone);
  final _pieces = <_Piece>[];

  @override
  void initState() {
    super.initState();
    final r = Random();
    const colors = [Color(0xFFF59E3A), Color(0xFFE0527F), Color(0xFF6ECFE0), Color(0xFF8F6FE6), Color(0xFFFFD84A), Color(0xFF7CC784)];
    for (var i = 0; i < 46; i++) {
      _pieces.add(_Piece(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.25,
        speed: 0.75 + r.nextDouble() * 0.6,
        drift: (r.nextDouble() - 0.5) * 0.25,
        size: 5.0 + r.nextInt(3) * 2,
        tall: r.nextBool(),
        color: colors[i % colors.length],
      ));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.size,
    required this.tall,
    required this.color,
  });

  final double x, delay, speed, drift, size;
  final bool tall;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (final p in pieces) {
      final local = ((t - p.delay) * p.speed).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + (size.height * 0.75 + 40) * Curves.easeIn.transform(local);
      final x = (p.x + p.drift * local) * size.width;
      // stepped positions keep the pixel feel
      final px = (x / 2).roundToDouble() * 2;
      final py = (y / 2).roundToDouble() * 2;
      paint.color = p.color.withValues(alpha: local > 0.8 ? (1 - local) * 5 : 1);
      canvas.drawRect(Rect.fromLTWH(px, py, p.size, p.tall ? p.size * 1.6 : p.size), paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
