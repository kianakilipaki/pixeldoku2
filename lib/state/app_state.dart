import 'package:flutter/material.dart';
import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:pixeldoku/models/theme_catalog.dart';
import 'package:pixeldoku/models/title_catalog.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  static const int dailyBonusPoints = 250;
  static const int dailyCoinBonus = 50;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  User? user;

  int coins = 0;
  int currentLevel = 1;
  Map<String, dynamic> gameProgress = {};
  String name = 'Player';
  String profilePicture = ThemeCatalog.themes.first.profileAssets.first;
  int profilePictureBgColor = 0xFFEEC027;
  String playerTitle = TitleCatalog.defaultTitle;
  List<String> unlockedThemes = ['birds'];
  String activeTheme = 'birds';
  int hints = 10;
  bool musicOn = true;
  bool sfxOn = true;
  bool boardHighlightsOn = true;
  Map<String, dynamic> statistics = {};

  bool isLoading = true;
  bool isOfflineMode = true;
  String? loadError;
  bool _initialized = false;

  // -----------------------------
  // INIT USER
  // -----------------------------
  Future<void> init() async {
    if (_initialized) return;

    AppLogger.log('AppState.init start');
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      AppLogger.log('AppState.init loading local progress');
      await _loadLocalUserData();
      user = _authService.currentUser;
      isOfflineMode = _storageService.supabase == null;
      AppLogger.log(
        'AppState.init offlineMode=$isOfflineMode currentUser=${user?.id ?? "null"}',
      );
    } catch (error) {
      AppLogger.error('AppState.init failed', error);
      loadError = error.toString();
    } finally {
      isLoading = false;
      _initialized = true;
      notifyListeners();
      AppLogger.log('AppState.init finished loadError=${loadError ?? "none"}');
    }
  }

  // -----------------------------
  // RELOAD AFTER AUTH CHANGE
  // -----------------------------
  Future<void> reloadAfterAuthChange() async {
    AppLogger.log('AppState.reloadAfterAuthChange start');
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      await _loadLocalUserData();
      user = _authService.currentUser;
      isOfflineMode = _storageService.supabase == null;
      AppLogger.log(
        'AppState.reloadAfterAuthChange currentUser=${user?.id ?? "null"}',
      );

      if (user != null) {
        AppLogger.log(
          'AppState.reloadAfterAuthChange cloud profile load skipped user=${user!.id}',
        );
      }
    } catch (error) {
      AppLogger.error('AppState.reloadAfterAuthChange failed', error);
      loadError = error.toString();
    } finally {
      isLoading = false;
      _initialized = true;
      notifyListeners();
      AppLogger.log(
        'AppState.reloadAfterAuthChange finished loadError=${loadError ?? "none"}',
      );
    }
  }

  // -----------------------------
  // LOAD LOCAL USER DATA
  // -----------------------------
  Future<void> _loadLocalUserData() async {
    final progress = await _storageService.loadLocalUserProgress();
    _applyProgress(progress);
  }

  void _applyProgress(UserProgress progress) {
    coins = progress.coins;
    currentLevel = progress.currentLevel;
    gameProgress = progress.gameProgress;
    name = progress.name;
    profilePicture = progress.profilePicture;
    profilePictureBgColor = progress.profilePictureBgColor;
    unlockedThemes = _mergeUnlockedThemes(progress.unlockedThemes);
    activeTheme = unlockedThemes.contains(progress.activeTheme)
        ? progress.activeTheme
        : unlockedThemes.first;
    hints = progress.hints;
    musicOn = progress.musicOn;
    sfxOn = progress.sfxOn;
    boardHighlightsOn = progress.boardHighlightsOn;
    statistics = progress.statistics;
    playerTitle = TitleCatalog.isUnlocked(progress.playerTitle, this)
        ? progress.playerTitle
        : TitleCatalog.bestUnlockedTitle(this);
  }

  Future<void> _saveLocalProgress() async {
    await _storageService.saveLocalUserProgress(
      UserProgress(
        coins: coins,
        currentLevel: currentLevel,
        gameProgress: gameProgress,
        name: name,
        profilePicture: profilePicture,
        profilePictureBgColor: profilePictureBgColor,
        playerTitle: playerTitle,
        unlockedThemes: unlockedThemes,
        activeTheme: activeTheme,
        hints: hints,
        musicOn: musicOn,
        sfxOn: sfxOn,
        boardHighlightsOn: boardHighlightsOn,
        statistics: statistics,
      ),
    );
  }

  Future<void> _tryCloudUpdate(String property, Object value) async {
    if (isOfflineMode || user == null) return;

    try {
      await _storageService.updateUserData(user!.id, property, value);
    } catch (error, stackTrace) {
      AppLogger.error(
        'AppState cloud update failed property=$property',
        error,
        stackTrace,
      );
      isOfflineMode = true;
    }
  }

  // -----------------------------
  // UPDATE COINS
  // -----------------------------
  Future<void> addCoins(int amount) async {
    coins += amount;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('coins', coins);
  }

  // -----------------------------
  // UPDATE LEVEL
  // -----------------------------
  Future<void> setLevel(int level) async {
    currentLevel = level;
    await unlockThemesForLevel(level);
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('current_level', level);
  }

  Future<void> spendCoins(int amount) async {
    if (coins < amount) return;

    coins -= amount;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('coins', coins);
  }

  Future<void> addHints(int amount) async {
    hints += amount;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('hints', hints);
  }

  Future<bool> useHint() async {
    if (hints <= 0) return false;

    hints--;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('hints', hints);
    return true;
  }

  Future<void> setActiveTheme(String themeId) async {
    if (!unlockedThemes.contains(themeId)) return;

    activeTheme = themeId;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('active_theme', themeId);
  }

  Future<void> setProfilePicture(String asset) async {
    if (!unlockedProfilePictures.contains(asset)) return;

    profilePicture = asset;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('profile_picture', asset);
  }

  Future<void> setPlayerTitle(String value) async {
    if (!TitleCatalog.isUnlocked(value, this)) return;

    playerTitle = value;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('player_title', value);
  }

  Future<void> setProfilePictureBgColor(int value) async {
    profilePictureBgColor = value;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('profile_picture_bg_color', value);
  }

  Future<void> setPlayerName(String value) async {
    if (value.trim().isEmpty) return;

    name = value.trim();
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('name', name);
  }

  Future<void> setMusicOn(bool value) async {
    musicOn = value;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('music_on', value);
  }

  Future<void> setSfxOn(bool value) async {
    sfxOn = value;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('sfx_on', value);
  }

  Future<void> setBoardHighlightsOn(bool value) async {
    boardHighlightsOn = value;
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('board_highlights_on', value);
  }

  Future<void> recordLevelCompleted({
    required String difficulty,
    required bool reducedReward,
    required int mistakes,
    required int hintsUsed,
    required int elapsedSeconds,
    bool isDaily = false,
    String? dailyDateKey,
  }) async {
    final dailyResults = _dailyResults();
    final previousDailyTime = dailyDateKey == null
        ? null
        : dailyResults[dailyDateKey];
    final firstDailyCompletion = !isDaily || previousDailyTime == null;
    final countsTowardProgress = !isDaily || firstDailyCompletion;
    final completed = (statistics['levels_completed'] ?? 0) as int;
    final retryWins = (statistics['retry_wins'] ?? 0) as int;
    final perfectRuns = (statistics['perfect_runs'] ?? 0) as int;
    final noMistakeWins = (statistics['no_mistake_wins'] ?? 0) as int;
    final noHintWins = (statistics['no_hint_wins'] ?? 0) as int;
    final hintsUsedTotal = (statistics['hints_used'] ?? 0) as int;
    final speedRuns = (statistics['speed_runs'] ?? 0) as int;
    final oneHeartWins = (statistics['one_heart_wins'] ?? 0) as int;
    final themeCompletions = _themeCompletionCounts();
    if (countsTowardProgress) {
      themeCompletions[activeTheme] = (themeCompletions[activeTheme] ?? 0) + 1;
    }
    final isNoMistake = mistakes == 0;
    final isNoHint = hintsUsed == 0;
    final isSpeedRun = elapsedSeconds > 0 && elapsedSeconds <= 180;
    final wonWithOneHeart = mistakes == 2;
    final basePoints = pointsForDifficulty(difficulty);
    final pointsAwarded = countsTowardProgress
        ? basePoints + (isDaily ? dailyBonusPoints : 0)
        : 0;
    if (isDaily &&
        dailyDateKey != null &&
        elapsedSeconds > 0 &&
        (previousDailyTime == null || elapsedSeconds < previousDailyTime)) {
      dailyResults[dailyDateKey] = elapsedSeconds;
    }

    statistics = {
      ...statistics,
      'levels_completed': completed + (countsTowardProgress ? 1 : 0),
      'last_completed_difficulty': difficulty,
      'retry_wins': retryWins + (countsTowardProgress && reducedReward ? 1 : 0),
      'perfect_runs':
          perfectRuns +
          (countsTowardProgress && isNoMistake && isNoHint ? 1 : 0),
      'no_mistake_wins':
          noMistakeWins + (countsTowardProgress && isNoMistake ? 1 : 0),
      'no_hint_wins': noHintWins + (countsTowardProgress && isNoHint ? 1 : 0),
      'hints_used': hintsUsedTotal + (countsTowardProgress ? hintsUsed : 0),
      'speed_runs': speedRuns + (countsTowardProgress && isSpeedRun ? 1 : 0),
      'one_heart_wins':
          oneHeartWins + (countsTowardProgress && wonWithOneHeart ? 1 : 0),
      'theme_completions': themeCompletions,
      'themes_unlocked': unlockedThemes.length,
      'profile_pictures_unlocked': unlockedProfilePictures.length,
      'total_points': totalPoints + pointsAwarded,
      'daily_completions':
          dailyCompletions + (isDaily && firstDailyCompletion ? 1 : 0),
      'daily_results': dailyResults,
    };
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('statistics', statistics);
  }

  Future<void> unlockThemesForLevel(int level) async {
    final before = unlockedThemes.length;
    unlockedThemes = _mergeUnlockedThemes(unlockedThemes, level: level);
    final unlockedCount = unlockedThemes.length - before;

    if (unlockedCount > 0) {
      hints += unlockedCount * 10;
      await _saveLocalProgress();
      await _tryCloudUpdate('unlocked_themes', unlockedThemes);
      await _tryCloudUpdate('hints', hints);
    }
  }

  List<PixelDokuTheme> get availableThemes =>
      unlockedThemes.map(ThemeCatalog.byId).toList(growable: false);

  PixelDokuTheme get activeThemeData => ThemeCatalog.byId(activeTheme);

  /// Number of puzzles completed while [themeId] was the active theme.
  int completedPuzzlesForTheme(String themeId) {
    return _themeCompletionCounts()[themeId] ?? 0;
  }

  Map<String, int> _themeCompletionCounts() {
    final stored = statistics['theme_completions'];
    if (stored is! Map) return <String, int>{};

    return stored.map(
      (key, value) =>
          MapEntry(key.toString(), value is num ? value.toInt() : 0),
    );
  }

  List<String> get unlockedTitleNames => TitleCatalog.titles
      .where((title) => title.isUnlocked(this))
      .map((title) => title.name)
      .toList(growable: false);

  List<String> get allProfilePictures => ThemeCatalog.allProfileAssets;

  List<String> get unlockedProfilePictures {
    return availableThemes
        .expand((theme) => theme.profileAssets)
        .toList(growable: false);
  }

  int coinRewardForLevel({required String difficulty, required bool reduced}) {
    final baseReward = switch (difficulty) {
      'Easy' => 50,
      'Medium' => 75,
      'Hard' => 100,
      'Expert' => 150,
      _ => 175,
    };

    return reduced ? (baseReward / 2).floor() : baseReward;
  }

  int pointsForDifficulty(String difficulty) {
    return switch (difficulty) {
      'Easy' => 100,
      'Medium' => 175,
      'Hard' => 250,
      'Expert' => 400,
      _ => 500,
    };
  }

  int get totalPoints => _statInt('total_points');
  int get dailyCompletions => _statInt('daily_completions');

  bool hasCompletedDaily(String dateKey) => _dailyResults()[dateKey] != null;

  int? bestDailyTime(String dateKey) => _dailyResults()[dateKey];

  Future<void> submitDailyTime(String dateKey, int elapsedSeconds) async {
    if (user == null || isOfflineMode) return;
    try {
      await _storageService.submitDailyTime(dateKey, elapsedSeconds);
    } catch (error, stackTrace) {
      AppLogger.error('Daily leaderboard submission failed', error, stackTrace);
    }
  }

  int _statInt(String key) {
    final value = statistics[key];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  Map<String, int> _dailyResults() {
    final stored = statistics['daily_results'];
    if (stored is! Map) return <String, int>{};
    return stored.map(
      (key, value) => MapEntry(
        key.toString(),
        value is num ? value.toInt() : int.tryParse('$value') ?? 0,
      ),
    );
  }

  // -----------------------------
  // UPDATE GAME PROGRESS
  // -----------------------------
  Future<void> setGameProgress(Map<String, dynamic> progress) async {
    gameProgress = progress;
    notifyListeners();

    await _saveLocalProgress();
    if (!isOfflineMode && user != null) {
      try {
        await _storageService.updateSupabaseGameData(user!.id, progress);
      } catch (error, stackTrace) {
        AppLogger.error(
          'AppState cloud game progress update failed',
          error,
          stackTrace,
        );
        isOfflineMode = true;
      }
    }
  }

  List<String> _mergeUnlockedThemes(List<String> existing, {int? level}) {
    final ids = <String>{
      'birds',
      ...existing,
      ...ThemeCatalog.unlockedThemeIdsForLevel(level ?? currentLevel),
    };

    return ThemeCatalog.themes
        .where((theme) => ids.contains(theme.id))
        .map((theme) => theme.id)
        .toList();
  }
}
