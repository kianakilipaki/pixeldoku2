import 'package:flutter_test/flutter_test.dart';
import 'package:pixeldoku/state/game_state.dart';

void main() {
  test('campaign difficulty repeats every ten levels', () {
    const expected = [
      'Easy',
      'Easy',
      'Easy',
      'Medium',
      'Medium',
      'Medium',
      'Medium',
      'Medium',
      'Hard',
      'Hard',
    ];

    for (var level = 1; level <= 30; level++) {
      expect(
        GameState.difficultyForLevel(level),
        expected[(level - 1) % 10],
        reason: 'Level $level',
      );
    }
  });

  test('daily puzzle remains labeled Hard but has 54 empty cells', () {
    final game = GameState()..startDailyGame(date: DateTime.utc(2026, 9, 28));

    expect(game.difficulty, 'Hard');
    expect(
      game.puzzle!.expand((row) => row).where((cell) => cell == 0).length,
      54,
    );
  });
}
