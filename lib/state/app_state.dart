import 'package:flutter/foundation.dart';
import 'package:pixeldoku/models/competition.dart';
import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:pixeldoku/models/theme_catalog.dart';
import 'package:pixeldoku/models/title_catalog.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  List<Map<String, dynamic>> pendingCompetitionAwards = [];
  int get spareHearts => _statInt('spare_hearts');

  Future<void> checkCompetitionAwards() async {
    pendingCompetitionAwards = [];
    if (user == null || isOfflineMode) return;
    final userId = user!.id;
    try {
      final now = DateTime.now().toUtc();
      final today =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final runs = statistics['daily_runs'];
      if (runs is Map && runs[today] is Map) {
        final run = runs[today] as Map;
        await submitDailyScore(
          today,
          run['seconds'] as int,
          run['hints'] as int,
          run['hearts'] as int,
        );
      }
      final awards = await _storageService.competitionAwards();
      if (user?.id != userId) return;
      if (awards.isEmpty) return;
      final wallet = awards.first;
      coins = (wallet['wallet_coins'] as num).toInt();
      hints = (wallet['wallet_hints'] as num).toInt();
      statistics = {
        ...statistics,
        'spare_hearts': wallet['spare_hearts'],
        'monthly_championships': wallet['monthly_championships'],
      };
      pendingCompetitionAwards = awards;
      await _saveLocalProgress();
      notifyListeners();
    } catch (error) {
      AppLogger.error(
        'Competition awards unavailable; will retry next visit',
        error,
      );
    }
  }

  Future<void> acknowledgeCompetitionAward(String id) async {
    final client = _storageService.supabase;
    if (client == null) return;
    await client.rpc('acknowledge_competition_award', params: {'p_id': id});
    pendingCompetitionAwards.removeWhere(
      (award) => award['id'].toString() == id,
    );
    notifyListeners();
  }

  Future<bool> useSpareHeart() async {
    if (spareHearts <= 0) return false;
    statistics = {...statistics, 'spare_hearts': spareHearts - 1};
    await _saveLocalProgress();
    await _tryCloudUpdate('statistics', statistics);
    notifyListeners();
    return true;
  }

  Future<bool> buyHeartBundle() async {
    if (coins < 100) return false;
    coins -= 100;
    statistics = {...statistics, 'spare_hearts': spareHearts + 3};
    notifyListeners();
    await _saveLocalProgress();
    await _tryCloudUpdate('coins', coins);
    await _tryCloudUpdate('statistics', statistics);
    return true;
  }

  List<PixelDokuTheme> get lockedThemes => ThemeCatalog.themes
      .where((theme) => !unlockedThemes.contains(theme.id))
      .toList(growable: false);

  Future<bool> buyTheme(String themeId) async {
    if (coins < 500 || !lockedThemes.any((theme) => theme.id == themeId)) {
      return false;
    }
    coins -= 500;
    unlockedThemes = [...unlockedThemes, themeId];
    notifyListeners();
    await _saveLocalProgress();
    await _tryCloudUpdate('coins', coins);
    await _tryCloudUpdate('unlocked_themes', unlockedThemes);
    return true;
  }

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
      if (!isOfflineMode) {
        user ??= await _startAnonymousSession();
        if (user != null) await _restoreOrSeedCloudProfile();
      }
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
        await _restoreOrSeedCloudProfile();
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

  Future<User?> _startAnonymousSession() async {
    try {
      final anonymousUser = await _authService.signInAnonymously();
      AppLogger.log(
        'AppState anonymous player ready user=${anonymousUser?.id ?? "null"}',
      );
      return anonymousUser;
    } catch (error, stackTrace) {
      AppLogger.error('Anonymous player setup failed', error, stackTrace);
      return null;
    }
  }

  Future<bool> _ensurePlayerIdentity() async {
    if (_storageService.supabase == null) return false;
    isOfflineMode = false;

    final existingUser = user ?? _authService.currentUser;
    if (existingUser != null) {
      user = existingUser;
      return true;
    }

    final anonymousUser = await _startAnonymousSession();
    if (anonymousUser == null) return false;
    user = anonymousUser;
    await _restoreOrSeedCloudProfile();
    return true;
  }

  Future<void> _restoreOrSeedCloudProfile() async {
    final currentUser = user;
    if (currentUser == null) return;

    AppLogger.log(
      'AppState._restoreOrSeedCloudProfile start user=${currentUser.id}',
    );
    await _authService.ensureCurrentUserExists();

    final savedLocalGame = await _storageService.loadLocalGameData();
    final local = _currentProgress(gameProgressOverride: savedLocalGame);
    final remote = await _storageService.loadUserData(currentUser.id);
    final shouldSeedCloud =
        !_hasCloudProgress(remote) && _hasLocalProgress(local);

    if (shouldSeedCloud) {
      final requestedLocalName =
          local.name.trim().isNotEmpty &&
              local.name != StorageService.defaultProgress.name
          ? local.name
          : null;
      final seeded = _progressForFirstCloudSync(local, remote);
      _applyProgress(seeded);
      await _storageService.saveUserProgress(currentUser.id, seeded);
      if (requestedLocalName != null) {
        try {
          name = await _storageService.saveUniquePlayerName(requestedLocalName);
        } on UsernameSaveException catch (error) {
          AppLogger.log(
            'Existing local username was not available: ${error.message}',
          );
        }
      }
      await _saveLocalProgress();
      AppLogger.log(
        'AppState._restoreOrSeedCloudProfile seeded cloud from local',
      );
      return;
    }

    _applyProgress(remote);
    await _saveLocalProgress();
    await _storageService.updateLocalGameFromSupabase(remote.gameProgress);
    AppLogger.log(
      'AppState._restoreOrSeedCloudProfile restored local from cloud',
    );
  }

  UserProgress _currentProgress({Map<String, dynamic>? gameProgressOverride}) {
    return UserProgress(
      coins: coins,
      currentLevel: currentLevel,
      gameProgress: gameProgressOverride ?? gameProgress,
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
    );
  }

  bool _hasCloudProgress(UserProgress progress) {
    final defaults = StorageService.defaultProgress;
    return progress.coins != defaults.coins ||
        progress.currentLevel != defaults.currentLevel ||
        progress.gameProgress.isNotEmpty ||
        progress.profilePicture != defaults.profilePicture ||
        progress.profilePictureBgColor != defaults.profilePictureBgColor ||
        progress.playerTitle != defaults.playerTitle ||
        !_sameStrings(progress.unlockedThemes, defaults.unlockedThemes) ||
        progress.activeTheme != defaults.activeTheme ||
        progress.hints != defaults.hints ||
        progress.musicOn != defaults.musicOn ||
        progress.sfxOn != defaults.sfxOn ||
        progress.boardHighlightsOn != defaults.boardHighlightsOn ||
        progress.statistics.isNotEmpty;
  }

  bool _hasLocalProgress(UserProgress progress) {
    return _hasCloudProgress(progress) ||
        progress.name != StorageService.defaultProgress.name;
  }

  UserProgress _progressForFirstCloudSync(
    UserProgress local,
    UserProgress remote,
  ) {
    return UserProgress(
      coins: local.coins,
      currentLevel: local.currentLevel,
      gameProgress: local.gameProgress,
      // Keep the server-generated Player#### until a custom local name has
      // passed the same uniqueness check used by the profile editor.
      name: remote.name,
      profilePicture: local.profilePicture,
      profilePictureBgColor: local.profilePictureBgColor,
      playerTitle: local.playerTitle,
      unlockedThemes: local.unlockedThemes,
      activeTheme: local.activeTheme,
      hints: local.hints,
      musicOn: local.musicOn,
      sfxOn: local.sfxOn,
      boardHighlightsOn: local.boardHighlightsOn,
      statistics: local.statistics,
    );
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
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
    await _storageService.saveLocalUserProgress(_currentProgress());
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

  Future<void> setDailyTheme(String themeId) => setActiveTheme(themeId);

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

  Future<String?> setPlayerName(String value) async {
    final requestedName = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (requestedName.length < 3 || requestedName.length > 20) {
      return 'Username must be between 3 and 20 characters.';
    }
    if (!await _ensurePlayerIdentity()) {
      return 'Connect to the internet to save a unique username.';
    }

    try {
      final savedName = await _storageService.saveUniquePlayerName(
        requestedName,
      );
      name = savedName;
      notifyListeners();
      await _saveLocalProgress();
      return null;
    } on UsernameSaveException catch (error) {
      return error.message;
    }
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
    required String themeId,
    bool isDaily = false,
    String? dailyDateKey,
  }) async {
    final dailyResults = _dailyResults();
    final dailyScores = _dailyScores();
    final dailyOutcomes = _dailyOutcomes();
    final dailyRuns = Map<String, dynamic>.from(
      statistics['daily_runs'] as Map? ?? {},
    );
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
      themeCompletions[themeId] = (themeCompletions[themeId] ?? 0) + 1;
    }
    final isNoMistake = mistakes == 0;
    final isNoHint = hintsUsed == 0;
    final isSpeedRun = elapsedSeconds > 0 && elapsedSeconds <= 180;
    final wonWithOneHeart = mistakes == 2;
    final basePoints = RewardRules.score(
      seconds: elapsedSeconds,
      hints: hintsUsed,
      heartsLost: mistakes,
    );
    final pointsAwarded = countsTowardProgress ? basePoints : 0;
    if (isDaily && dailyDateKey != null && firstDailyCompletion) {
      dailyResults[dailyDateKey] = elapsedSeconds;
    }
    if (isDaily && dailyDateKey != null && firstDailyCompletion) {
      dailyScores[dailyDateKey] = pointsAwarded;
      dailyRuns[dailyDateKey] = {
        'seconds': elapsedSeconds,
        'hints': hintsUsed,
        'hearts': mistakes,
      };
    }
    if (isDaily && dailyDateKey != null && firstDailyCompletion) {
      if (isNoMistake) {
        dailyOutcomes[dailyDateKey] = 'perfect';
      } else if (dailyOutcomes[dailyDateKey] != 'perfect') {
        dailyOutcomes[dailyDateKey] = 'complete';
      }
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
      'daily_scores': dailyScores,
      'daily_runs': dailyRuns,
      'daily_outcomes': dailyOutcomes,
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
  String get dailyTheme => activeTheme;
  PixelDokuTheme get dailyThemeData => ThemeCatalog.byId(dailyTheme);

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

  int? get bestDailyTimeOverall {
    final times = _dailyResults().values.where((time) => time > 0).toList();
    if (times.isEmpty) return null;
    times.sort();
    return times.first;
  }

  int? bestDailyTimeForMonth(DateTime month) {
    final prefix =
        '${month.toUtc().year}${month.toUtc().month.toString().padLeft(2, '0')}';
    final times = _dailyResults().entries
        .where((entry) => entry.key.startsWith(prefix) && entry.value > 0)
        .map((entry) => entry.value)
        .toList();
    if (times.isEmpty) return null;
    times.sort();
    return times.first;
  }

  int? dailyScore(String dateKey) {
    if (!hasCompletedDaily(dateKey)) return null;
    return _dailyScores()[dateKey];
  }

  String? dailyOutcome(String dateKey) {
    final outcome = _dailyOutcomes()[dateKey];
    if (outcome == 'perfect' || outcome == 'complete' || outcome == 'failed') {
      return outcome;
    }
    return hasCompletedDaily(dateKey) ? 'complete' : null;
  }

  Future<void> recordDailyFailure(String dateKey) async {
    if (hasCompletedDaily(dateKey)) return;

    final outcomes = _dailyOutcomes();
    if (outcomes[dateKey] == 'failed') return;
    outcomes[dateKey] = 'failed';
    statistics = {...statistics, 'daily_outcomes': outcomes};
    notifyListeners();

    await _saveLocalProgress();
    await _tryCloudUpdate('statistics', statistics);
  }

  Future<void> submitDailyTime(String dateKey, int elapsedSeconds) async {
    if (user == null || isOfflineMode) return;
    try {
      await _storageService.submitDailyTime(dateKey, elapsedSeconds);
    } catch (error, stackTrace) {
      AppLogger.error('Daily leaderboard submission failed', error, stackTrace);
    }
  }

  Future<void> submitDailyScore(
    String dateKey,
    int seconds,
    int hintsUsed,
    int heartsLost,
  ) async {
    if (user == null || isOfflineMode) return;
    try {
      final runs = statistics['daily_runs'];
      final first = runs is Map ? runs[dateKey] : null;
      if (first is Map) {
        seconds = (first['seconds'] as num).toInt();
        hintsUsed = (first['hints'] as num).toInt();
        heartsLost = (first['hearts'] as num).toInt();
      }
      await _storageService.submitDailyScore(
        dateKey,
        seconds,
        hintsUsed,
        heartsLost,
      );
    } catch (error) {
      AppLogger.error('Daily score submission failed', error);
    }
  }

  int competitionScore(CompetitionPeriod period) {
    final now = DateTime.now().toUtc();
    final start = period.start(now);
    final end = period.end(now);
    return _dailyScores().entries
        .where((entry) {
          final key = entry.key;
          if (key.length != 8) return false;
          final date = DateTime.tryParse(
            '${key.substring(0, 4)}-${key.substring(4, 6)}-${key.substring(6)}',
          );
          if (date == null) return false;
          final utc = DateTime.utc(date.year, date.month, date.day);
          return !utc.isBefore(start) && utc.isBefore(end);
        })
        .fold(0, (sum, entry) => sum + entry.value);
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

  Map<String, int> _dailyScores() {
    final stored = statistics['daily_scores'];
    if (stored is! Map) return <String, int>{};
    return stored.map(
      (key, value) => MapEntry(
        key.toString(),
        value is num ? value.toInt() : int.tryParse('$value') ?? 0,
      ),
    );
  }

  Map<String, String> _dailyOutcomes() {
    final stored = statistics['daily_outcomes'];
    if (stored is! Map) return <String, String>{};
    return stored.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
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
    if (kDebugMode) {
      return ThemeCatalog.themes
          .map((theme) => theme.id)
          .toList(growable: false);
    }

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
