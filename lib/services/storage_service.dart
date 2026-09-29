import 'dart:convert';

import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;

class UserProgress {
  // -----------------------------
  // USER PROGRESS
  // -----------------------------
  const UserProgress({
    required this.coins,
    required this.currentLevel,
    required this.gameProgress,
    required this.name,
    required this.profilePicture,
    required this.profilePictureBgColor,
    required this.playerTitle,
    required this.unlockedThemes,
    required this.activeTheme,
    required this.hints,
    required this.musicOn,
    required this.sfxOn,
    required this.boardHighlightsOn,
    required this.statistics,
  });

  final int coins;
  final int currentLevel;
  final Map<String, dynamic> gameProgress;
  final String name;
  final String profilePicture;
  final int profilePictureBgColor;
  final String playerTitle;
  final List<String> unlockedThemes;
  final String activeTheme;
  final int hints;
  final bool musicOn;
  final bool sfxOn;
  final bool boardHighlightsOn;
  final Map<String, dynamic> statistics;

  Map<String, dynamic> toJson() {
    return {
      'coins': coins,
      'current_level': currentLevel,
      StorageService.savedGameKey: gameProgress,
      'name': name,
      'profile_picture': profilePicture,
      'profile_picture_bg_color': profilePictureBgColor,
      'player_title': playerTitle,
      'unlocked_themes': unlockedThemes,
      'active_theme': activeTheme,
      'hints': hints,
      'music_on': musicOn,
      'sfx_on': sfxOn,
      'board_highlights_on': boardHighlightsOn,
      'statistics': statistics,
    };
  }
}

class DailyLeaderboardEntry {
  const DailyLeaderboardEntry({
    required this.userId,
    required this.name,
    required this.elapsedSeconds,
    this.profilePicture,
  });

  final String userId;
  final String name;
  final int elapsedSeconds;
  final String? profilePicture;
}

class GlobalLeaderboardEntry {
  const GlobalLeaderboardEntry({
    required this.userId,
    required this.name,
    required this.level,
    required this.bestTimeSeconds,
    this.profilePicture,
    this.profilePictureBgColor = 0xFFEEC027,
    this.playerTitle = 'New Explorer',
    this.score = 0,
  });

  final String userId;
  final String name;
  final int level;
  final int bestTimeSeconds;
  final String? profilePicture;
  final int profilePictureBgColor;
  final String playerTitle;
  final int score;
}

class UsernameSaveException implements Exception {
  const UsernameSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StorageService {
  Future<String> saveUniquePlayerName(String requestedName) async {
    final client = supabase;
    if (client == null || client.auth.currentUser == null) {
      throw const UsernameSaveException(
        'Connect to the internet to save a unique username.',
      );
    }

    try {
      final result = await client.rpc(
        'set_player_name',
        params: {'p_name': requestedName},
      );
      return result.toString();
    } catch (error, stackTrace) {
      final details = error.toString();
      AppLogger.error('Unique username save failed', error, stackTrace);
      if (details.contains('USERNAME_TAKEN')) {
        throw const UsernameSaveException('That username is already in use.');
      }
      if (details.contains('USERNAME_LENGTH')) {
        throw const UsernameSaveException(
          'Username must be between 3 and 20 characters.',
        );
      }
      if (details.contains('USERNAME_CHARACTERS')) {
        throw const UsernameSaveException(
          'That username contains unsupported characters.',
        );
      }
      if (details.contains('USERNAME_AUTH_REQUIRED')) {
        throw const UsernameSaveException(
          'Your player profile is not ready. Please try again.',
        );
      }
      throw const UsernameSaveException(
        'Could not verify that username. Please try again.',
      );
    }
  }

  Future<List<GlobalLeaderboardEntry>> loadCompetition(String period) async {
    final client = supabase;
    if (client == null) {
      throw StateError('Online competitions require a connection.');
    }
    final rows = await client.rpc(
      'get_competition_leaderboard',
      params: {'p_period': period},
    );
    return (rows as List)
        .map(
          (row) => GlobalLeaderboardEntry(
            userId: row['user_id'].toString(),
            name: row['player_name'] ?? 'Player',
            level: (row['player_level'] as num).toInt(),
            bestTimeSeconds: (row['best_time_seconds'] as num).toInt(),
            score: (row['score'] as num).toInt(),
            profilePicture: row['profile_picture'],
            profilePictureBgColor: (row['profile_picture_bg_color'] as num)
                .toInt(),
            playerTitle: row['player_title'] ?? 'New Explorer',
          ),
        )
        .toList();
  }

  Future<void> submitDailyScore(
    String dateKey,
    int seconds,
    int hints,
    int mistakes,
  ) async {
    final client = supabase;
    if (client == null || client.auth.currentUser == null) return;
    await client.rpc(
      'submit_daily_score',
      params: {
        'p_puzzle_date': _sqlDate(dateKey),
        'p_elapsed_seconds': seconds,
        'p_hints': hints,
        'p_hearts_lost': mistakes,
      },
    );
  }

  Future<List<Map<String, dynamic>>> competitionAwards() async {
    final client = supabase;
    if (client == null || client.auth.currentUser == null) return [];
    final rows = await client.rpc('get_competition_awards');
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static const String savedGameKey = 'saved_game';
  static const String dailyGameKey = 'saved_daily_game';
  static const String localProgressKey = 'local_user_progress';

  SupabaseClient? get supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static const UserProgress defaultProgress = UserProgress(
    coins: 100,
    currentLevel: 1,
    gameProgress: {},
    name: 'Player',
    profilePicture: 'lib/assets/themes/birds/bird_1.png',
    profilePictureBgColor: 0xFFEEC027,
    playerTitle: 'New Explorer',
    unlockedThemes: ['birds'],
    activeTheme: 'birds',
    hints: 10,
    musicOn: true,
    sfxOn: true,
    boardHighlightsOn: true,
    statistics: {},
  );

  // -----------------------------
  // LOAD USER DATA
  // -----------------------------
  Future<UserProgress> loadUserData(String userId) async {
    AppLogger.log('StorageService.loadUserData start user=$userId');
    final client = supabase;
    if (client == null) {
      throw StateError('Supabase is unavailable');
    }

    final data = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    AppLogger.log(
      'StorageService.loadUserData query complete found=${data != null}',
    );

    if (data == null) {
      AppLogger.log('StorageService.loadUserData inserting default user row');
      await client.from('users').insert({
        'id': userId,
        'coins': 100,
        'current_level': 1,
        savedGameKey: {},
      });
      AppLogger.log('StorageService.loadUserData default user row inserted');

      return defaultProgress;
    }

    final savedGame = data[savedGameKey];
    final unlockedThemes = data['unlocked_themes'];
    final statistics = data['statistics'];

    final progress = UserProgress(
      coins: data['coins'] ?? 0,
      currentLevel: data['current_level'] ?? 1,
      gameProgress: savedGame is Map
          ? Map<String, dynamic>.from(savedGame)
          : {},
      name: data['name'] ?? 'Player',
      profilePicture:
          data['profile_picture'] ?? 'lib/assets/themes/birds/bird_1.png',
      profilePictureBgColor:
          data['profile_picture_bg_color'] ??
          defaultProgress.profilePictureBgColor,
      playerTitle: data['player_title'] ?? defaultProgress.playerTitle,
      unlockedThemes: unlockedThemes is List
          ? unlockedThemes.map((theme) => theme.toString()).toList()
          : ['birds'],
      activeTheme: data['active_theme'] ?? 'birds',
      hints: data['hints'] ?? 10,
      musicOn: data['music_on'] ?? true,
      sfxOn: data['sfx_on'] ?? true,
      boardHighlightsOn: data['board_highlights_on'] ?? true,
      statistics: statistics is Map
          ? Map<String, dynamic>.from(statistics)
          : {},
    );
    AppLogger.log(
      'StorageService.loadUserData complete level=${progress.currentLevel} coins=${progress.coins}',
    );
    return progress;
  }

  // -----------------------------
  // UPDATE USER DATA
  // -----------------------------
  Future<void> updateUserData(
    String userId,
    String property,
    Object value,
  ) async {
    AppLogger.log('StorageService.updateUserData start property=$property');
    final client = supabase;
    if (client == null) {
      throw StateError('Supabase is unavailable');
    }

    await client.from('users').update({property: value}).eq('id', userId);
    AppLogger.log('StorageService.updateUserData complete property=$property');
  }

  /// Replaces the complete cloud profile after a player's first account sync.
  Future<void> saveUserProgress(String userId, UserProgress progress) async {
    AppLogger.log('StorageService.saveUserProgress start user=$userId');
    final client = supabase;
    if (client == null) {
      throw StateError('Supabase is unavailable');
    }

    await client.from('users').update(progress.toJson()).eq('id', userId);
    AppLogger.log('StorageService.saveUserProgress complete user=$userId');
  }

  /// Loads the fastest submitted time per player for one daily puzzle.
  Future<List<DailyLeaderboardEntry>> loadDailyLeaderboard(
    String dateKey,
  ) async {
    final client = supabase;
    if (client == null) return const [];

    try {
      final rows = await client.rpc(
        'get_daily_leaderboard',
        params: {'p_puzzle_date': _sqlDate(dateKey)},
      );
      if (rows is List) {
        return _leaderboardEntries(rows);
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Dedicated daily leaderboard unavailable; using profile statistics',
        error,
        stackTrace,
      );
    }

    final rows = await client
        .from('users')
        .select('id, name, profile_picture, statistics');
    final legacyRows = <Map<String, dynamic>>[];
    for (final row in rows) {
      final statistics = row['statistics'];
      if (statistics is! Map) continue;
      final results = statistics['daily_results'];
      if (results is! Map || results[dateKey] == null) continue;
      legacyRows.add({
        'user_id': row['id'],
        'player_name': row['name'],
        'profile_picture': row['profile_picture'],
        'elapsed_seconds': results[dateKey],
      });
    }
    return _leaderboardEntries(legacyRows);
  }

  Future<void> submitDailyTime(String dateKey, int elapsedSeconds) async {
    final client = supabase;
    if (client == null || client.auth.currentUser == null) return;
    await client.rpc(
      'submit_daily_time',
      params: {
        'p_puzzle_date': _sqlDate(dateKey),
        'p_elapsed_seconds': elapsedSeconds,
      },
    );
  }

  /// Loads this month's rankings using each player's fastest Daily time.
  Future<List<GlobalLeaderboardEntry>> loadGlobalLeaderboard() async {
    final client = supabase;
    if (client == null) return const [];

    try {
      final rows = await client.rpc('get_global_leaderboard');
      if (rows is List) return _globalLeaderboardEntries(rows);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Dedicated global leaderboard unavailable; using profile statistics',
        error,
        stackTrace,
      );
    }

    final rows = await client
        .from('users')
        .select(
          'id, name, profile_picture, profile_picture_bg_color, '
          'player_title, current_level, statistics',
        );
    final legacyRows = <Map<String, dynamic>>[];
    for (final row in rows) {
      final statistics = row['statistics'];
      if (statistics is! Map) continue;
      final results = statistics['daily_results'];
      if (results is! Map) continue;

      final now = DateTime.now().toUtc();
      final monthPrefix = '${now.year}${now.month.toString().padLeft(2, '0')}';
      final times = results.entries
          .where((entry) => entry.key.toString().startsWith(monthPrefix))
          .map((entry) => _intValue(entry.value, 0))
          .where((value) => value > 0)
          .toList();
      if (times.isEmpty) continue;
      times.sort();

      legacyRows.add({
        'user_id': row['id'],
        'player_name': row['name'],
        'profile_picture': row['profile_picture'],
        'profile_picture_bg_color': row['profile_picture_bg_color'],
        'player_title': row['player_title'],
        'player_level': row['current_level'],
        'best_time_seconds': times.first,
      });
    }
    return _globalLeaderboardEntries(legacyRows);
  }

  static List<GlobalLeaderboardEntry> _globalLeaderboardEntries(List rows) {
    final entries = <GlobalLeaderboardEntry>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final bestTime = _intValue(row['best_time_seconds'], 0);
      if (bestTime <= 0) continue;

      entries.add(
        GlobalLeaderboardEntry(
          userId: row['user_id']?.toString() ?? '',
          name: row['player_name']?.toString().trim().isNotEmpty == true
              ? row['player_name'].toString()
              : 'Player',
          level: _intValue(row['player_level'], 1).clamp(1, 999999),
          bestTimeSeconds: bestTime,
          profilePicture: row['profile_picture']?.toString(),
          profilePictureBgColor: _intValue(
            row['profile_picture_bg_color'],
            0xFFEEC027,
          ),
          playerTitle: row['player_title']?.toString().trim().isNotEmpty == true
              ? row['player_title'].toString()
              : 'New Explorer',
        ),
      );
    }
    entries.sort((a, b) {
      final timeComparison = a.bestTimeSeconds.compareTo(b.bestTimeSeconds);
      return timeComparison != 0 ? timeComparison : b.level.compareTo(a.level);
    });
    return entries.take(25).toList(growable: false);
  }

  static List<DailyLeaderboardEntry> _leaderboardEntries(List rows) {
    final entries = <DailyLeaderboardEntry>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final rawTime = row['elapsed_seconds'];
      final elapsed = rawTime is num
          ? rawTime.toInt()
          : int.tryParse('$rawTime');
      if (elapsed == null || elapsed <= 0) continue;
      entries.add(
        DailyLeaderboardEntry(
          userId: row['user_id']?.toString() ?? '',
          name: row['player_name']?.toString().trim().isNotEmpty == true
              ? row['player_name'].toString()
              : 'Player',
          elapsedSeconds: elapsed,
          profilePicture: row['profile_picture']?.toString(),
        ),
      );
    }
    entries.sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
    return entries.take(25).toList(growable: false);
  }

  static String _sqlDate(String dateKey) {
    if (dateKey.length != 8) return dateKey;
    return '${dateKey.substring(0, 4)}-${dateKey.substring(4, 6)}-'
        '${dateKey.substring(6, 8)}';
  }

  Future<UserProgress> loadLocalUserProgress() async {
    AppLogger.log('StorageService.loadLocalUserProgress start');
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(localProgressKey);
      if (jsonString == null) {
        AppLogger.log('StorageService.loadLocalUserProgress using default');
        return defaultProgress;
      }
      final data = jsonDecode(jsonString);
      if (data is! Map) {
        AppLogger.log('StorageService.loadLocalUserProgress invalid shape');
        return defaultProgress;
      }

      final progress = _progressFromMap(Map<String, dynamic>.from(data));
      AppLogger.log(
        'StorageService.loadLocalUserProgress complete level=${progress.currentLevel} coins=${progress.coins}',
      );
      return progress;
    } catch (error, stackTrace) {
      AppLogger.error(
        'StorageService.loadLocalUserProgress failed',
        error,
        stackTrace,
      );
      return defaultProgress;
    }
  }

  Future<void> saveLocalUserProgress(UserProgress progress) async {
    AppLogger.log('StorageService.saveLocalUserProgress start');
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(localProgressKey, jsonEncode(progress.toJson()));
    AppLogger.log('StorageService.saveLocalUserProgress complete');
  }

  Future<void> updateLocalUserData(String property, Object value) async {
    AppLogger.log(
      'StorageService.updateLocalUserData start property=$property',
    );
    final current = await loadLocalUserProgress();
    final data = current.toJson();
    data[property] = value;

    await saveLocalUserProgress(_progressFromMap(data));
    AppLogger.log(
      'StorageService.updateLocalUserData complete property=$property',
    );
  }

  // -----------------------------
  // UPDATE SUPABASE GAME DATA
  // -----------------------------
  Future<void> updateSupabaseGameData(
    String userId,
    Map<String, dynamic> gameData,
  ) async {
    await updateUserData(userId, savedGameKey, gameData);
  }

  // -----------------------------
  // SAVE LOCAL GAME DATA
  // -----------------------------
  Future<void> saveLocalGameData(
    Map<String, dynamic> gameData, {
    String key = savedGameKey,
  }) async {
    AppLogger.log(
      'StorageService.saveLocalGameData start keys=${gameData.keys.join(",")}',
    );
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(key, jsonEncode(gameData));
    AppLogger.log('StorageService.saveLocalGameData complete');
  }

  // -----------------------------
  // LOAD LOCAL GAME DATA
  // -----------------------------
  Future<Map<String, dynamic>?> loadLocalGameData({
    String key = savedGameKey,
  }) async {
    AppLogger.log('StorageService.loadLocalGameData start');
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);
      if (jsonString == null) {
        AppLogger.log('StorageService.loadLocalGameData no saved game');
        return null;
      }
      final data = jsonDecode(jsonString);
      if (data is! Map) {
        AppLogger.log(
          'StorageService.loadLocalGameData invalid saved game shape',
        );
        return null;
      }
      AppLogger.log('StorageService.loadLocalGameData complete');
      return Map<String, dynamic>.from(data);
    } catch (error, stackTrace) {
      AppLogger.error(
        'StorageService.loadLocalGameData failed',
        error,
        stackTrace,
      );
      return null;
    }
  }

  // -----------------------------
  // CLEAR LOCAL GAME DATA
  // -----------------------------
  Future<void> clearLocalGameData({String key = savedGameKey}) async {
    AppLogger.log('StorageService.clearLocalGameData start');
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(key);
    AppLogger.log('StorageService.clearLocalGameData complete');
  }

  // -----------------------------
  // UPDATE LOCAL GAME FROM SUPABASE
  // -----------------------------
  Future<void> updateLocalGameFromSupabase(
    Map<String, dynamic> savedGame,
  ) async {
    if (savedGame.isEmpty) {
      AppLogger.log('StorageService.updateLocalGameFromSupabase skipped empty');
      return;
    }

    AppLogger.log(
      'StorageService.updateLocalGameFromSupabase saving remote game',
    );
    await saveLocalGameData(savedGame);
  }

  // -----------------------------
  // UPDATE SUPABASE GAME FROM LOCAL IF REMOTE EMPTY
  // -----------------------------
  Future<void> updateSupabaseGameFromLocalIfRemoteEmpty(String userId) async {
    AppLogger.log(
      'StorageService.updateSupabaseGameFromLocalIfRemoteEmpty start',
    );
    final data = await loadLocalGameData();
    if (data == null || data.isEmpty) {
      AppLogger.log(
        'StorageService.updateSupabaseGameFromLocalIfRemoteEmpty skipped no local',
      );
      return;
    }

    final remoteData = await loadUserData(userId);
    if (remoteData.gameProgress.isNotEmpty) {
      AppLogger.log(
        'StorageService.updateSupabaseGameFromLocalIfRemoteEmpty skipped remote exists',
      );
      return;
    }

    await updateSupabaseGameData(userId, data);
    AppLogger.log(
      'StorageService.updateSupabaseGameFromLocalIfRemoteEmpty complete',
    );
  }

  // -----------------------------
  // UPDATE SUPABASE GAME FROM LOCAL
  // -----------------------------
  Future<void> updateSupabaseGameFromLocal(String userId) async {
    AppLogger.log('StorageService.updateSupabaseGameFromLocal start');
    final data = await loadLocalGameData();

    await updateSupabaseGameData(userId, data ?? {});
    AppLogger.log('StorageService.updateSupabaseGameFromLocal complete');
  }

  UserProgress _progressFromMap(Map<String, dynamic> data) {
    final savedGame = data[savedGameKey];
    final unlockedThemes = data['unlocked_themes'];
    final statistics = data['statistics'];

    return UserProgress(
      coins: _intValue(data['coins'], defaultProgress.coins),
      currentLevel: _intValue(
        data['current_level'],
        defaultProgress.currentLevel,
      ),
      gameProgress: savedGame is Map
          ? Map<String, dynamic>.from(savedGame)
          : defaultProgress.gameProgress,
      name: data['name'] ?? defaultProgress.name,
      profilePicture: data['profile_picture'] ?? defaultProgress.profilePicture,
      profilePictureBgColor: _intValue(
        data['profile_picture_bg_color'],
        defaultProgress.profilePictureBgColor,
      ),
      playerTitle: data['player_title'] ?? defaultProgress.playerTitle,
      unlockedThemes: unlockedThemes is List
          ? unlockedThemes.map((theme) => theme.toString()).toList()
          : defaultProgress.unlockedThemes,
      activeTheme: data['active_theme'] ?? defaultProgress.activeTheme,
      hints: _intValue(data['hints'], defaultProgress.hints),
      musicOn: _boolValue(data['music_on'], defaultProgress.musicOn),
      sfxOn: _boolValue(data['sfx_on'], defaultProgress.sfxOn),
      boardHighlightsOn: _boolValue(
        data['board_highlights_on'],
        defaultProgress.boardHighlightsOn,
      ),
      statistics: statistics is Map
          ? Map<String, dynamic>.from(statistics)
          : defaultProgress.statistics,
    );
  }

  static int _intValue(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _boolValue(Object? value, bool fallback) {
    if (value is bool) return value;
    if (value == 1 || value == 'true') return true;
    if (value == 0 || value == 'false') return false;
    return fallback;
  }
}
