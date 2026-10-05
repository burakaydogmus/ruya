import 'package:ruya/l10n/app_localizations.dart';

/// This class is a custom helper to build language selection dropdown.
class L10n {
  static final Map<String, String> nativeLanguageNames = {
    'en': 'English',
    'tr': 'Türkçe',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'cs': 'Čeština',
    'es': 'Español',
    'ru': 'русский',
    'th': 'ไทย'
  };

static Map<String, String> getLanguageOptions(AppLocalizations l10n) {
    return {
      'system': l10n.systemDefault,
      ...nativeLanguageNames, 
    };
  }
}