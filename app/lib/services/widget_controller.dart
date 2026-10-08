import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:ruya/home_widget/widget_content.dart';

/// Home screen widget sizes. Each size is its own Android AppWidgetProvider so
/// it appears separately in the launcher's widget picker and can be pinned.
enum WidgetSize {
  /// 2×2: countdown with ring.
  small('com.burakaydogmus.ruya.HomeScreenWidgetProvider'),

  /// 4×2: ring on the left, up to three lines of detail on the right.
  medium('com.burakaydogmus.ruya.RuyaWidgetMedium'),

  /// 4×3: header, large ring and every enabled line.
  large('com.burakaydogmus.ruya.RuyaWidgetLarge');

  const WidgetSize(this.provider);

  /// Fully qualified Android provider class. `small` keeps Menstrudel's class
  /// name so widgets placed by earlier versions keep working.
  final String provider;
}

/// Publishes widget content and talks to the launcher (pin, installed widgets).
class WidgetController {
  static const String daysKey = 'ruya_w_days';
  static const String titleKey = 'ruya_w_title';
  static const String staleKey = 'ruya_w_stale';
  static const String themeKey = 'ruya_w_theme';
  static const String ringKey = 'ruya_w_ring';
  static const String quickLogKey = 'ruya_w_quick';
  static const String petKey = 'ruya_w_pet';

  WidgetPayload? _last;

  /// Last published payload (used by the settings preview).
  WidgetPayload? get lastPayload => _last;

  Future<void> publish(WidgetPayload payload) async {
    _last = payload;
    try {
      await HomeWidget.saveWidgetData<String>(daysKey, payload.daysJson);
      await HomeWidget.saveWidgetData<String>(titleKey, payload.title);
      await HomeWidget.saveWidgetData<String>(staleKey, payload.staleText);
      await HomeWidget.saveWidgetData<String>(themeKey, payload.theme.name);
      await HomeWidget.saveWidgetData<bool>(ringKey, payload.showRing);
      await HomeWidget.saveWidgetData<bool>(quickLogKey, payload.showQuickLog);
      await HomeWidget.saveWidgetData<String>(petKey, payload.companion?.name ?? '');
      for (final size in WidgetSize.values) {
        await HomeWidget.updateWidget(qualifiedAndroidName: size.provider);
      }
      await _scheduleMidnightUpdates();
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }

  /// Redraws at every local midnight for the period covered by the payload,
  /// so the countdown changes even if the app is not opened.
  Future<void> _scheduleMidnightUpdates() async {
    final now = DateTime.now();
    final times = [
      for (var i = 1; i <= WidgetContentBuilder.daysAhead; i++)
        DateTime(now.year, now.month, now.day + i, 0, 1),
    ];
    for (final size in WidgetSize.values) {
      try {
        await HomeWidget.scheduleWidgetUpdates(times, qualifiedAndroidName: size.provider);
      } catch (e) {
        debugPrint('Scheduling widget updates for ${size.name} failed: $e');
      }
    }
  }

  Future<bool> isPinSupported() async {
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the launcher to place a widget of [size] on the home screen.
  Future<void> requestPin(WidgetSize size) =>
      HomeWidget.requestPinWidget(qualifiedAndroidName: size.provider);

  /// Number of placed widgets per size.
  Future<Map<WidgetSize, int>> installedCounts() async {
    final counts = {for (final s in WidgetSize.values) s: 0};
    try {
      for (final w in await HomeWidget.getInstalledWidgets()) {
        for (final s in WidgetSize.values) {
          if (w.androidClassName == s.provider) counts[s] = counts[s]! + 1;
        }
      }
    } catch (_) {}
    return counts;
  }
}
