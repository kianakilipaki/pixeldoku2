import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pixeldoku/services/ads_service.dart';
import 'package:pixeldoku/services/auth_service.dart';
import 'package:pixeldoku/services/storage_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';

class GameController {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  int selectedRow = -1;
  int selectedCol = -1;
  int selectedAnimal = -1;

  late GameState _gameState;
  AppState? _appState;
  bool _completionHandled = false;

  // -----------------------------
  // SET GAME STATE
  // -----------------------------
  void setGameState(GameState gameState) {
    _gameState = gameState;
  }

  void setAppState(AppState appState) {
    _appState = appState;
  }

  // -----------------------------
  // HANDLE APP LIFECYCLE STATE
  // -----------------------------
  void handleAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }

    _gameState.pause();
    saveLocalGameToSupabase();
  }

  bool get isPaused => _gameState.isPaused;

  // -----------------------------
  // SAVE LOCAL GAME TO SUPABASE
  // -----------------------------
  Future<void> saveLocalGameToSupabase() async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (_gameState.hasActiveGame) {
      await _storageService.saveLocalGameData(_gameState.toJson());
    }

    await _storageService.updateSupabaseGameFromLocal(user.id);
  }

  // -----------------------------
  // SELECT CELL
  // -----------------------------
  void selectCell(int row, int col) {
    selectedRow = row;
    selectedCol = col;
  }

  // -----------------------------
  // INPUT NUMBER
  // -----------------------------
  void inputNumber(int number) {
    if (selectedRow == -1 || selectedCol == -1) return;
    if (_gameState.puzzle![selectedRow][selectedCol] != 0) return;

    _gameState.inputNumber(selectedRow, selectedCol, number);
  }

  void selectAnimal(int number) {
    selectedAnimal = number;
  }

  void deselectAnimal() {
    selectedAnimal = -1;
  }

  void clearSelection() {
    selectedRow = -1;
    selectedCol = -1;
    selectedAnimal = -1;
  }

  void placeSelectedAnimal() {
    if (selectedAnimal == -1) return;

    inputNumber(selectedAnimal);
  }

  // -----------------------------
  // CLEAR CELL
  // -----------------------------
  void clearCell() {
    if (selectedRow == -1 || selectedCol == -1) return;
    if (_gameState.puzzle![selectedRow][selectedCol] != 0) return;

    _gameState.clearCell(selectedRow, selectedCol);
  }

  void undoLastMove() {
    _gameState.undoLastMove();
  }

  Future<({int row, int col})?> useHint() async {
    final appState = _appState;
    if (appState == null || appState.hints <= 0) return null;

    final hint = _gameState.revealRandomHint();
    if (hint == null) return null;

    unawaited(appState.useHint());
    return hint;
  }

  Future<List<String>> completeLevel() async {
    final appState = _appState;
    if (appState == null || _completionHandled || !_gameState.gameCompleted) {
      return const [];
    }

    final unlockedBefore = appState.unlockedTitleNames.toSet();

    _completionHandled = true;
    final dailyAlreadyCompleted =
        _gameState.isDaily &&
        _gameState.dailyDateKey != null &&
        appState.hasCompletedDaily(_gameState.dailyDateKey!);
    final reward = dailyAlreadyCompleted
        ? 0
        : appState.coinRewardForLevel(
                difficulty: _gameState.difficulty,
                reduced: _gameState.completedAfterRetry,
              ) +
              (_gameState.isDaily ? AppState.dailyCoinBonus : 0);
    _gameState.completionReward = reward;

    if (reward > 0) await appState.addCoins(reward);
    await appState.recordLevelCompleted(
      difficulty: _gameState.difficulty,
      reducedReward: _gameState.completedAfterRetry,
      mistakes: _gameState.mistakes,
      hintsUsed: _gameState.hintsUsedThisLevel,
      elapsedSeconds: _gameState.elapsedSeconds,
      isDaily: _gameState.isDaily,
      dailyDateKey: _gameState.dailyDateKey,
    );
    if (_gameState.isDaily && _gameState.dailyDateKey != null) {
      await appState.submitDailyTime(
        _gameState.dailyDateKey!,
        _gameState.elapsedSeconds,
      );
    }
    if (!_gameState.isDaily) await appState.setGameProgress({});

    AdsService.showInterstitial();

    return appState.unlockedTitleNames
        .where((title) => !unlockedBefore.contains(title))
        .toList(growable: false);
  }

  Future<List<String>> advanceCompletedLevel() async {
    final appState = _appState;
    if (appState == null || !_gameState.gameCompleted) return const [];
    if (_gameState.isDaily) return const [];

    final unlockedBefore = appState.unlockedTitleNames.toSet();
    final nextLevel = _gameState.currentLevel + 1;
    _gameState.currentLevel = nextLevel;
    await appState.setLevel(nextLevel);

    return appState.unlockedTitleNames
        .where((title) => !unlockedBefore.contains(title))
        .toList(growable: false);
  }

  Future<List<String>> loadNextLevel() async {
    final achievements = await advanceCompletedLevel();
    _completionHandled = false;
    clearSelection();
    _gameState.startGame(level: _gameState.currentLevel);
    return achievements;
  }

  // -----------------------------
  // IS SELECTED CELL
  // -----------------------------
  bool isSelectedCell(int row, int col) {
    return row == selectedRow && col == selectedCol;
  }
}
