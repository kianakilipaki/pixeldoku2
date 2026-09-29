import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pixeldoku/models/competition.dart';
import 'package:pixeldoku/features/daily/daily_page.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:pixeldoku/models/theme_catalog.dart';
import 'package:pixeldoku/models/title_catalog.dart';
import 'package:pixeldoku/services/storage_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

String _formatNumber(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

String _monthName(int month) => const [
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
][month - 1].toUpperCase();

const _debugLeaderboardEntries = <GlobalLeaderboardEntry>[
  GlobalLeaderboardEntry(
    userId: 'debug-nova-kitty',
    name: 'NovaKitty',
    level: 342,
    bestTimeSeconds: 87,
    profilePicture: 'lib/assets/themes/cats/cat_1.png',
    profilePictureBgColor: 0xFF5B3D85,
    playerTitle: 'Puzzle Royalty',
  ),
  GlobalLeaderboardEntry(
    userId: 'debug-bird-master',
    name: 'BirdMaster',
    level: 318,
    bestTimeSeconds: 102,
    profilePicture: 'lib/assets/themes/birds/bird_2.png',
    profilePictureBgColor: 0xFF2E86C1,
    playerTitle: 'Lord of the Flock',
  ),
  GlobalLeaderboardEntry(
    userId: 'debug-pixel-frog',
    name: 'PixelFrog',
    level: 297,
    bestTimeSeconds: 118,
    profilePicture: 'lib/assets/themes/swamp/amphibian_1.png',
    profilePictureBgColor: 0xFF5F7F35,
    playerTitle: 'Marsh Master',
  ),
  GlobalLeaderboardEntry(
    userId: 'debug-puzzle-pup',
    name: 'PuzzlePup',
    level: 284,
    bestTimeSeconds: 135,
    profilePicture: 'lib/assets/themes/dogs/dog_1.png',
    profilePictureBgColor: 0xFFA65D2D,
    playerTitle: 'Perfect Puzzler',
  ),
  GlobalLeaderboardEntry(
    userId: 'debug-coral-sage',
    name: 'CoralSage',
    level: 271,
    bestTimeSeconds: 149,
    profilePicture: 'lib/assets/themes/fish/fish_3.png',
    profilePictureBgColor: 0xFF2E8F8C,
    playerTitle: 'Deep Sea Solver',
  ),
  GlobalLeaderboardEntry(
    userId: 'debug-night-owl',
    name: 'NightOwl',
    level: 268,
    bestTimeSeconds: 164,
    profilePicture: 'lib/assets/themes/birds/bird_5.png',
    profilePictureBgColor: 0xFF334F7D,
    playerTitle: 'Night Thinker',
  ),
  GlobalLeaderboardEntry(
    userId: 'debug-lady-pixels',
    name: 'LadyPixels',
    level: 254,
    bestTimeSeconds: 183,
    profilePicture: 'lib/assets/themes/bugs/bug_1.png',
    profilePictureBgColor: 0xFFC37432,
    playerTitle: 'Tiny Titan',
  ),
  GlobalLeaderboardEntry(
    userId: 'debug-quail-quest',
    name: 'QuailQuest',
    level: 248,
    bestTimeSeconds: 205,
    profilePicture: 'lib/assets/themes/birds/bird_7.png',
    profilePictureBgColor: 0xFF7899A8,
    playerTitle: 'Quick Wings',
  ),
  GlobalLeaderboardEntry(
    userId: 'debug-leafy-logic',
    name: 'LeafyLogic',
    level: 235,
    bestTimeSeconds: 227,
    profilePicture: 'lib/assets/themes/swamp/amphibian_4.png',
    profilePictureBgColor: 0xFF47734D,
    playerTitle: 'Forest Sage',
  ),
  GlobalLeaderboardEntry(
    userId: 'debug-maple-mint',
    name: 'MapleMint',
    level: 229,
    bestTimeSeconds: 251,
    profilePicture: 'lib/assets/themes/cats/cat_6.png',
    profilePictureBgColor: 0xFFD17A24,
    playerTitle: 'Daily Explorer',
  ),
];

/// Global rankings using the same framed forest UI as the profile screen.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final StorageService _storage = StorageService();
  final ScrollController _rankingsScrollController = ScrollController();
  List<GlobalLeaderboardEntry> _globalLeaders = const [];
  bool _loadingLeaders = true;
  String? _leaderboardError;
  CompetitionPeriod _period = CompetitionPeriod.daily;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLeaderboard());
  }

  @override
  void dispose() {
    _rankingsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    final app = context.read<AppState>();
    final period = _period;
    final request = ++_request;
    setState(() => _loadingLeaders = true);
    List<GlobalLeaderboardEntry> leaders;
    String? message;
    try {
      leaders = await _storage.loadCompetition(period.name);
    } catch (_) {
      leaders = [];
      message = 'Online rankings unavailable. Local scores are provisional.';
    }
    if (!mounted || request != _request) return;
    if (kDebugMode && leaders.isEmpty) {
      leaders = _debugLeaderboardEntries
          .map(
            (entry) => GlobalLeaderboardEntry(
              userId: entry.userId,
              name: entry.name,
              level: entry.level,
              bestTimeSeconds: entry.bestTimeSeconds,
              score:
                  RewardRules.score(
                    seconds: entry.bestTimeSeconds,
                    hints: 0,
                    heartsLost: 0,
                  ) *
                  (period == CompetitionPeriod.daily
                      ? 1
                      : period == CompetitionPeriod.weekly
                      ? 4
                      : 12),
              profilePicture: entry.profilePicture,
              profilePictureBgColor: entry.profilePictureBgColor,
              playerTitle: entry.playerTitle,
            ),
          )
          .toList();
      message = 'Test rankings — sample players cannot win prizes.';
    }
    final score = app.competitionScore(period);
    final now = DateTime.now().toUtc();
    final firstDay = GameState.formatDailyDateKey(period.start(now));
    final lastDay = GameState.formatDailyDateKey(period.end(now));
    final results = app.statistics['daily_results'];
    final localTimes = results is Map
        ? results.entries
              .where(
                (entry) =>
                    entry.key.toString().compareTo(firstDay) >= 0 &&
                    entry.key.toString().compareTo(lastDay) < 0,
              )
              .map((entry) => int.tryParse('${entry.value}') ?? 0)
              .where((time) => time > 0)
              .toList()
        : <int>[];
    localTimes.sort();
    final id = app.user?.id ?? 'local-player';
    if (message != null &&
        score > 0 &&
        !leaders.any((entry) => entry.userId == id)) {
      leaders.add(
        GlobalLeaderboardEntry(
          userId: id,
          name: app.name,
          level: app.currentLevel,
          bestTimeSeconds: localTimes.isEmpty ? 0 : localTimes.first,
          score: score,
          profilePicture: app.profilePicture,
          profilePictureBgColor: app.profilePictureBgColor,
          playerTitle: app.playerTitle,
        ),
      );
    }
    if (message != null) {
      leaders.sort((a, b) {
        final c = b.score.compareTo(a.score);
        return c != 0 ? c : a.userId.compareTo(b.userId);
      });
    }
    setState(() {
      _globalLeaders = leaders;
      _loadingLeaders = false;
      _leaderboardError = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return ForestPageShell(
      title: 'Leaderboard',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
        children: [
          SegmentedButton<CompetitionPeriod>(
            segments: CompetitionPeriod.values
                .map(
                  (period) =>
                      ButtonSegment(value: period, label: Text(period.label)),
                )
                .toList(),
            selected: {_period},
            style: SegmentedButton.styleFrom(
              foregroundColor: forestGold,
              selectedForegroundColor: Colors.black,
              selectedBackgroundColor: forestGold,
            ),
            onSelectionChanged: (selection) {
              forestTapHaptic();
              setState(() => _period = selection.first);
              _loadLeaderboard();
            },
          ),
          const SizedBox(height: 8),
          if (_period == CompetitionPeriod.daily &&
              !appState.hasCompletedDaily(
                GameState.formatDailyDateKey(DateTime.now()),
              )) ...[
            _LeaderboardPlayButton(
              label: 'Play Daily Puzzle',
              onPressed: () async {
                await Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const DailyPage()));
                if (mounted) _loadLeaderboard();
              },
            ),
            const SizedBox(height: 8),
          ],
          AspectRatio(
            aspectRatio: 536 / 899,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'lib/assets/wood/wood-panel-tall-curved-lvs.png',
                  fit: BoxFit.contain,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
                  child: _GlobalLeaderboard(
                    period: _period,
                    entries: _globalLeaders,
                    isLoading: _loadingLeaders,
                    message: _leaderboardError,
                    currentUserId: appState.user?.id ?? 'local-player',
                    scrollController: _rankingsScrollController,
                    onRefresh: _loadLeaderboard,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerSummary extends StatelessWidget {
  const PlayerSummary({required this.appState, super.key});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final levelProgress = (appState.currentLevel % 10) / 10;
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: forestTitleGoldGradient,
          ),
          child: ProfileGradientBackground(
            colorValue: appState.profilePictureBgColor,
            padding: const EdgeInsets.all(8),
            child: Image.asset(appState.profilePicture),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appState.name.toUpperCase(),
                style: const TextStyle(
                  color: forestPanelText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [forestPixelShadow],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '★  LEVEL ${appState.currentLevel}',
                style: const TextStyle(
                  color: forestGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: levelProgress,
                  minHeight: 9,
                  backgroundColor: Colors.black54,
                  valueColor: const AlwaysStoppedAnimation(forestGold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatGrid extends StatelessWidget {
  const StatGrid({required this.appState, super.key});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        Icons.emoji_events,
        '${appState.statistics['levels_completed'] ?? 0}',
        'Puzzles Solved',
      ),
      (
        Icons.star,
        '${appState.statistics['perfect_runs'] ?? 0}',
        'Perfect Runs',
      ),
      (
        Icons.gps_fixed,
        '${appState.statistics['no_mistake_wins'] ?? 0}',
        'No Mistakes',
      ),
      (
        Icons.lightbulb_outline,
        '${appState.statistics['no_hint_wins'] ?? 0}',
        'No Hints',
      ),
      (Icons.timer, '${appState.statistics['speed_runs'] ?? 0}', 'Speed Runs'),
      (
        Icons.favorite,
        '${appState.statistics['one_heart_wins'] ?? 0}',
        'Close Calls',
      ),
      (Icons.auto_awesome, '${appState.totalPoints}', 'Total Points'),
      (Icons.today, '${appState.dailyCompletions}', 'Daily Wins'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values
              .map(
                (stat) => SizedBox(
                  width: width,
                  child: _StatCard(
                    icon: stat.$1,
                    value: stat.$2,
                    label: stat.$3,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _GlobalLeaderboard extends StatelessWidget {
  const _GlobalLeaderboard({
    required this.period,
    required this.entries,
    required this.isLoading,
    required this.message,
    required this.currentUserId,
    required this.scrollController,
    required this.onRefresh,
  });

  final List<GlobalLeaderboardEntry> entries;
  final CompetitionPeriod period;
  final bool isLoading;
  final String? message;
  final String currentUserId;
  final ScrollController scrollController;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: forestGold)),
      );
    }

    final currentPlayerIndex = entries.indexWhere(
      (entry) => entry.userId == currentUserId,
    );
    final currentPlace = currentPlayerIndex < 0 ? null : currentPlayerIndex + 1;
    final now = DateTime.now().toUtc();

    void scrollToCurrentPlayer() {
      if (currentPlayerIndex < 0 || !scrollController.hasClients) return;
      final position = scrollController.position;
      final target = (currentPlayerIndex * 60.0)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -10),
          child: Image.asset(
            'lib/assets/icons/chest.png',
            height: 80,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _MonthlyPrizeBanner(
            month: _monthName(now.month),
            period: period,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _CurrentPlayerPlace(
            place: currentPlace,
            onTap: currentPlace == null ? null : scrollToCurrentPlayer,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFD37A),
              fontFamily: 'Fira Sans',
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: entries.isEmpty
                    ? const Color(0xFFF0DFC0).withValues(alpha: 0.88)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: const Text(
                          'No scores yet. Complete a Daily puzzle to enter!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF492617),
                            fontFamily: 'Fira Sans',
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        const _LeaderboardHeader(),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            padding: EdgeInsets.zero,
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return _LeaderboardRow(
                                rank: index + 1,
                                entry: entry,
                                isCurrentPlayer: entry.userId == currentUserId,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ForestPressBounce(
          child: TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: forestGold, size: 18),
            label: const Text(
              'REFRESH',
              style: TextStyle(color: forestPanelText),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyPrizeBanner extends StatelessWidget {
  const _MonthlyPrizeBanner({required this.month, required this.period});

  final String month;
  final CompetitionPeriod period;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF25170F).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: forestGold, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${period == CompetitionPeriod.monthly ? '$month ' : ''}${period.label.toUpperCase()} · 1ST PLACE PRIZE',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: forestGold,
              fontFamily: 'Silkscreen',
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'lib/assets/icons/coins.png',
                  width: 28,
                  height: 24,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(width: 5),
                Text(
                  '${_formatNumber(period.prizeForPlace(1).coins)} gold + ',
                  style: const TextStyle(
                    color: forestGold,
                    fontFamily: 'Fira Sans',
                    fontSize: 14,
                  ),
                ),
                Image.asset(
                  'lib/assets/icons/hint.png',
                  width: 22,
                  height: 24,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
                if (period.prizeForPlace(1).hints > 1)
                  Text(
                    ' ×${period.prizeForPlace(1).hints}',
                    style: const TextStyle(
                      color: forestGold,
                      fontFamily: 'Fira Sans',
                      fontSize: 14,
                    ),
                  ),
                if (period.prizeForPlace(1).hearts > 0) ...[
                  const Text(
                    ' + ',
                    style: TextStyle(color: forestGold, fontSize: 14),
                  ),
                  Image.asset(
                    'lib/assets/icons/heart.png',
                    width: 22,
                    height: 24,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    semanticLabel: 'Extra hearts',
                  ),
                  Text(
                    ' ×${period.prizeForPlace(1).hearts}',
                    style: const TextStyle(
                      color: forestGold,
                      fontFamily: 'Fira Sans',
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPlayerPlace extends StatelessWidget {
  const _CurrentPlayerPlace({required this.place, required this.onTap});

  final int? place;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: place == null
          ? 'Your current place is unranked'
          : 'Your current place is $place. Tap to show your ranking.',
      child: ForestPressBounce(
        enabled: onTap != null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            borderRadius: BorderRadius.circular(7),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2A4864).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFFB3682D)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'YOUR CURRENT PLACE',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Fira Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    place == null ? 'UNRANKED' : '#$place',
                    style: const TextStyle(
                      color: forestGold,
                      fontFamily: 'Silkscreen',
                      fontSize: 13,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: forestGold,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardPlayButton extends StatelessWidget {
  const _LeaderboardPlayButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: label,
        child: ForestPressBounce(
          child: InkWell(
            onTap: onPressed,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 300,
              child: AspectRatio(
                aspectRatio: 186 / 39,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'lib/assets/icons/button.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      excludeFromSemantics: true,
                    ),
                    Center(
                      child: Transform.translate(
                        offset: const Offset(0, -3),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label.toUpperCase(),
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Silkscreen',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                shadows: [forestPixelShadow],
                              ),
                            ),
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
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: forestPanelText,
      fontSize: 10,
      fontWeight: FontWeight.w900,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF293B3D).withValues(alpha: 0.9),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 38,
            child: Text('#', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(width: 43),
          Expanded(child: Text('PLAYER', style: style)),
          SizedBox(
            width: 58,
            child: Text(
              'TOTAL\nSCORE',
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          SizedBox(
            width: 54,
            child: Text('BEST\nTIME', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isCurrentPlayer,
  });

  final int rank;
  final GlobalLeaderboardEntry entry;
  final bool isCurrentPlayer;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF492617);

    final podiumColor = switch (rank) {
      1 => const Color(0xFFF0C759),
      2 => const Color(0xFFBEC8D2),
      3 => const Color(0xFFD39B70),
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: podiumColor ?? const Color(0xFFF0DFC0).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: rank <= 3
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      _RankingStar(rank: rank),
                      Text(
                        '$rank',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: ProfileGradientBackground(
              colorValue: entry.profilePictureBgColor,
              padding: const EdgeInsets.all(3),
              child: entry.profilePicture == null
                  ? const Icon(Icons.person, color: ink, size: 20)
                  : Image.asset(
                      entry.profilePicture!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.person, color: ink, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrentPlayer ? const Color(0xFF39713A) : ink,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  entry.playerTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: podiumColor != null ? ink : const Color(0xFF8B6238),
                    fontFamily: 'Fira Sans',
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              _formatNumber(entry.score),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 54,
            child: Text(
              entry.bestTimeSeconds > 0
                  ? '${entry.bestTimeSeconds ~/ 60}:${(entry.bestTimeSeconds % 60).toString().padLeft(2, '0')}'
                  : '—',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingStar extends StatelessWidget {
  const _RankingStar({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final star = Image.asset(
      'lib/assets/icons/star.png',
      width: 36,
      height: 36,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );

    return switch (rank) {
      2 => ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          18,
          0.2126,
          0.7152,
          0.0722,
          0,
          18,
          0.2126,
          0.7152,
          0.0722,
          0,
          28,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: star,
      ),
      3 => ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFFC07A4A),
          BlendMode.modulate,
        ),
        child: star,
      ),
      _ => star,
    };
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: BoxDecoration(
        color: const Color(0xFF111820).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF68431E), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: forestGold, size: 28),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: forestPanelText,
                  fontFamily: 'Silkscreen',
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: forestGold,
              fontFamily: 'Fira Sans',
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeProgress extends StatelessWidget {
  const ThemeProgress({required this.appState, super.key});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ThemeCatalog.themes.map((theme) {
        final completed = appState.completedPuzzlesForTheme(theme.id);
        final total = theme.iconAssets.length;
        final shownCompleted = completed.clamp(0, total);
        final progress = shownCompleted / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  theme.name.toUpperCase(),
                  style: const TextStyle(
                    color: forestPanelText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.black54,
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1 ? forestGold : const Color(0xFF1985DF),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  '$shownCompleted/$total',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: forestPanelText, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class AchievementProgress extends StatelessWidget {
  const AchievementProgress({required this.appState, super.key});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: TitleCategory.values.map((category) {
        final titles = TitleCatalog.byCategory(category);
        if (titles.isEmpty) return const SizedBox.shrink();
        final unlocked = titles
            .where((title) => title.isUnlocked(appState))
            .length;
        return ForestListRow(
          title: TitleCatalog.categoryName(category),
          subtitle: '$unlocked of ${titles.length} titles unlocked',
          leading: Icon(
            unlocked == titles.length ? Icons.emoji_events : Icons.lock_open,
            color: forestGold,
          ),
          trailing: Text(
            '$unlocked/${titles.length}',
            style: const TextStyle(
              color: forestPanelText,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }
}
