import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/pain_level_enum.dart';

/// RUYA's companions. Each one arrives a fixed number of calendar days after
/// the app was first opened, never because of streaks or logging habits.
enum Companion {
  pamuk(0),
  fistik(7),
  tarcin(30),
  lokum(90),
  mehtap(180),
  boncuk(365);

  const Companion(this.unlockDay);

  final int unlockDay;

  String get asset => 'assets/pets/$name.png';

  /// Sheet with only the pixels an accessory changes, stacked on [asset].
  String overlayAsset(Accessory a) => 'assets/pets/acc/${name}_${a.name}.png';

  static Companion? byName(String? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }

  String defaultName(AppLocalizations l10n) => switch (this) {
        Companion.pamuk => l10n.companion_pamuk,
        Companion.fistik => l10n.companion_fistik,
        Companion.tarcin => l10n.companion_tarcin,
        Companion.lokum => l10n.companion_lokum,
        Companion.mehtap => l10n.companion_mehtap,
        Companion.boncuk => l10n.companion_boncuk,
      };

  String description(AppLocalizations l10n) => switch (this) {
        Companion.pamuk => l10n.companion_pamukAbout,
        Companion.fistik => l10n.companion_fistikAbout,
        Companion.tarcin => l10n.companion_tarcinAbout,
        Companion.lokum => l10n.companion_lokumAbout,
        Companion.mehtap => l10n.companion_mehtapAbout,
        Companion.boncuk => l10n.companion_boncukAbout,
      };

  String trait(AppLocalizations l10n) => switch (this) {
        Companion.pamuk => l10n.companion_pamukTrait,
        Companion.fistik => l10n.companion_fistikTrait,
        Companion.tarcin => l10n.companion_tarcinTrait,
        Companion.lokum => l10n.companion_lokumTrait,
        Companion.mehtap => l10n.companion_mehtapTrait,
        Companion.boncuk => l10n.companion_boncukTrait,
      };

  String likes(AppLocalizations l10n) => switch (this) {
        Companion.pamuk => l10n.companion_pamukLikes,
        Companion.fistik => l10n.companion_fistikLikes,
        Companion.tarcin => l10n.companion_tarcinLikes,
        Companion.lokum => l10n.companion_lokumLikes,
        Companion.mehtap => l10n.companion_mehtapLikes,
        Companion.boncuk => l10n.companion_boncukLikes,
      };

  /// Short story on the back of the companion's card.
  String story(AppLocalizations l10n) => switch (this) {
        Companion.pamuk => l10n.companion_pamukStory,
        Companion.fistik => l10n.companion_fistikStory,
        Companion.tarcin => l10n.companion_tarcinStory,
        Companion.lokum => l10n.companion_lokumStory,
        Companion.mehtap => l10n.companion_mehtapStory,
        Companion.boncuk => l10n.companion_boncukStory,
      };
}

/// Things a companion can wear. They arrive with the calendar, like the
/// companions themselves; the party hat comes with the first special day.
enum Accessory {
  bow(3),
  daisy(21),
  beanie(45),
  scarf(60),
  flower(100),
  party(365);

  const Accessory(this.unlockDay);

  final int unlockDay;

  static Accessory? byName(String? name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
        Accessory.bow => l10n.accessory_bow,
        Accessory.daisy => l10n.accessory_daisy,
        Accessory.beanie => l10n.accessory_beanie,
        Accessory.scarf => l10n.accessory_scarf,
        Accessory.flower => l10n.accessory_flower,
        Accessory.party => l10n.accessory_party,
      };
}

/// How the companion feels. Derived only from the time of day and what the
/// user logged today; it never depends on how often the app is opened.
enum CompanionMood { calm, sleepy, cozy, comfort, happy, tea }

/// Frame indices in the sprite sheets written by tool/pets/pets.py.
class CompanionFrames {
  CompanionFrames._();

  static const int count = 13;
  static const int idle0 = 0, idle1 = 1, blink = 2, sleep0 = 3, sleep1 = 4;
  static const int cozy0 = 5, cozy1 = 6, comfort0 = 7, comfort1 = 8, happy0 = 9, happy1 = 10;
  static const int tea0 = 11, tea1 = 12;

  /// (frame, milliseconds) loops per mood.
  static List<(int, int)> loop(CompanionMood mood) => switch (mood) {
        CompanionMood.calm => const [
            (idle0, 700), (idle1, 700), (idle0, 700), (idle1, 700),
            (idle0, 500), (blink, 140), (idle0, 600), (idle1, 700),
          ],
        CompanionMood.sleepy => const [(sleep0, 1100), (sleep1, 1100)],
        CompanionMood.cozy => const [(cozy0, 800), (cozy1, 800)],
        CompanionMood.comfort => const [(comfort0, 800), (comfort1, 800)],
        CompanionMood.happy => const [(happy0, 180), (happy1, 220)],
        CompanionMood.tea => const [(tea0, 900), (tea1, 900)],
      };

  /// The frame shown when animations are turned off.
  static int still(CompanionMood mood) => loop(mood).first.$1;
}

const _lowMoods = {Mood.sad, Mood.anxious, Mood.irritable, Mood.moodSwings, Mood.sensitive, Mood.tired};

CompanionMood companionMoodFor({required DateTime now, LogDay? todayLog}) {
  final log = todayLog;
  if (log != null) {
    final pain = log.painLevel ?? 0;
    if (pain >= PainLevel.moderate.index || log.moods.any(_lowMoods.contains)) {
      return CompanionMood.comfort;
    }
    if (log.flow != FlowRate.none) return CompanionMood.cozy;
  }
  if (now.hour >= 22 || now.hour < 6) return CompanionMood.sleepy;
  if (now.hour >= 18) return CompanionMood.tea;
  return CompanionMood.calm;
}

/// A fixed, reviewed line for the mood. The companion never talks about
/// predictions, dates or what is "normal".
String companionLine(AppLocalizations l10n, CompanionMood mood, int seed) {
  final lines = switch (mood) {
    CompanionMood.calm => [l10n.companion_lineCalm1, l10n.companion_lineCalm2, l10n.companion_lineCalm3],
    CompanionMood.sleepy => [l10n.companion_lineSleepy1, l10n.companion_lineSleepy2],
    CompanionMood.cozy => [l10n.companion_lineCozy1, l10n.companion_lineCozy2],
    CompanionMood.comfort => [l10n.companion_lineComfort1, l10n.companion_lineComfort2],
    CompanionMood.happy => [l10n.companion_lineHappy1, l10n.companion_lineHappy2],
    CompanionMood.tea => [l10n.companion_lineTea1, l10n.companion_lineTea2],
  };
  return lines[seed.abs() % lines.length];
}
