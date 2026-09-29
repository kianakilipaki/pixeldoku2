import 'package:pixeldoku/models/theme_catalog.dart';
import 'package:pixeldoku/state/app_state.dart';

enum TitleCategory {
  theme,
  level,
  perfectRun,
  speed,
  hint,
  collection,
  secret,
  prestige,
}

enum TitleRuleType {
  always,
  themeUnlocked,
  level,
  statistic,
  allThemes,
  allProfilePictures,
}

class PlayerTitle {
  const PlayerTitle({
    required this.name,
    required this.category,
    required this.unlockText,
    required this.ruleType,
    this.themeId,
    this.requiredLevel = 0,
    this.statKey,
    this.statValue = 0,
  });

  final String name;
  final TitleCategory category;
  final String unlockText;
  final TitleRuleType ruleType;
  final String? themeId;
  final int requiredLevel;
  final String? statKey;
  final int statValue;

  bool isUnlocked(AppState appState) {
    return switch (ruleType) {
      TitleRuleType.always => true,
      TitleRuleType.themeUnlocked =>
        themeId != null &&
            appState.unlockedThemes.contains(themeId) &&
            appState.completedPuzzlesForTheme(themeId!) >=
                TitleCatalog.themeTitleCompletionRequirement(this),
      TitleRuleType.level => appState.currentLevel >= requiredLevel,
      TitleRuleType.statistic => _statValue(appState) >= statValue,
      TitleRuleType.allThemes =>
        appState.unlockedThemes.length >= ThemeCatalog.themes.length,
      TitleRuleType.allProfilePictures =>
        appState.unlockedProfilePictures.length >=
            ThemeCatalog.allProfileAssets.length,
    };
  }

  int _statValue(AppState appState) {
    if (statKey == 'themes_unlocked') {
      final stored = appState.statistics[statKey] ?? 0;
      return stored is int && stored > appState.unlockedThemes.length
          ? stored
          : appState.unlockedThemes.length;
    }
    if (statKey == 'profile_pictures_unlocked') {
      final stored = appState.statistics[statKey] ?? 0;
      return stored is int && stored > appState.unlockedProfilePictures.length
          ? stored
          : appState.unlockedProfilePictures.length;
    }

    final value = appState.statistics[statKey] ?? 0;
    return value is int ? value : 0;
  }
}

class TitleCatalog {
  static const defaultTitle = 'New Explorer';

  static const titles = <PlayerTitle>[
    PlayerTitle(
      name: 'Monthly Champion',
      category: TitleCategory.prestige,
      unlockText: 'Win a monthly competition',
      ruleType: TitleRuleType.statistic,
      statKey: 'monthly_championships',
      statValue: 1,
    ),
    PlayerTitle(
      name: 'New Explorer',
      category: TitleCategory.level,
      unlockText: 'Starting title',
      ruleType: TitleRuleType.always,
    ),
    PlayerTitle(
      name: 'Hatchling',
      category: TitleCategory.theme,
      unlockText: 'Unlock Birds',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'birds',
    ),
    PlayerTitle(
      name: 'Feather Finder',
      category: TitleCategory.theme,
      unlockText: 'Unlock Birds',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'birds',
    ),
    PlayerTitle(
      name: 'Skywatcher',
      category: TitleCategory.theme,
      unlockText: 'Unlock Birds',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'birds',
    ),
    PlayerTitle(
      name: 'Wingmaster',
      category: TitleCategory.theme,
      unlockText: 'Unlock Birds',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'birds',
    ),
    PlayerTitle(
      name: 'Lord of the Flock',
      category: TitleCategory.theme,
      unlockText: 'Unlock Birds',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'birds',
    ),
    PlayerTitle(
      name: 'Pup Pal',
      category: TitleCategory.theme,
      unlockText: 'Unlock Dogs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'dogs',
    ),
    PlayerTitle(
      name: 'Pack Member',
      category: TitleCategory.theme,
      unlockText: 'Unlock Dogs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'dogs',
    ),
    PlayerTitle(
      name: 'Alpha Hound',
      category: TitleCategory.theme,
      unlockText: 'Unlock Dogs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'dogs',
    ),
    PlayerTitle(
      name: 'Pack Leader',
      category: TitleCategory.theme,
      unlockText: 'Unlock Dogs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'dogs',
    ),
    PlayerTitle(
      name: 'Canine Champion',
      category: TitleCategory.theme,
      unlockText: 'Unlock Dogs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'dogs',
    ),
    PlayerTitle(
      name: 'Curious Kitten',
      category: TitleCategory.theme,
      unlockText: 'Unlock Cats',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'cats',
    ),
    PlayerTitle(
      name: 'Midnight Prowler',
      category: TitleCategory.theme,
      unlockText: 'Unlock Cats',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'cats',
    ),
    PlayerTitle(
      name: 'Nine-Lives Solver',
      category: TitleCategory.theme,
      unlockText: 'Unlock Cats',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'cats',
    ),
    PlayerTitle(
      name: 'Feline Mystic',
      category: TitleCategory.theme,
      unlockText: 'Unlock Cats',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'cats',
    ),
    PlayerTitle(
      name: 'Cat Monarch',
      category: TitleCategory.theme,
      unlockText: 'Unlock Cats',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'cats',
    ),
    PlayerTitle(
      name: 'Beetle Scout',
      category: TitleCategory.theme,
      unlockText: 'Unlock Bugs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'bugs',
    ),
    PlayerTitle(
      name: 'Hive Helper',
      category: TitleCategory.theme,
      unlockText: 'Unlock Bugs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'bugs',
    ),
    PlayerTitle(
      name: 'Swarm Tamer',
      category: TitleCategory.theme,
      unlockText: 'Unlock Bugs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'bugs',
    ),
    PlayerTitle(
      name: 'Insect Whisperer',
      category: TitleCategory.theme,
      unlockText: 'Unlock Bugs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'bugs',
    ),
    PlayerTitle(
      name: 'Queen of the Hive',
      category: TitleCategory.theme,
      unlockText: 'Unlock Bugs',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'bugs',
    ),
    PlayerTitle(
      name: 'Pond Hopper',
      category: TitleCategory.theme,
      unlockText: 'Unlock Fish',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'fish',
    ),
    PlayerTitle(
      name: 'River Swimmer',
      category: TitleCategory.theme,
      unlockText: 'Unlock Fish',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'fish',
    ),
    PlayerTitle(
      name: 'Deep Diver',
      category: TitleCategory.theme,
      unlockText: 'Unlock Fish',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'fish',
    ),
    PlayerTitle(
      name: 'Ocean Explorer',
      category: TitleCategory.theme,
      unlockText: 'Unlock Fish',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'fish',
    ),
    PlayerTitle(
      name: 'Leviathan Hunter',
      category: TitleCategory.theme,
      unlockText: 'Unlock Fish',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'fish',
    ),
    PlayerTitle(
      name: 'Marsh Walker',
      category: TitleCategory.theme,
      unlockText: 'Unlock Swamp',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'swamp',
    ),
    PlayerTitle(
      name: 'Gator Tracker',
      category: TitleCategory.theme,
      unlockText: 'Unlock Swamp',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'swamp',
    ),
    PlayerTitle(
      name: 'Bayou Explorer',
      category: TitleCategory.theme,
      unlockText: 'Unlock Swamp',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'swamp',
    ),
    PlayerTitle(
      name: 'Swamp Keeper',
      category: TitleCategory.theme,
      unlockText: 'Unlock Swamp',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'swamp',
    ),
    PlayerTitle(
      name: 'Swamp Sovereign',
      category: TitleCategory.theme,
      unlockText: 'Unlock Swamp',
      ruleType: TitleRuleType.themeUnlocked,
      themeId: 'swamp',
    ),
    PlayerTitle(
      name: 'Woodland Wanderer',
      category: TitleCategory.level,
      unlockText: 'Reach level 10',
      ruleType: TitleRuleType.level,
      requiredLevel: 10,
    ),
    PlayerTitle(
      name: 'Forest Guardian',
      category: TitleCategory.level,
      unlockText: 'Reach level 50',
      ruleType: TitleRuleType.level,
      requiredLevel: 50,
    ),
    PlayerTitle(
      name: 'Beginner Explorer',
      category: TitleCategory.level,
      unlockText: 'Reach level 10',
      ruleType: TitleRuleType.level,
      requiredLevel: 10,
    ),
    PlayerTitle(
      name: 'Puzzle Adventurer',
      category: TitleCategory.level,
      unlockText: 'Reach level 25',
      ruleType: TitleRuleType.level,
      requiredLevel: 25,
    ),
    PlayerTitle(
      name: 'Sudoku Ranger',
      category: TitleCategory.level,
      unlockText: 'Reach level 50',
      ruleType: TitleRuleType.level,
      requiredLevel: 50,
    ),
    PlayerTitle(
      name: 'Puzzle Veteran',
      category: TitleCategory.level,
      unlockText: 'Reach level 100',
      ruleType: TitleRuleType.level,
      requiredLevel: 100,
    ),
    PlayerTitle(
      name: 'Grand Explorer',
      category: TitleCategory.level,
      unlockText: 'Reach level 250',
      ruleType: TitleRuleType.level,
      requiredLevel: 250,
    ),
    PlayerTitle(
      name: 'Pixel Legend',
      category: TitleCategory.level,
      unlockText: 'Reach level 500',
      ruleType: TitleRuleType.level,
      requiredLevel: 500,
    ),
    PlayerTitle(
      name: 'Careful Thinker',
      category: TitleCategory.perfectRun,
      unlockText: 'Complete 1 perfect run',
      ruleType: TitleRuleType.statistic,
      statKey: 'perfect_runs',
      statValue: 1,
    ),
    PlayerTitle(
      name: 'Flawless Solver',
      category: TitleCategory.perfectRun,
      unlockText: 'Complete 5 perfect runs',
      ruleType: TitleRuleType.statistic,
      statKey: 'perfect_runs',
      statValue: 5,
    ),
    PlayerTitle(
      name: 'Precision Master',
      category: TitleCategory.perfectRun,
      unlockText: 'Complete 10 perfect runs',
      ruleType: TitleRuleType.statistic,
      statKey: 'perfect_runs',
      statValue: 10,
    ),
    PlayerTitle(
      name: 'Perfect Predator',
      category: TitleCategory.perfectRun,
      unlockText: 'Complete 20 perfect runs',
      ruleType: TitleRuleType.statistic,
      statKey: 'perfect_runs',
      statValue: 20,
    ),
    PlayerTitle(
      name: 'Sudoku Sage',
      category: TitleCategory.perfectRun,
      unlockText: 'Complete 50 perfect runs',
      ruleType: TitleRuleType.statistic,
      statKey: 'perfect_runs',
      statValue: 50,
    ),
    PlayerTitle(
      name: 'Swift Paw',
      category: TitleCategory.speed,
      unlockText: 'Complete 1 speed run',
      ruleType: TitleRuleType.statistic,
      statKey: 'speed_runs',
      statValue: 1,
    ),
    PlayerTitle(
      name: 'Quick Thinker',
      category: TitleCategory.speed,
      unlockText: 'Complete 5 speed runs',
      ruleType: TitleRuleType.statistic,
      statKey: 'speed_runs',
      statValue: 5,
    ),
    PlayerTitle(
      name: 'Lightning Solver',
      category: TitleCategory.speed,
      unlockText: 'Complete 10 speed runs',
      ruleType: TitleRuleType.statistic,
      statKey: 'speed_runs',
      statValue: 10,
    ),
    PlayerTitle(
      name: 'Speed Demon',
      category: TitleCategory.speed,
      unlockText: 'Complete 20 speed runs',
      ruleType: TitleRuleType.statistic,
      statKey: 'speed_runs',
      statValue: 20,
    ),
    PlayerTitle(
      name: 'Time Bender',
      category: TitleCategory.speed,
      unlockText: 'Complete 50 speed runs',
      ruleType: TitleRuleType.statistic,
      statKey: 'speed_runs',
      statValue: 50,
    ),
    PlayerTitle(
      name: 'Curious Student',
      category: TitleCategory.hint,
      unlockText: 'Use 10 hints',
      ruleType: TitleRuleType.statistic,
      statKey: 'hints_used',
      statValue: 10,
    ),
    PlayerTitle(
      name: 'Seeker of Wisdom',
      category: TitleCategory.hint,
      unlockText: 'Use 50 hints',
      ruleType: TitleRuleType.statistic,
      statKey: 'hints_used',
      statValue: 50,
    ),
    PlayerTitle(
      name: 'Guided Explorer',
      category: TitleCategory.hint,
      unlockText: 'Use 100 hints',
      ruleType: TitleRuleType.statistic,
      statKey: 'hints_used',
      statValue: 100,
    ),
    PlayerTitle(
      name: 'Independent Mind',
      category: TitleCategory.hint,
      unlockText: 'Complete 5 levels with no hints',
      ruleType: TitleRuleType.statistic,
      statKey: 'no_hint_wins',
      statValue: 5,
    ),
    PlayerTitle(
      name: 'Sharp Instincts',
      category: TitleCategory.hint,
      unlockText: 'Complete 20 levels with no hints',
      ruleType: TitleRuleType.statistic,
      statKey: 'no_hint_wins',
      statValue: 20,
    ),
    PlayerTitle(
      name: 'Self-Made Genius',
      category: TitleCategory.hint,
      unlockText: 'Complete 50 levels with no hints',
      ruleType: TitleRuleType.statistic,
      statKey: 'no_hint_wins',
      statValue: 50,
    ),
    PlayerTitle(
      name: 'Theme Collector',
      category: TitleCategory.collection,
      unlockText: 'Unlock 2 themes',
      ruleType: TitleRuleType.statistic,
      statKey: 'themes_unlocked',
      statValue: 2,
    ),
    PlayerTitle(
      name: 'Animal Enthusiast',
      category: TitleCategory.collection,
      unlockText: 'Unlock 3 themes',
      ruleType: TitleRuleType.statistic,
      statKey: 'themes_unlocked',
      statValue: 3,
    ),
    PlayerTitle(
      name: 'Wildlife Expert',
      category: TitleCategory.collection,
      unlockText: 'Unlock 4 themes',
      ruleType: TitleRuleType.statistic,
      statKey: 'themes_unlocked',
      statValue: 4,
    ),
    PlayerTitle(
      name: 'Pixel Zoologist',
      category: TitleCategory.collection,
      unlockText: 'Unlock 5 themes',
      ruleType: TitleRuleType.statistic,
      statKey: 'themes_unlocked',
      statValue: 5,
    ),
    PlayerTitle(
      name: 'Master Collector',
      category: TitleCategory.collection,
      unlockText: 'Unlock every theme',
      ruleType: TitleRuleType.allThemes,
    ),
    PlayerTitle(
      name: 'Avatar Hunter',
      category: TitleCategory.collection,
      unlockText: 'Unlock 18 profile pictures',
      ruleType: TitleRuleType.statistic,
      statKey: 'profile_pictures_unlocked',
      statValue: 18,
    ),
    PlayerTitle(
      name: 'Icon Collector',
      category: TitleCategory.collection,
      unlockText: 'Unlock 27 profile pictures',
      ruleType: TitleRuleType.statistic,
      statKey: 'profile_pictures_unlocked',
      statValue: 27,
    ),
    PlayerTitle(
      name: 'Portrait Curator',
      category: TitleCategory.collection,
      unlockText: 'Unlock every profile picture',
      ruleType: TitleRuleType.allProfilePictures,
    ),
    PlayerTitle(
      name: 'Night Owl',
      category: TitleCategory.secret,
      unlockText: 'Play after midnight',
      ruleType: TitleRuleType.statistic,
      statKey: 'night_owl_plays',
      statValue: 1,
    ),
    PlayerTitle(
      name: 'Early Bird',
      category: TitleCategory.secret,
      unlockText: 'Play before 6 AM',
      ruleType: TitleRuleType.statistic,
      statKey: 'early_bird_plays',
      statValue: 1,
    ),
    PlayerTitle(
      name: 'Cat Napper',
      category: TitleCategory.secret,
      unlockText: 'Pause 50 times',
      ruleType: TitleRuleType.statistic,
      statKey: 'pauses',
      statValue: 50,
    ),
    PlayerTitle(
      name: 'Firefly Chaser',
      category: TitleCategory.secret,
      unlockText: 'Watch 100 ads',
      ruleType: TitleRuleType.statistic,
      statKey: 'ads_watched',
      statValue: 100,
    ),
    PlayerTitle(
      name: 'Lucky Paw',
      category: TitleCategory.secret,
      unlockText: 'Win with 1 heart remaining',
      ruleType: TitleRuleType.statistic,
      statKey: 'one_heart_wins',
      statValue: 1,
    ),
    PlayerTitle(
      name: 'Untouchable',
      category: TitleCategory.secret,
      unlockText: 'Complete 20 levels without mistakes',
      ruleType: TitleRuleType.statistic,
      statKey: 'no_mistake_wins',
      statValue: 20,
    ),
    PlayerTitle(
      name: 'Completionist',
      category: TitleCategory.secret,
      unlockText: 'Unlock everything',
      ruleType: TitleRuleType.allProfilePictures,
    ),
    PlayerTitle(
      name: 'Pixel Deity',
      category: TitleCategory.secret,
      unlockText: 'Reach level 500 and unlock all themes',
      ruleType: TitleRuleType.level,
      requiredLevel: 500,
    ),
    PlayerTitle(
      name: 'Puzzle Hero',
      category: TitleCategory.prestige,
      unlockText: 'Reach level 100',
      ruleType: TitleRuleType.level,
      requiredLevel: 100,
    ),
    PlayerTitle(
      name: 'Animal Grandmaster',
      category: TitleCategory.prestige,
      unlockText: 'Unlock all themes',
      ruleType: TitleRuleType.allThemes,
    ),
    PlayerTitle(
      name: 'PixelDoku Champion',
      category: TitleCategory.prestige,
      unlockText: 'Reach level 250',
      ruleType: TitleRuleType.level,
      requiredLevel: 250,
    ),
    PlayerTitle(
      name: 'Keeper of the Wilds',
      category: TitleCategory.prestige,
      unlockText: 'Unlock every profile picture',
      ruleType: TitleRuleType.allProfilePictures,
    ),
    PlayerTitle(
      name: 'The Pixel Sage',
      category: TitleCategory.prestige,
      unlockText: 'Reach level 500',
      ruleType: TitleRuleType.level,
      requiredLevel: 500,
    ),
  ];

  static PlayerTitle byName(String name) {
    return titles.firstWhere(
      (title) => title.name == name,
      orElse: () => titles.first,
    );
  }

  static bool isUnlocked(String name, AppState appState) {
    return byName(name).isUnlocked(appState);
  }

  static String bestUnlockedTitle(AppState appState) {
    return titles.lastWhere((title) => title.isUnlocked(appState)).name;
  }

  static List<PlayerTitle> byCategory(TitleCategory category) {
    return titles.where((title) => title.category == category).toList();
  }

  /// The first title arrives with its theme; each later title needs one more
  /// completed puzzle using that theme.
  static int themeTitleCompletionRequirement(PlayerTitle title) {
    if (title.category != TitleCategory.theme || title.themeId == null) {
      return 0;
    }
    final themeTitles = titles
        .where(
          (candidate) =>
              candidate.category == TitleCategory.theme &&
              candidate.themeId == title.themeId,
        )
        .toList(growable: false);
    final index = themeTitles.indexOf(title);
    return index < 0 ? 0 : index;
  }

  static String categoryName(TitleCategory category) {
    return switch (category) {
      TitleCategory.theme => 'Theme Titles',
      TitleCategory.level => 'Level Titles',
      TitleCategory.perfectRun => 'Perfect Run Titles',
      TitleCategory.speed => 'Speed Titles',
      TitleCategory.hint => 'Hint Titles',
      TitleCategory.collection => 'Collection Titles',
      TitleCategory.secret => 'Secret Titles',
      TitleCategory.prestige => 'Prestige Titles',
    };
  }
}
