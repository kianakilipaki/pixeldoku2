enum CompetitionPeriod {
  daily,
  weekly,
  monthly;

  String get label => name[0].toUpperCase() + name.substring(1);

  DateTime start(DateTime time) {
    final utc = time.toUtc();
    final day = DateTime.utc(utc.year, utc.month, utc.day);
    return switch (this) {
      daily => day,
      weekly => day.subtract(Duration(days: day.weekday - 1)),
      monthly => DateTime.utc(day.year, day.month),
    };
  }

  DateTime end(DateTime time) {
    final first = start(time);
    return switch (this) {
      daily => first.add(const Duration(days: 1)),
      weekly => first.add(const Duration(days: 7)),
      monthly => DateTime.utc(first.year, first.month + 1),
    };
  }

  CompetitionPrize prizeForPlace(int place) {
    if (place < 1 || place > 3) throw RangeError.range(place, 1, 3);
    return switch (this) {
      daily => const [
        CompetitionPrize(100, 1, 0),
        CompetitionPrize(50, 1, 0),
        CompetitionPrize(25, 0, 0),
      ],
      weekly => const [
        CompetitionPrize(350, 3, 1),
        CompetitionPrize(200, 2, 1),
        CompetitionPrize(100, 1, 0),
      ],
      monthly => const [
        CompetitionPrize(1000, 10, 3, title: 'Monthly Champion'),
        CompetitionPrize(600, 6, 2),
        CompetitionPrize(300, 3, 1),
      ],
    }[place - 1];
  }

  String get podiumPrizes => [
    for (var place = 1; place <= 3; place++)
      '${const ['Gold', 'Silver', 'Bronze'][place - 1]}: ${prizeForPlace(place).description}',
  ].join('\n');
}

class CompetitionPrize {
  const CompetitionPrize(this.coins, this.hints, this.hearts, {this.title});
  final int coins;
  final int hints;
  final int hearts;
  final String? title;

  String get description => [
    '$coins coins',
    if (hints > 0) '$hints ${hints == 1 ? 'hint' : 'hints'}',
    if (hearts > 0) '$hearts ${hearts == 1 ? 'heart' : 'hearts'}',
    if (title != null) '$title title',
  ].join(' + ');
}

class RewardRules {
  /// One score per daily puzzle. Time is capped at a 30-minute penalty.
  static int score({
    required int seconds,
    required int hints,
    required int heartsLost,
  }) => (2000 - seconds.clamp(0, 1800) - hints * 200 - heartsLost * 300).clamp(
    100,
    2000,
  );

  static int coins({required int heartsLost, required bool daily}) =>
      (daily ? 100 : 50) - heartsLost.clamp(0, 2) * (daily ? 20 : 10);
}
