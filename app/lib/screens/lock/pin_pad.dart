import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ruya/security/pin_service.dart';

/// Numeric keypad with PIN dots. Does not depend on an Overlay, so it can be
/// rendered above the Navigator (lock screen) as well as inside a route.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.extraAction,
    this.submitLabel,
    this.minLength = PinService.minLength,
    this.maxLength = PinService.maxLength,
    this.autoSubmitLength,
  });

  /// Returns false to clear the entry (wrong PIN), true to keep it.
  final Future<bool> Function(String pin) onSubmit;
  final bool enabled;

  /// Optional button in the bottom-left slot (e.g. biometrics).
  final Widget? extraAction;
  final String? submitLabel;
  final int minLength;
  final int maxLength;

  /// Submit automatically once this many digits were entered.
  final int? autoSubmitLength;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _value = '';
  bool _busy = false;

  void clear() => setState(() => _value = '');

  Future<void> _submit() async {
    if (_busy || _value.length < widget.minLength) return;
    setState(() => _busy = true);
    final keep = await widget.onSubmit(_value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!keep) _value = '';
    });
  }

  void _press(String digit) {
    if (!widget.enabled || _busy || _value.length >= widget.maxLength) return;
    HapticFeedback.selectionClick();
    setState(() => _value += digit);
    if (widget.autoSubmitLength != null && _value.length == widget.autoSubmitLength) _submit();
  }

  void _backspace() {
    if (_busy || _value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dots = _value.length < widget.minLength ? widget.minLength : _value.length;

    Widget key(String label) => _PadButton(
          onTap: widget.enabled ? () => _press(label) : null,
          child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(dots, (i) {
              final filled = i < _value.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? scheme.primary : Colors.transparent,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: row.map(key).toList()),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 80, height: 72, child: Center(child: widget.extraAction)),
            key('0'),
            _PadButton(
              onTap: _value.isEmpty ? null : _backspace,
              child: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.autoSubmitLength == null)
          FilledButton(
            onPressed: widget.enabled && !_busy && _value.length >= widget.minLength ? _submit : null,
            style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.submitLabel ?? MaterialLocalizations.of(context).okButtonLabel),
          ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 72,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
