import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ruya/services/settings_service.dart';

/// Three small feedback gestures used the same way everywhere: save, select
/// and celebrate (plus the companion's own sound). Haptics are on by default,
/// sounds are off, and nothing plays in discrete mode.
class FeedbackService {
  FeedbackService(this._settings);

  final SettingsService _settings;
  static const MethodChannel _channel = MethodChannel('com.burakaydogmus.ruya/sfx');

  bool get _haptics => _settings.areHapticsEnabled;
  bool get _quiet => _settings.isDiscreteModeEnabled;

  void save() {
    if (_haptics) HapticFeedback.lightImpact();
    _play('save', _settings.areUiSoundsEnabled);
  }

  void select() {
    if (_haptics) HapticFeedback.selectionClick();
    _play('select', _settings.areUiSoundsEnabled);
  }

  void celebrate() {
    if (_haptics) HapticFeedback.mediumImpact();
    _play('celebrate', _settings.areUiSoundsEnabled);
  }

  /// The companion was petted.
  void pet() {
    if (_haptics) HapticFeedback.lightImpact();
    _play('pet', _settings.arePetSoundsEnabled);
  }

  /// Plays a sample regardless of the switches (settings preview buttons).
  void preview(String name) => _play(name, true, force: true);

  void _play(String name, bool enabled, {bool force = false}) {
    if (!enabled || (_quiet && !force)) return;
    _channel.invokeMethod<void>('play', {'name': name}).catchError((Object e) {
      debugPrint('sfx $name failed: $e');
    });
  }
}
