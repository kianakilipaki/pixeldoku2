import 'package:flutter/material.dart';
import 'package:pixeldoku/models/theme_catalog.dart';
import 'package:pixeldoku/models/title_catalog.dart';
import 'package:pixeldoku/services/storage_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

/// Progress overview using the same framed forest UI as the profile screen.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final StorageService _storage = StorageService();
  List<DailyLeaderboardEntry> _dailyLeaders = const [];
  bool _loadingLeaders = true;
  String? _leaderboardError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLeaderboard());
  }

  Future<void> _loadLeaderboard() async {
    final appState = context.read<AppState>();
    final dateKey = GameState.formatDailyDateKey(DateTime.now());
    try {
      final leaders = await _storage.loadDailyLeaderboard(dateKey);
      final localBest = appState.bestDailyTime(dateKey);
      final currentUserId = appState.user?.id ?? 'local-player';
      final merged = [...leaders];
      final currentIndex = merged.indexWhere(
        (entry) => entry.userId == currentUserId,
      );
      if (localBest != null) {
        final localEntry = DailyLeaderboardEntry(
          userId: currentUserId,
          name: appState.name,
          elapsedSeconds: localBest,
          profilePicture: appState.profilePicture,
        );
        if (currentIndex == -1) {
          merged.add(localEntry);
        } else if (localBest < merged[currentIndex].elapsedSeconds) {
          merged[currentIndex] = localEntry;
        }
        merged.sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
      }
      if (!mounted) return;
      setState(() {
        _dailyLeaders = merged.take(25).toList(growable: false);
        _loadingLeaders = false;
        _leaderboardError = null;
      });
    } catch (_) {
      if (!mounted) return;
      final localBest = appState.bestDailyTime(dateKey);
      setState(() {
        _dailyLeaders = localBest == null
            ? const []
            : [
                DailyLeaderboardEntry(
                  userId: appState.user?.id ?? 'local-player',
                  name: appState.name,
                  elapsedSeconds: localBest,
                  profilePicture: appState.profilePicture,
                ),
              ];
        _loadingLeaders = false;
        _leaderboardError = 'Online rankings are unavailable right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return ForestPageShell(
      title: 'Stats',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          ForestSection(
            title: 'Player',
            child: _PlayerSummary(appState: appState),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Puzzle Stats',
            child: _StatGrid(appState: appState),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Daily Leaderboard',
            child: _DailyLeaderboard(
              entries: _dailyLeaders,
              isLoading: _loadingLeaders,
              message: _leaderboardError,
              currentUserId: appState.user?.id ?? 'local-player',
              onRefresh: _loadLeaderboard,
            ),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Themes Progress',
            child: _ThemeProgress(appState: appState),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Achievements',
            child: _AchievementProgress(appState: appState),
          ),
        ],
      ),
    );
  }
}

class _PlayerSummary extends StatelessWidget {
  const _PlayerSummary({required this.appState});
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
            gradient: forestShinyGold,
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

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.appState});
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

class _DailyLeaderboard extends StatelessWidget {
  const _DailyLeaderboard({
    required this.entries,
    required this.isLoading,
    required this.message,
    required this.currentUserId,
    required this.onRefresh,
  });

  final List<DailyLeaderboardEntry> entries;
  final bool isLoading;
  final String? message;
  final String currentUserId;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: forestGold)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'FASTEST TIMES TODAY · HARD · RESETS 00:00 UTC',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Fira Sans',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
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
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF111820).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF68431E), width: 2),
            ),
            child: const Text(
              'No times yet. Finish today\'s Daily puzzle to take the first spot!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Fira Sans',
                fontSize: 14,
                height: 1.3,
              ),
            ),
          )
        else
          ...List.generate(entries.length, (index) {
            final entry = entries[index];
            return _LeaderboardRow(
              rank: index + 1,
              entry: entry,
              isCurrentPlayer: entry.userId == currentUserId,
            );
          }),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, color: forestGold, size: 18),
          label: const Text(
            'REFRESH',
            style: TextStyle(color: forestPanelText),
          ),
        ),
      ],
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
  final DailyLeaderboardEntry entry;
  final bool isCurrentPlayer;

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (rank) {
      1 => const Color(0xFFFFD34E),
      2 => const Color(0xFFD8E1E8),
      3 => const Color(0xFFC77B42),
      _ => Colors.white70,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isCurrentPlayer
            ? forestPanelBlue.withValues(alpha: 0.96)
            : const Color(0xFF111820).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentPlayer ? forestGold : const Color(0xFF68431E),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: medalColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (entry.profilePicture != null) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF385A82),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Image.asset(
                  entry.profilePicture!,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(
              entry.name.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(entry.elapsedSeconds),
            style: const TextStyle(
              color: forestPanelText,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
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

class _ThemeProgress extends StatelessWidget {
  const _ThemeProgress({required this.appState});
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

class _AchievementProgress extends StatelessWidget {
  const _AchievementProgress({required this.appState});
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
