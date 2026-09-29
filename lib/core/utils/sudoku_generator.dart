import 'dart:math';

class SudokuGenerator {
  static final Random _random = Random();

  // -----------------------------
  // GENERATE SUDOKU
  // -----------------------------
  static Map<String, List<List<int>>> generateSudoku({
    String difficulty = 'Easy',
    int? seed,
  }) {
    final random = seed == null ? _random : Random(seed);
    if (difficulty == 'Daily Hard') {
      return _generateTemplatePuzzle(
        random: random,
        basePuzzle: _expertPuzzle,
        baseSolution: _expertSolution,
        targetBlanks: 54,
      );
    }
    if (difficulty.startsWith('Expert')) {
      return _generateTemplatePuzzle(
        random: random,
        basePuzzle: _expertPuzzle,
        baseSolution: _expertSolution,
        targetBlanks: 60,
      );
    }
    final targetBlanks = switch (difficulty) {
      'Easy' => 30,
      'Medium' => 40,
      _ => 45,
    };
    return _generateTemplatePuzzle(
      random: random,
      basePuzzle: _hardPuzzle,
      baseSolution: _hardSolution,
      targetBlanks: targetBlanks,
    );
  }

  static Map<String, List<List<int>>> _generateTemplatePuzzle({
    required Random random,
    required List<List<int>> basePuzzle,
    required List<List<int>> baseSolution,
    required int targetBlanks,
  }) {
    final digits = List<int>.generate(9, (index) => index + 1)..shuffle(random);
    final rows = _shuffledUnitOrder(random);
    final columns = _shuffledUnitOrder(random);

    int transformValue(int value) => value == 0 ? 0 : digits[value - 1];
    final puzzle = List.generate(
      9,
      (row) => List.generate(
        9,
        (column) => transformValue(basePuzzle[rows[row]][columns[column]]),
      ),
    );
    final solution = List.generate(
      9,
      (row) => List.generate(
        9,
        (column) => transformValue(baseSolution[rows[row]][columns[column]]),
      ),
    );

    final blankCells = <(int, int)>[
      for (var row = 0; row < 9; row++)
        for (var column = 0; column < 9; column++)
          if (puzzle[row][column] == 0) (row, column),
    ]..shuffle(random);
    final blanksToFill = blankCells.length - targetBlanks;
    for (var index = 0; index < blanksToFill; index++) {
      final (row, column) = blankCells[index];
      puzzle[row][column] = solution[row][column];
    }

    return {'puzzle': puzzle, 'solution': solution};
  }

  static const List<List<int>> _hardPuzzle = [
    [0, 0, 0, 2, 6, 0, 7, 0, 1],
    [6, 8, 0, 0, 7, 0, 0, 9, 0],
    [1, 9, 0, 0, 0, 4, 5, 0, 0],
    [8, 2, 0, 1, 0, 0, 0, 4, 0],
    [0, 0, 4, 6, 0, 2, 9, 0, 0],
    [0, 5, 0, 0, 0, 3, 0, 2, 8],
    [0, 0, 9, 3, 0, 0, 0, 7, 4],
    [0, 4, 0, 0, 5, 0, 0, 3, 6],
    [7, 0, 3, 0, 1, 8, 0, 0, 0],
  ];

  static const List<List<int>> _hardSolution = [
    [4, 3, 5, 2, 6, 9, 7, 8, 1],
    [6, 8, 2, 5, 7, 1, 4, 9, 3],
    [1, 9, 7, 8, 3, 4, 5, 6, 2],
    [8, 2, 6, 1, 9, 5, 3, 4, 7],
    [3, 7, 4, 6, 8, 2, 9, 1, 5],
    [9, 5, 1, 7, 4, 3, 6, 2, 8],
    [5, 1, 9, 3, 2, 6, 8, 7, 4],
    [2, 4, 8, 9, 5, 7, 1, 3, 6],
    [7, 6, 3, 4, 1, 8, 2, 5, 9],
  ];

  static const List<List<int>> _expertPuzzle = [
    [8, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 3, 6, 0, 0, 0, 0, 0],
    [0, 7, 0, 0, 9, 0, 2, 0, 0],
    [0, 5, 0, 0, 0, 7, 0, 0, 0],
    [0, 0, 0, 0, 4, 5, 7, 0, 0],
    [0, 0, 0, 1, 0, 0, 0, 3, 0],
    [0, 0, 1, 0, 0, 0, 0, 6, 8],
    [0, 0, 8, 5, 0, 0, 0, 1, 0],
    [0, 9, 0, 0, 0, 0, 4, 0, 0],
  ];

  static const List<List<int>> _expertSolution = [
    [8, 1, 2, 7, 5, 3, 6, 4, 9],
    [9, 4, 3, 6, 8, 2, 1, 7, 5],
    [6, 7, 5, 4, 9, 1, 2, 8, 3],
    [1, 5, 4, 2, 3, 7, 8, 9, 6],
    [3, 6, 9, 8, 4, 5, 7, 2, 1],
    [2, 8, 7, 1, 6, 9, 5, 3, 4],
    [5, 2, 1, 9, 7, 4, 3, 6, 8],
    [4, 3, 8, 5, 2, 6, 9, 1, 7],
    [7, 9, 6, 3, 1, 8, 4, 5, 2],
  ];

  static List<int> _shuffledUnitOrder(Random random) {
    final units = [0, 1, 2]..shuffle(random);
    return [
      for (final unit in units)
        ...([0, 1, 2]..shuffle(random)).map((offset) => unit * 3 + offset),
    ];
  }

  // -----------------------------
  // CHECK VALID PLACEMENT
  // -----------------------------
  static bool isValidPlacement(
    List<List<int>> board,
    int row,
    int col,
    int num,
  ) {
    for (int i = 0; i < 9; i++) {
      if (board[row][i] == num || board[i][col] == num) {
        return false;
      }

      int boxRow = (row ~/ 3) * 3 + (i ~/ 3);
      int boxCol = (col ~/ 3) * 3 + (i % 3);

      if (board[boxRow][boxCol] == num) {
        return false;
      }
    }

    return true;
  }

  // -----------------------------
  // FILL BOARD RECURSIVELY
  // -----------------------------
  static bool fillBoard(List<List<int>> board, {Random? random}) {
    List<int> numbers = getRandomNumbers(random: random);

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          for (int num in numbers) {
            if (isValidPlacement(board, row, col, num)) {
              board[row][col] = num;

              if (fillBoard(board, random: random)) {
                return true;
              }

              // Backtrack
              board[row][col] = 0;
            }
          }

          return false;
        }
      }
    }

    return true;
  }

  // -----------------------------
  // COUNT SOLUTIONS
  // -----------------------------
  static int countSolutions(List<List<int>> board) {
    List<List<int>> cloneBoard = board
        .map((row) => List<int>.from(row))
        .toList();

    int solutionCount = 0;

    void solve(List<List<int>> grid) {
      if (solutionCount >= 2) return;

      var bestRow = -1;
      var bestCol = -1;
      var bestCandidates = <int>[];
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (grid[row][col] != 0) continue;
          final candidates = <int>[
            for (int number = 1; number <= 9; number++)
              if (isValidPlacement(grid, row, col, number)) number,
          ];
          if (candidates.isEmpty) return;
          if (bestRow == -1 || candidates.length < bestCandidates.length) {
            bestRow = row;
            bestCol = col;
            bestCandidates = candidates;
            if (candidates.length == 1) break;
          }
        }
        if (bestCandidates.length == 1) break;
      }

      if (bestRow == -1) {
        solutionCount++;
        return;
      }

      for (final number in bestCandidates) {
        grid[bestRow][bestCol] = number;
        solve(grid);
        grid[bestRow][bestCol] = 0;
        if (solutionCount >= 2) return;
      }
    }

    solve(cloneBoard);

    return solutionCount;
  }

  // -----------------------------
  // REMOVE CELLS
  // -----------------------------
  static List<List<int>> removeCells(
    List<List<int>> board,
    String difficulty, {
    Random? random,
  }) {
    Map<String, int> difficultyMap = {
      'Easy': 30,
      'Medium': 40,
      'Hard': 50,
      'Expert': 56,
    };

    int targetRemovals =
        difficultyMap[difficulty] ?? _extraExpertRemovals(difficulty);
    int removedCells = 0;

    List<List<int>> positions = [];

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        positions.add([row, col]);
      }
    }

    shuffleArray(positions, random: random);

    for (List<int> pos in positions) {
      if (removedCells >= targetRemovals) {
        break;
      }

      int row = pos[0];
      int col = pos[1];

      int backup = board[row][col];

      board[row][col] = 0;

      if (countSolutions(board) == 1) {
        removedCells++;
      } else {
        board[row][col] = backup;
      }
    }

    return board;
  }

  static int _extraExpertRemovals(String difficulty) {
    final match = RegExp(r'Expert \+(\d+)').firstMatch(difficulty);
    final extraBand = int.tryParse(match?.group(1) ?? '0') ?? 0;

    return min(64, 56 + extraBand);
  }

  // -----------------------------
  // SHUFFLE ARRAY
  // -----------------------------
  static List<T> shuffleArray<T>(List<T> array, {Random? random}) {
    array.shuffle(random ?? _random);
    return array;
  }

  // -----------------------------
  // RANDOM NUMBERS
  // -----------------------------
  static List<int> getRandomNumbers({Random? random}) {
    List<int> nums = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    nums.shuffle(random ?? _random);
    return nums;
  }

  // -----------------------------
  // SHUFFLE ROWS AND COLUMNS
  // -----------------------------
  static void shuffleRowsAndColumns(List<List<int>> board, {Random? random}) {
    final shuffler = random ?? _random;
    // Shuffle rows within each 3-row group
    for (int i = 0; i < 9; i += 3) {
      List<int> rows = [i, i + 1, i + 2];
      rows.shuffle(shuffler);

      List<List<int>> temp = [
        List<int>.from(board[rows[0]]),
        List<int>.from(board[rows[1]]),
        List<int>.from(board[rows[2]]),
      ];

      for (int j = 0; j < 3; j++) {
        board[i + j] = temp[j];
      }
    }

    // Shuffle columns within each 3-column group
    for (int box = 0; box < 3; box++) {
      int start = box * 3;

      List<int> cols = [start, start + 1, start + 2];
      cols.shuffle(shuffler);

      for (int row = 0; row < 9; row++) {
        List<int> temp = [
          board[row][cols[0]],
          board[row][cols[1]],
          board[row][cols[2]],
        ];

        for (int j = 0; j < 3; j++) {
          board[row][start + j] = temp[j];
        }
      }
    }
  }
}
