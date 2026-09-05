import 'package:flutter/material.dart';
import 'package:pixeldoku/core/utils/sudoku_generator.dart';
import 'package:pixeldoku/services/storage_service.dart';

class GameState extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<List<int>>? puzzle;
  List<List<int>>? currentBoard;
  List<List<int>>? solution;
  List<List<Set<int>>> notes = _emptyNotes();
  List<List<bool>> wrongCells = _emptyWrongCells();

  String difficulty = 'Easy';

  int currentLevel = 1;

  int mistakes = 0;
  int maxMistakes = 3;
  int elapsedSeconds = 0;
  int hintsUsedThisLevel = 0;
  int completionReward = 0;

  bool hasActiveGame = false;
  bool gameCompleted = false;
  bool gameOver = false;
  bool isPaused = false;
  bool pencilMode = false;
  bool completedAfterRetry = false;
  bool isDaily = false;
  String? dailyDateKey;
  final List<_MoveSnapshot> _history = [];

  // -----------------------------
  // START GAME
  // -----------------------------
  void startGame({int? level}) {
    if (level != null) {
      currentLevel = level;
    }

    difficulty = _getDifficultyFromLevel(currentLevel);
    isDaily = false;
    dailyDateKey = null;

    final game = SudokuGenerator.generateSudoku(difficulty: difficulty);

    puzzle = game['puzzle'];

    currentBoard = puzzle!.map((row) => List<int>.from(row)).toList();

    solution = game['solution'];
    notes = _emptyNotes();
    wrongCells = _emptyWrongCells();
    _history.clear();

    mistakes = 0;
    elapsedSeconds = 0;
    hintsUsedThisLevel = 0;
    completionReward = 0;

    gameCompleted = false;
    gameOver = false;
    isPaused = false;
    completedAfterRetry = false;

    hasActiveGame = true;

    _saveLocalGameData();

    notifyListeners();
  }

  /// Starts the shared hard puzzle for a UTC calendar day.
  void startDailyGame({DateTime? date}) {
    final day = (date ?? DateTime.now()).toUtc();
    dailyDateKey = formatDailyDateKey(day);
    isDaily = true;
    difficulty = 'Hard';

    final game = SudokuGenerator.generateSudoku(
      difficulty: difficulty,
      seed: int.parse(dailyDateKey!),
    );
    puzzle = game['puzzle'];
    currentBoard = puzzle!.map((row) => List<int>.from(row)).toList();
    solution = game['solution'];
    notes = _emptyNotes();
    wrongCells = _emptyWrongCells();
    _history.clear();
    mistakes = 0;
    elapsedSeconds = 0;
    hintsUsedThisLevel = 0;
    completionReward = 0;
    gameCompleted = false;
    gameOver = false;
    isPaused = false;
    completedAfterRetry = false;
    hasActiveGame = true;
    _saveLocalGameData();
    notifyListeners();
  }

  static String formatDailyDateKey(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  // -----------------------------
  // INPUT NUMBER
  // -----------------------------
  void inputNumber(int row, int col, int number) {
    if (gameOver || gameCompleted || isPaused) return;

    // Prevent editing original cells
    if (puzzle![row][col] != 0) return;

    if (number == 0) {
      clearCell(row, col);
      return;
    }

    if (pencilMode) {
      _captureMove(row, col);
      if (notes[row][col].contains(number)) {
        notes[row][col].remove(number);
      } else {
        notes[row][col].add(number);
      }
      _saveLocalGameData();
      notifyListeners();
      return;
    }

    _captureMove(row, col);
    currentBoard![row][col] = number;
    notes[row][col].clear();

    // WRONG ANSWER
    if (solution![row][col] != number) {
      wrongCells[row][col] = true;
      mistakes++;

      if (mistakes >= maxMistakes) {
        gameOver = true;
        hasActiveGame = false;

        _clearLocalGameData();
      }
    }
    // CHECK COMPLETION
    else if (_isBoardComplete()) {
      wrongCells[row][col] = false;
      gameCompleted = true;
      hasActiveGame = false;

      _clearLocalGameData();
    } else {
      wrongCells[row][col] = false;
    }

    if (hasActiveGame) {
      _saveLocalGameData();
    }

    notifyListeners();
  }

  void clearCell(int row, int col) {
    if (gameOver || gameCompleted || isPaused) return;
    if (puzzle![row][col] != 0) return;

    _captureMove(row, col);
    currentBoard![row][col] = 0;
    notes[row][col].clear();
    wrongCells[row][col] = false;

    if (hasActiveGame) {
      _saveLocalGameData();
    }

    notifyListeners();
  }

  ({int row, int col})? revealRandomHint() {
    if (gameOver || gameCompleted || isPaused) return null;

    final unsolved = <({int row, int col})>[];
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (currentBoard![row][col] != solution![row][col]) {
          unsolved.add((row: row, col: col));
        }
      }
    }

    if (unsolved.isEmpty) return null;

    unsolved.shuffle();
    final cell = unsolved.first;
    _captureMove(cell.row, cell.col);
    currentBoard![cell.row][cell.col] = solution![cell.row][cell.col];
    hintsUsedThisLevel++;
    notes[cell.row][cell.col].clear();
    wrongCells[cell.row][cell.col] = false;

    if (_isBoardComplete()) {
      gameCompleted = true;
      hasActiveGame = false;
      _clearLocalGameData();
    } else {
      _saveLocalGameData();
    }

    notifyListeners();
    return cell;
  }

  void setPencilMode(bool value) {
    pencilMode = value;
    notifyListeners();
  }

  void togglePause() {
    if (gameOver || gameCompleted) return;

    isPaused = !isPaused;
    notifyListeners();
  }

  void pause() {
    if (!hasActiveGame || gameOver || gameCompleted || isPaused) return;
    isPaused = true;
    notifyListeners();
  }

  void resume() {
    isPaused = false;
    notifyListeners();
  }

  void undoLastMove() {
    if (gameOver || gameCompleted || isPaused || _history.isEmpty) return;

    final move = _history.removeLast();
    currentBoard![move.row][move.col] = move.value;
    notes[move.row][move.col] = {...move.notes};
    wrongCells[move.row][move.col] = move.wrong;
    mistakes = move.mistakes;

    if (hasActiveGame) {
      _saveLocalGameData();
    }

    notifyListeners();
  }

  void tickTimer() {
    if (!hasActiveGame || isPaused || gameOver || gameCompleted) return;

    elapsedSeconds++;
    notifyListeners();
  }

  int placedCountForAnimal(int value) {
    if (currentBoard == null || solution == null) return 0;

    var count = 0;
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (currentBoard![row][col] == value && solution![row][col] == value) {
          count++;
        }
      }
    }

    return count;
  }

  // -----------------------------
  // CHECK COMPLETE
  // -----------------------------
  bool _isBoardComplete() {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (currentBoard![row][col] != solution![row][col]) {
          return false;
        }
      }
    }

    return true;
  }

  // -----------------------------
  // RETRY GAME
  // -----------------------------
  void retryGame() {
    currentBoard = puzzle!.map((row) => List<int>.from(row)).toList();
    notes = _emptyNotes();
    wrongCells = _emptyWrongCells();
    _history.clear();

    mistakes = 0;
    elapsedSeconds = 0;
    hintsUsedThisLevel = 0;
    completionReward = 0;

    gameOver = false;
    gameCompleted = false;
    isPaused = false;
    completedAfterRetry = true;

    hasActiveGame = true;

    _saveLocalGameData();

    notifyListeners();
  }

  // -----------------------------
  // SAVE LOCAL GAME DATA
  // -----------------------------
  Future<void> _saveLocalGameData() async {
    await _storageService.saveLocalGameData(
      toJson(),
      key: isDaily ? StorageService.dailyGameKey : StorageService.savedGameKey,
    );
  }

  // -----------------------------
  // CONVERT TO JSON
  // -----------------------------
  Map<String, dynamic> toJson() {
    return {
      'puzzle': puzzle,
      'currentBoard': currentBoard,
      'solution': solution,
      'notes': notes
          .map((row) => row.map((cell) => cell.toList()).toList())
          .toList(),
      'wrongCells': wrongCells,
      'difficulty': difficulty,
      'currentLevel': currentLevel,
      'mistakes': mistakes,
      'elapsedSeconds': elapsedSeconds,
      'hintsUsedThisLevel': hintsUsedThisLevel,
      'completedAfterRetry': completedAfterRetry,
      'isDaily': isDaily,
      'dailyDateKey': dailyDateKey,
    };
  }

  // -----------------------------
  // RESTORE FROM JSON
  // -----------------------------
  bool restoreFromJson(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return false;
    }

    try {
      final restoredPuzzle = _intGridFromJson(data['puzzle']);
      final restoredBoard = _intGridFromJson(data['currentBoard']);
      final restoredSolution = _intGridFromJson(data['solution']);
      if (restoredPuzzle == null ||
          restoredBoard == null ||
          restoredSolution == null) {
        return false;
      }

      puzzle = restoredPuzzle;
      currentBoard = restoredBoard;
      solution = restoredSolution;
      notes = _notesFromJson(data['notes']);
      wrongCells = _wrongCellsFromJson(data['wrongCells']);
      difficulty = data['difficulty']?.toString() ?? 'Easy';
      currentLevel = _intFromJson(data['currentLevel'], 1);
      mistakes = _intFromJson(data['mistakes'], 0);
      elapsedSeconds = _intFromJson(data['elapsedSeconds'], 0);
      hintsUsedThisLevel = _intFromJson(data['hintsUsedThisLevel'], 0);
      completedAfterRetry = data['completedAfterRetry'] == true;
      isDaily = data['isDaily'] == true;
      dailyDateKey = data['dailyDateKey']?.toString();
      gameOver = false;
      gameCompleted = false;
      isPaused = false;
      hasActiveGame = true;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<List<int>>? _intGridFromJson(Object? data) {
    if (data is! List || data.length != 9) return null;
    final grid = <List<int>>[];
    for (final row in data) {
      if (row is! List || row.length != 9) return null;
      grid.add(row.map((value) => _intFromJson(value, 0)).toList());
    }
    return grid;
  }

  static int _intFromJson(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  // -----------------------------
  // CLEAR LOCAL GAME DATA
  // -----------------------------
  Future<void> _clearLocalGameData() async {
    await _storageService.clearLocalGameData(
      key: isDaily ? StorageService.dailyGameKey : StorageService.savedGameKey,
    );
  }

  void _captureMove(int row, int col) {
    _history.add(
      _MoveSnapshot(
        row: row,
        col: col,
        value: currentBoard![row][col],
        notes: {...notes[row][col]},
        wrong: wrongCells[row][col],
        mistakes: mistakes,
      ),
    );

    if (_history.length > 100) {
      _history.removeAt(0);
    }
  }

  // -----------------------------
  // DIFFICULTY
  // -----------------------------
  String _getDifficultyFromLevel(int level) {
    final band = ((level - 1) ~/ 10) + 1;
    if (band == 1) return 'Easy';
    if (band == 2) return 'Medium';
    if (band == 3) return 'Hard';
    if (band == 4) return 'Expert';

    return 'Expert +${band - 4}';
  }

  static List<List<Set<int>>> _emptyNotes() {
    return List.generate(9, (_) => List.generate(9, (_) => <int>{}));
  }

  static List<List<bool>> _emptyWrongCells() {
    return List.generate(9, (_) => List.generate(9, (_) => false));
  }

  static List<List<Set<int>>> _notesFromJson(Object? data) {
    if (data is! List) return _emptyNotes();

    return List.generate(9, (row) {
      final sourceRow = row < data.length && data[row] is List
          ? data[row] as List
          : const [];

      return List.generate(9, (col) {
        final sourceCell = col < sourceRow.length && sourceRow[col] is List
            ? sourceRow[col] as List
            : const [];

        return sourceCell.map((value) => value as int).toSet();
      });
    });
  }

  static List<List<bool>> _wrongCellsFromJson(Object? data) {
    if (data is! List) return _emptyWrongCells();

    return List.generate(9, (row) {
      final sourceRow = row < data.length && data[row] is List
          ? data[row] as List
          : const [];

      return List.generate(9, (col) {
        if (col >= sourceRow.length) return false;
        return sourceRow[col] == true;
      });
    });
  }
}

class _MoveSnapshot {
  const _MoveSnapshot({
    required this.row,
    required this.col,
    required this.value,
    required this.notes,
    required this.wrong,
    required this.mistakes,
  });

  final int row;
  final int col;
  final int value;
  final Set<int> notes;
  final bool wrong;
  final int mistakes;
}
