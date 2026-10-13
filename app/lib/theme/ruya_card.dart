import 'package:flutter/material.dart';
import 'package:ruya/theme/app_style.dart';

/// A card that follows the active pack: a chunky frame on a hard shadow in the
/// pixel pack, a soft rounded card elsewhere.
class RuyaCard extends StatelessWidget {
  const RuyaCard({super.key, required this.child, this.color, this.padding, this.onTap});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RuyaStyle.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.surfaceContainerLow;
    Widget content = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: BorderRadius.circular(style.pixel ? 6 : 18), child: content);
    }
    if (!style.pixel) {
      return Card(color: fill, clipBehavior: Clip.antiAlias, child: content);
    }
    return Padding(
      // room for the shadow so neighbouring cards do not touch it
      padding: const EdgeInsets.only(right: 3, bottom: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: style.ink, width: 2),
          boxShadow: [BoxShadow(color: style.ink, offset: const Offset(3, 3))],
        ),
        child: Padding(
          // keep the frame visible when the content is edge to edge
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Material(type: MaterialType.transparency, child: content),
          ),
        ),
      ),
    );
  }
}

/// Text in the pack's display face (pixel font in the pixel pack).
TextStyle displayText(BuildContext context, {double size = 28, Color? color, FontWeight weight = FontWeight.w800}) {
  final style = RuyaStyle.of(context);
  return TextStyle(
    fontFamily: style.displayFont,
    fontSize: size,
    height: 1.05,
    fontWeight: style.pixel ? FontWeight.w700 : weight,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );
}
