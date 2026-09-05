import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:pixeldoku/services/storage_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';

class HomeController {
  final StorageService _storageService = StorageService();

  bool didSyncRemoteSaveToLocal = false;
  bool isSyncingRemoteSave = false;
  String? _lastSyncedUserId;

  // -----------------------------
  // SYNC REMOTE SAVE TO LOCAL
  // -----------------------------
  Future<void> syncRemoteSaveToLocal(AppState appState) async {
    final userId = appState.user?.id;
    AppLogger.log(
      'HomeController.syncRemoteSaveToLocal start user=${userId ?? "null"} isLoading=${appState.isLoading}',
    );
    if (appState.isLoading || _lastSyncedUserId == userId) {
      isSyncingRemoteSave = false;
      AppLogger.log('HomeController.syncRemoteSaveToLocal skipped');
      return;
    }

    if (appState.isOfflineMode || userId == null) {
      didSyncRemoteSaveToLocal = true;
      isSyncingRemoteSave = false;
      AppLogger.log('HomeController.syncRemoteSaveToLocal skipped offline');
      return;
    }

    isSyncingRemoteSave = true;
    didSyncRemoteSaveToLocal = true;
    _lastSyncedUserId = userId;

    try {
      await _storageService.updateLocalGameFromSupabase(appState.gameProgress);
    } finally {
      isSyncingRemoteSave = false;
      AppLogger.log('HomeController.syncRemoteSaveToLocal complete');
    }
  }

  // -----------------------------
  // START OR CONTINUE GAME
  // -----------------------------
  Future<void> startOrContinueGame(
    AppState appState,
    GameState gameState,
  ) async {
    AppLogger.log('HomeController.startOrContinueGame start');
    var loaded = false;

    try {
      final savedGame = await _storageService.loadLocalGameData();
      loaded = savedGame != null && gameState.restoreFromJson(savedGame);
      AppLogger.log(
        'HomeController.startOrContinueGame restore loaded=$loaded',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'HomeController.startOrContinueGame restore failed',
        error,
        stackTrace,
      );
      loaded = false;
    }

    if (!loaded) {
      AppLogger.log(
        'HomeController.startOrContinueGame starting new level=${appState.currentLevel}',
      );
      gameState.startGame(level: appState.currentLevel);
    }
  }

  Future<void> startOrContinueDaily(GameState gameState) async {
    final today = GameState.formatDailyDateKey(DateTime.now());
    var loaded = false;
    try {
      final savedGame = await _storageService.loadLocalGameData(
        key: StorageService.dailyGameKey,
      );
      loaded =
          savedGame != null &&
          savedGame['dailyDateKey'] == today &&
          gameState.restoreFromJson(savedGame);
    } catch (error, stackTrace) {
      AppLogger.error(
        'HomeController.startOrContinueDaily restore failed',
        error,
        stackTrace,
      );
    }

    if (!loaded) gameState.startDailyGame();
  }

  // -----------------------------
  // CAN START GAME
  // -----------------------------
  bool canStartGame(AppState appState) {
    return !appState.isLoading && !isSyncingRemoteSave;
  }

  // -----------------------------
  // GAME BUTTON TEXT
  // -----------------------------
  String gameButtonText(AppState appState, GameState gameState) {
    if (!canStartGame(appState)) {
      return "Loading";
    }

    if (_hasContinuableGame(appState, gameState)) {
      return "Continue";
    }

    return "Start Game";
  }

  // -----------------------------
  // HAS CONTINUABLE GAME
  // -----------------------------
  bool _hasContinuableGame(AppState appState, GameState gameState) {
    return (gameState.hasActiveGame && !gameState.isDaily) ||
        (!gameState.gameCompleted &&
            !gameState.gameOver &&
            appState.gameProgress.isNotEmpty);
  }
}
