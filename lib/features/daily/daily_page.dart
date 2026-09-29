import 'package:flutter/material.dart';
import 'package:pixeldoku/features/game/game_page.dart';
import 'package:pixeldoku/features/home/home_controller.dart';
import 'package:pixeldoku/features/profile/stats_page.dart';
import 'package:pixeldoku/services/storage_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

/// Entry point for the shared hard puzzle that changes at midnight UTC.
class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  final HomeController _controller = HomeController();
  final StorageService _storage = StorageService();
  late DateTime _visibleMonth;
  bool _loading = true;
  bool _savedAttemptEnded = false;
  bool _opening = false;

  String get _todayKey => GameState.formatDailyDateKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().toUtc();
    _visibleMonth = DateTime.utc(today.year, today.month);
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final saved = await _storage.loadLocalGameData(
      key: StorageService.dailyGameKey,
    );
    if (!mounted) return;
    setState(() {
      _savedAttemptEnded =
          saved?['dailyDateKey'] == _todayKey &&
          (saved?['gameOver'] == true || saved?['gameCompleted'] == true);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final canPlay =
        !_loading &&
        !_opening &&
        !_savedAttemptEnded &&
        appState.dailyOutcome(_todayKey) == null;

    return ForestPageShell(
      title: 'Daily',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          ForestSection(
            title: 'Daily Calendar',
            child: _DailyCalendar(
              month: _visibleMonth,
              today: DateTime.now().toUtc(),
              appState: appState,
              onPreviousMonth: _showPreviousMonth,
              onNextMonth: _isCurrentMonth(_visibleMonth)
                  ? null
                  : _showNextMonth,
              onTodayTap: canPlay ? _openDailyGame : null,
            ),
          ),
          if (!appState.hasCompletedDaily(_todayKey)) ...[
            const SizedBox(height: 12),
            _DailyImageButton(
              asset: 'lib/assets/icons/button.png',
              label: 'PLAY DAILY',
              onPressed: canPlay ? _openDailyGame : null,
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              "You have already completed today's daily. Come back tomorrow for a new puzzle to challenge.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: forestPanelText,
                fontFamily: 'Fira Sans',
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 20),
          ForestSection(
            title: 'Today\'s Challenge',
            child: Column(
              children: [
                Image.asset(
                  'lib/assets/icons/daily.png',
                  height: 60,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(height: 10),
                Text(
                  _displayDate(DateTime.now().toUtc()).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: forestPanelText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [forestPixelShadow],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every player gets the same Hard puzzle. A new board '
                  'arrives each day at midnight UTC. One attempt per day; no retries.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Fira Sans',
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _DailyBadge(
                      icon: Icons.local_fire_department,
                      label: 'HARD',
                    ),
                    _DailyBadge(icon: Icons.add_circle, label: 'SCORED RUN'),
                    _DailyBadge(icon: Icons.paid, label: '60–100 COINS'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DailyImageButton(
            asset: 'lib/assets/icons/button-2.png',
            label: 'LEADERBOARD',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardPage()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDailyGame() async {
    if (_opening || _loading || _savedAttemptEnded) return;
    final appState = context.read<AppState>();
    if (appState.dailyOutcome(_todayKey) != null) return;
    setState(() => _opening = true);
    final gameState = context.read<GameState>();
    try {
      final started = await _controller.startOrContinueDaily(
        gameState,
        appState,
      );
      if (!mounted) return;
      if (started) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GamePage()),
        );
      }
      await _loadStatus();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime.utc(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _showNextMonth() {
    if (_isCurrentMonth(_visibleMonth)) return;
    setState(() {
      _visibleMonth = DateTime.utc(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  static bool _isCurrentMonth(DateTime month) {
    final today = DateTime.now().toUtc();
    return month.year == today.year && month.month == today.month;
  }

  static String _displayDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _DailyCalendar extends StatelessWidget {
  const _DailyCalendar({
    required this.month,
    required this.today,
    required this.appState,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onTodayTap,
  });

  final DateTime month;
  final DateTime today;
  final AppState appState;
  final VoidCallback onPreviousMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback? onTodayTap;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime.utc(month.year, month.month);
    final leadingDays = firstDay.weekday % DateTime.daysPerWeek;
    final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
    final cellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      children: [
        Row(
          children: [
            ForestPressBounce(
              child: IconButton(
                onPressed: onPreviousMonth,
                tooltip: 'Previous month',
                color: forestPanelText,
                icon: const Icon(Icons.chevron_left, size: 30),
              ),
            ),
            Expanded(
              child: Text(
                '${_monthNames[month.month - 1].toUpperCase()} ${month.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: forestPanelText,
                  fontFamily: 'Silkscreen',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [forestPixelShadow],
                ),
              ),
            ),
            ForestPressBounce(
              enabled: onNextMonth != null,
              child: IconButton(
                onPressed: onNextMonth,
                tooltip: 'Next month',
                color: forestPanelText,
                disabledColor: Colors.white24,
                icon: const Icon(Icons.chevron_right, size: 30),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            _WeekdayLabel('SUN'),
            _WeekdayLabel('MON'),
            _WeekdayLabel('TUE'),
            _WeekdayLabel('WED'),
            _WeekdayLabel('THU'),
            _WeekdayLabel('FRI'),
            _WeekdayLabel('SAT'),
          ],
        ),
        const SizedBox(height: 5),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final day = index - leadingDays + 1;
            if (day < 1 || day > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime.utc(month.year, month.month, day);
            final dateKey = GameState.formatDailyDateKey(date);
            final isToday = _sameDate(date, today);
            final outcome = appState.dailyOutcome(dateKey);

            return _CalendarDay(
              day: day,
              outcome: outcome,
              isToday: isToday,
              onTap: isToday ? onTodayTap : null,
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'ONE ATTEMPT EACH DAY • TAP TODAY TO PLAY',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: forestGold,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.outcome,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final String? outcome;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (outcome) {
      'perfect' => const Color(0xFF4B9A4A),
      'complete' => forestGold,
      'failed' => const Color(0xFFB44337),
      _ => isToday ? const Color(0xFFB3682D) : Colors.black54,
    };
    final stampAsset = switch (outcome) {
      'perfect' => 'lib/assets/icons/daily-stamp-perfect.png',
      'complete' => 'lib/assets/icons/daily-stamp-complete.png',
      'failed' => 'lib/assets/icons/daily-stamp-failed.png',
      _ => null,
    };

    return Semantics(
      button: onTap != null,
      label: outcome == 'perfect'
          ? 'Day $day, completed without mistakes'
          : outcome == 'complete'
          ? 'Day $day, completed with mistakes'
          : outcome == 'failed'
          ? 'Day $day, failed'
          : isToday
          ? 'Day $day, today, tap to play'
          : 'Day $day, not completed',
      child: ForestPressBounce(
        enabled: onTap != null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF111820).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: borderColor, width: isToday ? 2 : 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isToday ? Colors.white : forestPanelText,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (stampAsset != null)
                    Transform.rotate(
                      angle: switch (outcome) {
                        'perfect' => -0.25,
                        'complete' => -0.35,
                        'failed' => 0.28,
                        _ => 0,
                      },
                      child: Image.asset(
                        stampAsset,
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    )
                  else if (isToday && onTap != null)
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'PLAY',
                          style: TextStyle(
                            color: forestGold,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyImageButton extends StatelessWidget {
  const _DailyImageButton({
    required this.asset,
    required this.label,
    required this.onPressed,
  });

  final String asset;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ForestPressBounce(
        enabled: onPressed != null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: AspectRatio(
            aspectRatio: asset.endsWith('button.png') ? 186 / 39 : 152 / 38,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  excludeFromSemantics: true,
                  color: onPressed == null ? const Color(0xFFAAAAAA) : null,
                  colorBlendMode: BlendMode.modulate,
                ),
                TextButton(
                  onPressed: onPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: forestPanelText,
                    disabledForegroundColor: forestPanelText,
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: 'Silkscreen',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [forestPixelShadow],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyBadge extends StatelessWidget {
  const _DailyBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: forestPanelBlue.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: forestGold, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: forestGold, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
