import 'dart:io';

import 'package:pixeldoku/core/utils/sudoku_generator.dart';

void main() {
  final stopwatch = Stopwatch()..start();
  final game = SudokuGenerator.generateSudoku(
    difficulty: 'Hard',
    seed: 20260901,
  );
  final duplicate = SudokuGenerator.generateSudoku(
    difficulty: 'Hard',
    seed: 20260901,
  );
  final nextDay = SudokuGenerator.generateSudoku(
    difficulty: 'Hard',
    seed: 20260902,
  );
  if ('$game' != '$duplicate') {
    throw StateError('Identical daily seeds produced different puzzles');
  }
  if ('${game['puzzle']}' == '${nextDay['puzzle']}') {
    throw StateError('Adjacent daily seeds produced the same puzzle');
  }
  _validate(game);
  for (final difficulty in ['Easy', 'Medium', 'Hard', 'Expert']) {
    _validate(SudokuGenerator.generateSudoku(difficulty: difficulty));
  }
  stdout.writeln(
    'daily and campaign boards verified in ${stopwatch.elapsedMilliseconds} ms; daily has '
    '${game['puzzle']!.expand((row) => row).where((cell) => cell == 0).length} blanks',
  );
}

void _validate(Map<String, List<List<int>>> game) {
  final puzzle = game['puzzle']!;
  final solution = game['solution']!;
  const expected = '123456789';
  for (var row = 0; row < 9; row++) {
    final rowValues = [...solution[row]]..sort();
    if (rowValues.join() != expected) throw StateError('Invalid row $row');
    for (var column = 0; column < 9; column++) {
      final clue = puzzle[row][column];
      if (clue != 0 && clue != solution[row][column]) {
        throw StateError('Clue does not match solution');
      }
    }
  }
  for (var column = 0; column < 9; column++) {
    final values = [for (var row = 0; row < 9; row++) solution[row][column]]
      ..sort();
    if (values.join() != expected) throw StateError('Invalid column $column');
  }
  for (var boxRow = 0; boxRow < 3; boxRow++) {
    for (var boxColumn = 0; boxColumn < 3; boxColumn++) {
      final values = <int>[
        for (var row = boxRow * 3; row < boxRow * 3 + 3; row++)
          for (var column = boxColumn * 3; column < boxColumn * 3 + 3; column++)
            solution[row][column],
      ]..sort();
      if (values.join() != expected) throw StateError('Invalid box');
    }
  }
}
