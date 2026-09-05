import 'package:flutter_test/flutter_test.dart';
import 'package:pixeldoku/core/utils/sudoku_generator.dart';

void main() {
  test('daily seed creates the same hard puzzle for every user', () {
    final first = SudokuGenerator.generateSudoku(
      difficulty: 'Hard',
      seed: 20260831,
    );
    final second = SudokuGenerator.generateSudoku(
      difficulty: 'Hard',
      seed: 20260831,
    );

    expect(second['puzzle'], first['puzzle']);
    expect(second['solution'], first['solution']);
    expect(
      first['puzzle']!.expand((row) => row).where((cell) => cell == 0).length,
      45,
    );
    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        final clue = first['puzzle']![row][column];
        if (clue != 0) expect(clue, first['solution']![row][column]);
      }
    }
  });

  test('a different daily seed changes the puzzle', () {
    final first = SudokuGenerator.generateSudoku(
      difficulty: 'Hard',
      seed: 20260831,
    );
    final nextDay = SudokuGenerator.generateSudoku(
      difficulty: 'Hard',
      seed: 20260901,
    );

    expect(nextDay['puzzle'], isNot(first['puzzle']));
  });
}
