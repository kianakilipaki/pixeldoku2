import 'package:flutter/material.dart';
import 'package:pixeldoku/features/game/game_page.dart';
import 'package:pixeldoku/features/home/home_controller.dart';
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
  bool _loading = true;
  bool _hasSavedToday = false;

  String get _todayKey => GameState.formatDailyDateKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final saved = await _storage.loadLocalGameData(
      key: StorageService.dailyGameKey,
    );
    if (!mounted) return;
    setState(() {
      _hasSavedToday = saved?['dailyDateKey'] == _todayKey;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final completed = appState.hasCompletedDaily(_todayKey);
    final bestTime = appState.bestDailyTime(_todayKey);

    return ForestPageShell(
      title: 'Daily',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
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
                  'arrives each day at midnight UTC.',
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
                    _DailyBadge(icon: Icons.add_circle, label: '+250 POINTS'),
                    _DailyBadge(icon: Icons.paid, label: '+50 COINS'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: completed ? 'Completed' : 'Ready',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (completed) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: forestGold,
                        size: 34,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'BEST TIME  ${_formatTime(bestTime ?? 0)}',
                          style: const TextStyle(
                            color: forestPanelText,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                ForestButton(
                  label: _loading
                      ? 'Loading...'
                      : completed
                      ? 'Play Again'
                      : _hasSavedToday
                      ? 'Continue Daily'
                      : 'Start Daily',
                  onPressed: _loading ? null : _openDailyGame,
                ),
                if (completed) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Replays can improve your leaderboard time, but rewards '
                    'are earned only once per day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Fira Sans',
                      fontSize: 13,
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

  Future<void> _openDailyGame() async {
    final gameState = context.read<GameState>();
    await _controller.startOrContinueDaily(gameState);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GamePage()),
    );
    await _loadStatus();
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

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
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
