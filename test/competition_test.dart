import 'package:flutter_test/flutter_test.dart';
import 'package:pixeldoku/models/competition.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/features/home/home_controller.dart';
import 'package:pixeldoku/models/title_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('theme titles unlock one at a time through theme completions', () async {
    final app = AppState();
    final birdTitles = TitleCatalog.byCategory(
      TitleCategory.theme,
    ).where((title) => title.themeId == 'birds').toList();
    expect(birdTitles, hasLength(5));
    expect(birdTitles[0].isUnlocked(app), isTrue);
    expect(birdTitles[1].isUnlocked(app), isFalse);

    for (var completion = 1; completion <= 4; completion++) {
      await app.recordLevelCompleted(
        difficulty: 'Easy',
        reducedReward: false,
        mistakes: 0,
        hintsUsed: 0,
        elapsedSeconds: 60,
        themeId: 'birds',
      );
      expect(birdTitles[completion].isUnlocked(app), isTrue);
      if (completion < 4) {
        expect(birdTitles[completion + 1].isUnlocked(app), isFalse);
      }
    }
  });
  test('failed daily cannot restart and daily retry does nothing', () async {
    final app = AppState();
    final game = GameState()..startDailyGame();
    final today = game.dailyDateKey!;
    game.mistakes = 3;
    game.gameOver = true;
    game.retryGame();
    expect(game.gameOver, isTrue);
    expect(game.mistakes, 3);
    await app.recordDailyFailure(today);
    expect(await HomeController().startOrContinueDaily(game, app), isFalse);
    expect(game.gameOver, isTrue);
  });
  test('completed daily cannot be replayed', () async {
    final app = AppState();
    final today = GameState.formatDailyDateKey(DateTime.now());
    await app.recordLevelCompleted(
      difficulty: 'Hard',
      reducedReward: false,
      mistakes: 0,
      hintsUsed: 0,
      elapsedSeconds: 60,
      themeId: 'birds',
      isDaily: true,
      dailyDateKey: today,
    );
    expect(
      await HomeController().startOrContinueDaily(GameState(), app),
      isFalse,
    );
  });
  test('heart bundle costs 100 coins and adds three usable hearts', () async {
    final app = AppState()..coins = 150;
    expect(await app.buyHeartBundle(), isTrue);
    expect(app.coins, 50);
    expect(app.spareHearts, 3);
    expect(await app.buyHeartBundle(), isFalse);
    expect(app.coins, 50);
    expect(app.spareHearts, 3);
    expect(await app.useSpareHeart(), isTrue);
    expect(app.spareHearts, 2);
  });
  test('heart bundle can be bought with exactly 100 coins', () async {
    final app = AppState()..coins = 100;
    expect(await app.buyHeartBundle(), isTrue);
    expect(app.coins, 0);
    expect(app.spareHearts, 3);
  });
  test(
    'themes cost 500 coins and owned themes cannot be bought twice',
    () async {
      final app = AppState()..coins = 1000;
      expect(
        app.lockedThemes.map((theme) => theme.id),
        isNot(contains('birds')),
      );
      expect(await app.buyTheme('cats'), isTrue);
      expect(app.coins, 500);
      expect(app.unlockedThemes, contains('cats'));
      expect(
        app.lockedThemes.map((theme) => theme.id),
        isNot(contains('cats')),
      );
      expect(await app.buyTheme('cats'), isFalse);
      expect(await app.buyTheme('missing'), isFalse);
      expect(app.coins, 500);
      expect(await app.buyTheme('bugs'), isTrue);
      expect(app.coins, 0);
      expect(await app.buyTheme('cats'), isFalse);
    },
  );
  test('podium prizes decrease by rank and monthly title is gold only', () {
    for (final period in CompetitionPeriod.values) {
      final gold = period.prizeForPlace(1);
      final silver = period.prizeForPlace(2);
      final bronze = period.prizeForPlace(3);
      expect(gold.coins, greaterThan(silver.coins));
      expect(silver.coins, greaterThan(bronze.coins));
      expect(gold.hints, greaterThanOrEqualTo(silver.hints));
      expect(silver.hints, greaterThanOrEqualTo(bronze.hints));
      expect(gold.hearts, greaterThanOrEqualTo(silver.hearts));
      expect(silver.hearts, greaterThanOrEqualTo(bronze.hearts));
      expect(silver.title, isNull);
      expect(bronze.title, isNull);
    }
    expect(
      CompetitionPeriod.monthly.prizeForPlace(1).title,
      'Monthly Champion',
    );
    expect(() => CompetitionPeriod.daily.prizeForPlace(4), throwsRangeError);
  });
  test(
    'only first daily completion earns points and establishes its score',
    () async {
      final app = AppState();
      await app.recordLevelCompleted(
        difficulty: 'Hard',
        reducedReward: false,
        mistakes: 1,
        hintsUsed: 1,
        elapsedSeconds: 120,
        themeId: 'birds',
        isDaily: true,
        dailyDateKey: '20260916',
      );
      expect(app.dailyScore('20260916'), 1380);
      final points = app.totalPoints;
      await app.recordLevelCompleted(
        difficulty: 'Hard',
        reducedReward: false,
        mistakes: 0,
        hintsUsed: 0,
        elapsedSeconds: 30,
        themeId: 'birds',
        isDaily: true,
        dailyDateKey: '20260916',
      );
      expect(app.dailyScore('20260916'), 1380);
      expect(app.bestDailyTime('20260916'), 120);
      expect(app.totalPoints, points);
    },
  );
  test('score rewards speed and penalizes each hint and lost heart', () {
    expect(RewardRules.score(seconds: 120, hints: 0, heartsLost: 0), 1880);
    expect(RewardRules.score(seconds: 180, hints: 0, heartsLost: 0), 1820);
    expect(RewardRules.score(seconds: 120, hints: 1, heartsLost: 0), 1680);
    expect(RewardRules.score(seconds: 120, hints: 0, heartsLost: 1), 1580);
    expect(RewardRules.score(seconds: 86400, hints: 81, heartsLost: 10), 100);
  });
  test('completion coins depend only on lost hearts and puzzle type', () {
    expect(RewardRules.coins(heartsLost: 0, daily: true), 100);
    expect(RewardRules.coins(heartsLost: 1, daily: true), 80);
    expect(RewardRules.coins(heartsLost: 2, daily: true), 60);
    expect(RewardRules.coins(heartsLost: 0, daily: false), 50);
    expect(RewardRules.coins(heartsLost: 2, daily: false), 30);
  });
  test('UTC periods roll over on day, Monday and month boundaries', () {
    final time = DateTime.utc(2026, 9, 16, 23, 59);
    expect(CompetitionPeriod.daily.start(time), DateTime.utc(2026, 9, 16));
    expect(CompetitionPeriod.daily.end(time), DateTime.utc(2026, 9, 17));
    expect(CompetitionPeriod.weekly.start(time), DateTime.utc(2026, 9, 14));
    expect(CompetitionPeriod.weekly.end(time), DateTime.utc(2026, 9, 21));
    expect(
      CompetitionPeriod.monthly.end(DateTime.utc(2026, 12, 31)),
      DateTime.utc(2027),
    );
  });
  test(
    'spare heart resumes the same board with exactly one remaining heart',
    () async {
      final game = GameState();
      final board = List.generate(9, (_) => List.filled(9, 0));
      game.currentBoard = board;
      game.gameOver = true;
      game.mistakes = 3;
      game.elapsedSeconds = 95;
      game.hintsUsedThisLevel = 2;
      final app = AppState()..statistics = {'spare_hearts': 2};
      expect(await app.useSpareHeart(), true);
      game.addSpareHeart();
      expect(app.spareHearts, 1);
      expect(game.gameOver, false);
      expect(game.maxMistakes - game.mistakes, 1);
      expect(identical(game.currentBoard, board), true);
      expect(game.elapsedSeconds, 95);
      expect(game.hintsUsedThisLevel, 2);
      expect(game.scoreMistakes, 3);
      // Calling the continuation again while alive grants nothing.
      game.addSpareHeart();
      expect(game.maxMistakes - game.mistakes, 1);
    },
  );
  test('daily retry cannot reset time, hints or lost hearts', () {
    final game = GameState()..isDaily = true;
    game.elapsedSeconds = 95;
    game.hintsUsedThisLevel = 2;
    game.mistakes = 3;
    game.puzzle = List.generate(9, (_) => List.filled(9, 0));
    game.solution = List.generate(9, (_) => List.filled(9, 1));
    game.retryGame();
    expect(game.elapsedSeconds, 95);
    expect(game.hintsUsedThisLevel, 2);
    expect(game.scoreMistakes, 3);
    expect(game.mistakes, 3);
  });
}
