import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pixeldoku/models/competition.dart';
import 'package:pixeldoku/features/game/game_controller.dart';
import 'package:pixeldoku/features/shop/coin_shop_page.dart';
import 'package:pixeldoku/features/themes/themes_page.dart';
import 'package:pixeldoku/models/theme_catalog.dart';
import 'package:pixeldoku/services/audio_service.dart';
import 'package:pixeldoku/services/ads_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:pixeldoku/widgets/unlock_notification.dart';
import 'package:provider/provider.dart';

const _boardPanelAsset = 'lib/assets/wood/wood-panel-curved-lvs.png';
const _successPanelAsset = 'lib/assets/wood/wood-panel-md-curved-lvs.png';
const _failurePanelAsset = 'lib/assets/wood/wood-panel-md-curved.png';
const _animalButtonAsset = 'lib/assets/wood/wood-button.png';
const _gameInk = Color(0xFF171C1A);
const _woodLight = Color(0xFFC17830);
const _buttonBorderBrown = Color(0xFFC17830);
const _givenCell = Color(0xFFD2C7AD);
const _playerCell = Color(0xFFECE3D2);
const _selectedCell = Color(0xFFD6AD55);
const _sameAnimalCell = Color.fromARGB(255, 129, 176, 196);
const _helperCell = Color(0xFFBBC4B5);
const _wrongCell = Color(0xFFA96057);
const _hintedCell = Color.fromARGB(255, 150, 182, 132);

class _GamePalette {
  const _GamePalette(this.dark, this.mid, this.light, this.accent);

  final Color dark;
  final Color mid;
  final Color light;
  final Color accent;
}

_GamePalette _paletteForTheme(String themeId) {
  return switch (themeId) {
    'birds' => const _GamePalette(
      Color(0xFF536470),
      Color(0xFF858C90),
      Color(0xFFE6E3DA),
      Color(0xFFD2A94F),
    ),
    'cats' => const _GamePalette(
      Color(0xFF684E68),
      Color(0xFF94616D),
      Color(0xFFE6CFC5),
      Color(0xFFC78F8C),
    ),
    'dogs' => const _GamePalette(
      Color(0xFF523D2B),
      Color(0xFF836346),
      Color(0xFFE0CCAA),
      Color(0xFF7B7756),
    ),
    'bugs' => const _GamePalette(
      Color(0xFF38432F),
      Color(0xFF696B50),
      Color(0xFFB57935),
      Color(0xFF4A3324),
    ),
    'fish' => const _GamePalette(
      Color(0xFF405968),
      Color(0xFF7698A2),
      Color(0xFFE7D9CB),
      Color(0xFFB76955),
    ),
    'swamp' => const _GamePalette(
      Color(0xFF414534),
      Color(0xFF656C56),
      Color(0xFFAAA36D),
      Color(0xFFA77B50),
    ),
    _ => const _GamePalette(
      Color(0xFF3D4B40),
      Color(0xFF66705C),
      Color(0xFFDCCBAA),
      Color(0xFFA7783E),
    ),
  };
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  final GameController _controller = GameController();
  final PixelAudioService _audio = PixelAudioService.instance;
  Timer? _timer;
  String? _audioThemeId;
  bool _levelCompleteSfxPlayed = false;
  bool _usingSpareHeart = false;
  ({int row, int col})? _hintCell;
  Timer? _hintFlashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdsService.ensureInitialized();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        context.read<GameState>().tickTimer();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.read<AppState>();
    final gameState = context.read<GameState>();
    _controller.setGameState(gameState);
    _controller.setAppState(appState);
    _syncAudio(appState, gameState);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _hintFlashTimer?.cancel();
    _audio.stopMusic();
    _controller.saveLocalGameToSupabase();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.handleAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _audio.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      if (!_controller.isPaused) _audio.resumeMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final gameState = context.watch<GameState>();
    final board = gameState.currentBoard;
    final theme = gameState.isDaily
        ? appState.dailyThemeData
        : ThemeCatalog.forLevel(gameState.currentLevel);
    final gamePalette = _paletteForTheme(theme.id);

    if (board == null) {
      return Scaffold(
        body: Center(
          child: Image.asset(
            'lib/assets/sleeping-kitty.gif',
            width: 120,
            height: 120,
          ),
        ),
      );
    }

    if (gameState.gameCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!_levelCompleteSfxPlayed) {
          _levelCompleteSfxPlayed = true;
          _audio.playLevelComplete();
        }
        final achievements = await _controller.completeLevel();
        if (!mounted) return;
        _showAchievementPopup(achievements);
      });
    }

    if (gameState.gameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.recordDailyFailure();
      });
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(theme.backgroundAsset, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.16)),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  mistakes: gameState.mistakes,
                  maxMistakes: gameState.maxMistakes,
                  coins: appState.coins,
                  hints: appState.hints,
                  onShop: () => _openShop(context),
                ),
                const SizedBox(height: 4),
                _LevelStatsRow(
                  level: gameState.currentLevel,
                  difficulty: gameState.difficulty,
                  elapsedSeconds: gameState.elapsedSeconds,
                  isDaily: gameState.isDaily,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: _BoardFrame(
                      child: _Board(
                        board: board,
                        puzzle: gameState.puzzle!,
                        notes: gameState.notes,
                        wrongCells: gameState.wrongCells,
                        themeIcons: theme.iconAssets,
                        selectedRow: _controller.selectedRow,
                        selectedCol: _controller.selectedCol,
                        selectedAnimal: _controller.selectedAnimal,
                        boardHighlightsOn: appState.boardHighlightsOn,
                        hintCell: _hintCell,
                        isSelected: _controller.isSelectedCell,
                        onCellTap: (row, col) {
                          setState(() {
                            _controller.selectCell(row, col);
                          });
                        },
                      ),
                    ),
                  ),
                ),
                _ActionBar(
                  palette: gamePalette,
                  pencilMode: gameState.pencilMode,
                  onPencil: () =>
                      gameState.setPencilMode(!gameState.pencilMode),
                  onHint: () async {
                    if (appState.hints <= 0 ||
                        gameState.gameOver ||
                        gameState.gameCompleted ||
                        gameState.isPaused) {
                      return;
                    }

                    unawaited(_audio.playHint());
                    final hint = await _controller.useHint();
                    if (!mounted || hint == null) return;

                    _hintFlashTimer?.cancel();
                    setState(() {
                      _hintCell = hint;
                    });
                    _hintFlashTimer = Timer(
                      const Duration(milliseconds: 900),
                      () {
                        if (!mounted) return;
                        setState(() {
                          _hintCell = null;
                        });
                      },
                    );
                  },
                  onErase: _controller.clearCell,
                  onPause: () {
                    gameState.togglePause();
                    _audio.pauseMusic();
                  },
                ),
                _AnimalInputBar(
                  icons: theme.iconAssets,
                  completed: List.generate(
                    9,
                    (index) => gameState.placedCountForAnimal(index + 1) >= 9,
                  ),
                  selectedAnimal: _controller.selectedAnimal,
                  onAnimal: (value) {
                    setState(() {
                      final mistakesBefore = gameState.mistakes;
                      _controller.selectAnimal(value);
                      _controller.placeSelectedAnimal();
                      if (gameState.placedCountForAnimal(value) >= 9) {
                        _controller.deselectAnimal();
                      }
                      if (gameState.mistakes > mistakesBefore) {
                        _audio.playWrongAnswer();
                      }
                    });
                  },
                  onDeselect: () {
                    setState(_controller.clearSelection);
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          if (gameState.isPaused)
            _PauseOverlay(
              backgroundAsset: theme.backgroundAsset,
              isDaily: gameState.isDaily,
              level: gameState.currentLevel,
              difficulty: gameState.difficulty,
              mistakes: gameState.mistakes,
              maxMistakes: gameState.maxMistakes,
              elapsedSeconds: gameState.elapsedSeconds,
              completedAnimals: List.generate(
                9,
                (index) => gameState.placedCountForAnimal(index + 1) >= 9,
              ).where((complete) => complete).length,
              onResume: () {
                gameState.resume();
                _audio.resumeMusic();
              },
              onHome: () => _returnHome(gameState),
            ),
          if (gameState.gameOver)
            _GameOverOverlay(
              isDaily: gameState.isDaily,
              onRetry: () async {
                await AdsService.showInterstitial();
                if (!context.mounted) return;
                if (!_usingSpareHeart) gameState.retryGame();
              },
              spareHearts: appState.spareHearts,
              onUseHeart: !gameState.isDaily && appState.spareHearts > 0
                  ? () async {
                      if (!gameState.gameOver || _usingSpareHeart) return;
                      _usingSpareHeart = true;
                      try {
                        if (await appState.useSpareHeart()) {
                          gameState.addSpareHeart();
                          if (mounted) _audio.resumeMusic();
                        }
                      } finally {
                        _usingSpareHeart = false;
                      }
                    }
                  : null,
              onHome: () async {
                await AdsService.showInterstitial();
                if (mounted) _returnHome(gameState);
              },
            ),
          if (gameState.gameCompleted)
            _VictoryOverlay(
              reward: gameState.completionReward,
              isDaily: gameState.isDaily,
              mistakes: gameState.scoreMistakes,
              elapsedSeconds: gameState.elapsedSeconds,
              hintsUsed: gameState.hintsUsedThisLevel,
              score: RewardRules.score(
                seconds: gameState.elapsedSeconds,
                hints: gameState.hintsUsedThisLevel,
                heartsLost: gameState.scoreMistakes,
              ),
              onNext: () async {
                await AdsService.showInterstitial();
                if (!context.mounted) return;
                if (gameState.isDaily) {
                  Navigator.pop(context);
                  return;
                }
                final achievements = await _controller.loadNextLevel();
                if (!mounted) return;
                setState(() {
                  _levelCompleteSfxPlayed = false;
                });
                _showAchievementPopup(achievements);
              },
              onHome: () async {
                await AdsService.showInterstitial();
                if (!mounted) return;
                final achievements = await _controller.advanceCompletedLevel();
                if (!context.mounted) return;
                _showAchievementPopup(achievements);
                _returnHome(gameState);
              },
            ),
        ],
      ),
    );
  }

  void _showAchievementPopup(List<String> achievements) {
    if (achievements.isEmpty) return;

    final title = achievements.first;
    final navigator = Navigator.of(context, rootNavigator: true);
    showUnlockNotification(
      context,
      label: achievements.length == 1
          ? title
          : '$title +${achievements.length - 1} more',
      onOpen: () => navigator.push(
        MaterialPageRoute(builder: (_) => CollectionsPage(revealTitle: title)),
      ),
    );
  }

  void _returnHome(GameState gameState) {
    if (gameState.isDaily) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _openShop(BuildContext context) async {
    final gameState = context.read<GameState>();
    final shouldResume =
        gameState.hasActiveGame &&
        !gameState.isPaused &&
        !gameState.gameOver &&
        !gameState.gameCompleted;

    if (shouldResume) {
      gameState.togglePause();
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CoinShopPage()),
    );

    if (!mounted || !shouldResume) return;
    gameState.resume();
  }

  Future<void> _syncAudio(AppState appState, GameState gameState) async {
    final theme = gameState.isDaily
        ? appState.dailyThemeData
        : ThemeCatalog.forLevel(gameState.currentLevel);
    await _audio.init(
      musicOn: appState.musicOn,
      sfxOn: appState.sfxOn,
      theme: _audioThemeId == theme.id ? null : theme,
    );
    _audioThemeId = theme.id;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.mistakes,
    required this.maxMistakes,
    required this.coins,
    required this.hints,
    required this.onShop,
  });

  final int mistakes;
  final int maxMistakes;
  final int coins;
  final int hints;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Row(
            children: List.generate(maxMistakes.clamp(0, 3), (index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Opacity(
                  opacity: index < maxMistakes - mistakes ? 1 : 0.25,
                  child: Image.asset(
                    'lib/assets/icons/heart.png',
                    width: 24,
                    height: 24,
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          Row(
            children: [
              _TopBarCounter(
                icon: 'lib/assets/icons/hint.png',
                value: hints,
                onTap: onShop,
              ),
              const SizedBox(width: 10),
              _TopBarCounter(
                icon: 'lib/assets/icons/coin.png',
                value: coins,
                onTap: onShop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBarCounter extends StatelessWidget {
  const _TopBarCounter({
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String icon;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ForestPressBounce(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Image.asset(
                icon,
                width: 22,
                height: 22,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(width: 4),
              Text('$value', style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelStatsRow extends StatelessWidget {
  const _LevelStatsRow({
    required this.level,
    required this.difficulty,
    required this.elapsedSeconds,
    required this.isDaily,
  });

  final int level;
  final String difficulty;
  final int elapsedSeconds;
  final bool isDaily;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _gameInk.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _woodLight, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isDaily ? 'Daily' : 'Level $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Silkscreen',
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  difficulty.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _formatTime(elapsedSeconds),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}

class _BoardFrame extends StatelessWidget {
  const _BoardFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const frameAspectRatio = 540 / 624;
        final heightLimitedWidth = constraints.maxHeight * frameAspectRatio;
        final width = constraints.maxWidth < heightLimitedWidth
            ? constraints.maxWidth
            : heightLimitedWidth;
        final height = width / frameAspectRatio;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  _boardPanelAsset,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(
                left: width * 0.075,
                right: width * 0.075,
                top: height * 0.175 - 10,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRect(child: child),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.board,
    required this.puzzle,
    required this.notes,
    required this.wrongCells,
    required this.themeIcons,
    required this.selectedRow,
    required this.selectedCol,
    required this.selectedAnimal,
    required this.boardHighlightsOn,
    required this.hintCell,
    required this.isSelected,
    required this.onCellTap,
  });

  final List<List<int>> board;
  final List<List<int>> puzzle;
  final List<List<Set<int>>> notes;
  final List<List<bool>> wrongCells;
  final List<String> themeIcons;
  final int selectedRow;
  final int selectedCol;
  final int selectedAnimal;
  final bool boardHighlightsOn;
  final ({int row, int col})? hintCell;
  final bool Function(int row, int col) isSelected;
  final void Function(int row, int col) onCellTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 81,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
      ),
      itemBuilder: (context, index) {
        final row = index ~/ 9;
        final col = index % 9;
        final value = board[row][col];
        final original = puzzle[row][col] != 0;
        final selected = isSelected(row, col);
        final highlightValue = selectedAnimal != -1
            ? selectedAnimal
            : selectedRow != -1 && selectedCol != -1
            ? board[selectedRow][selectedCol]
            : 0;
        final inSelectedRow = row == selectedRow;
        final inSelectedCol = col == selectedCol;
        final inSelectedBox =
            selectedRow != -1 &&
            selectedCol != -1 &&
            row ~/ 3 == selectedRow ~/ 3 &&
            col ~/ 3 == selectedCol ~/ 3;
        final sameAnimal =
            boardHighlightsOn && highlightValue != 0 && value == highlightValue;
        final helper =
            boardHighlightsOn &&
            (inSelectedRow || inSelectedCol || inSelectedBox);
        final hinted = hintCell?.row == row && hintCell?.col == col;

        return GestureDetector(
          onTap: () {
            forestTapHaptic();
            onCellTap(row, col);
          },
          child: Container(
            decoration: BoxDecoration(
              color: _cellColor(
                wrong: wrongCells[row][col],
                selected: selected,
                hinted: hinted,
                sameAnimal: sameAnimal,
                helper: helper,
                original: original,
              ),
              border: Border(
                top: BorderSide(width: row % 3 == 0 ? 2 : 0.5),
                left: BorderSide(width: col % 3 == 0 ? 2 : 0.5),
                right: BorderSide(width: col == 8 ? 2 : 0.5),
                bottom: BorderSide(width: row == 8 ? 2 : 0.5),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.zero,
              child: value == 0
                  ? _Notes(notes: notes[row][col], icons: themeIcons)
                  : Image.asset(
                      themeIcons[value - 1],
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
            ),
          ),
        );
      },
    );
  }

  Color _cellColor({
    required bool wrong,
    required bool selected,
    required bool hinted,
    required bool sameAnimal,
    required bool helper,
    required bool original,
  }) {
    if (wrong) return _wrongCell;
    if (hinted) return _hintedCell;
    if (selected) return _selectedCell;
    if (sameAnimal) return _sameAnimalCell;
    if (helper) return _helperCell;
    return original ? _givenCell : _playerCell;
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.notes, required this.icons});

  final Set<int> notes;
  final List<String> icons;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: List.generate(9, (index) {
        final value = index + 1;
        if (!notes.contains(value)) return const SizedBox.shrink();

        return Image.asset(icons[index], fit: BoxFit.contain);
      }),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.palette,
    required this.pencilMode,
    required this.onPencil,
    required this.onHint,
    required this.onErase,
    required this.onPause,
  });

  final _GamePalette palette;
  final bool pencilMode;
  final VoidCallback onPencil;
  final VoidCallback onHint;
  final VoidCallback onErase;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      child: Row(
        children: [
          _ToolButton(
            accent: palette.dark,
            asset: pencilMode
                ? 'lib/assets/icons/pencil.png'
                : 'lib/assets/icons/pencil.png',
            label: 'Pencil',
            selected: pencilMode,
            onPressed: onPencil,
          ),
          _ToolButton(
            accent: palette.mid,
            asset: 'lib/assets/icons/hint.png',
            label: 'Hint',
            onPressed: onHint,
          ),
          _ToolButton(
            accent: palette.light,
            asset: 'lib/assets/icons/erase.png',
            label: 'Erase',
            onPressed: onErase,
          ),
          _ToolButton(
            accent: palette.accent,
            asset: 'lib/assets/icons/pause.png',
            label: 'Pause',
            onPressed: onPause,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.accent,
    required this.asset,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final Color accent;
  final String asset;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ForestPressBounce(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                tooltip: label,
                onPressed: onPressed,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(52),
                  backgroundColor: selected
                      ? accent.withValues(alpha: 0.72)
                      : _gameInk.withValues(alpha: 0.68),
                  foregroundColor: Colors.white,
                  shape: CircleBorder(
                    side: const BorderSide(
                      color: _buttonBorderBrown,
                      width: 1.5,
                    ),
                  ),
                  shadowColor: Colors.black,
                  elevation: 4,
                ),
                icon: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Image.asset(
                    asset,
                    width: 34,
                    height: 34,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimalInputBar extends StatelessWidget {
  const _AnimalInputBar({
    required this.icons,
    required this.completed,
    required this.selectedAnimal,
    required this.onAnimal,
    required this.onDeselect,
  });

  final List<String> icons;
  final List<bool> completed;
  final int selectedAnimal;
  final ValueChanged<int> onAnimal;
  final VoidCallback onDeselect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 3, 18, 3),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 5,
        mainAxisSpacing: 4,
        crossAxisSpacing: 7,
        childAspectRatio: 1,
        children: [
          for (int index = 0; index < icons.length; index++)
            _AnimalButton(
              icon: icons[index],
              selected: selectedAnimal == index + 1,
              completed: completed[index],
              onTap: completed[index] ? null : () => onAnimal(index + 1),
            ),
          _AnimalButton(
            icon: 'lib/assets/icons/clear.png',
            iconPadding: 16,
            onTap: onDeselect,
          ),
        ],
      ),
    );
  }
}

class _AnimalButton extends StatelessWidget {
  const _AnimalButton({
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.completed = false,
    this.iconPadding = 3,
  });

  final String icon;
  final VoidCallback? onTap;
  final bool selected;
  final bool completed;
  final double iconPadding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      child: ForestPressBounce(
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: AnimatedScale(
            scale: selected ? 1.1 : 1,
            duration: const Duration(milliseconds: 120),
            child: Opacity(
              opacity: completed ? 0.35 : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _animalButtonAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                  Padding(
                    padding: EdgeInsets.all(iconPadding),
                    child: Image.asset(
                      icon,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
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

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.backgroundAsset,
    required this.isDaily,
    required this.level,
    required this.difficulty,
    required this.mistakes,
    required this.maxMistakes,
    required this.elapsedSeconds,
    required this.completedAnimals,
    required this.onResume,
    required this.onHome,
  });

  final String backgroundAsset;
  final bool isDaily;
  final int level;
  final String difficulty;
  final int mistakes;
  final int maxMistakes;
  final int elapsedSeconds;
  final int completedAnimals;
  final VoidCallback onResume;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(backgroundAsset, fit: BoxFit.cover),
        ColoredBox(color: Colors.black.withValues(alpha: 0.48)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Image.asset(
                          'lib/assets/sleeping-kitty.gif',
                          height: 240,
                          semanticLabel: 'Sleeping cat',
                        ),
                        const Text(
                          'PAUSED',
                          style: TextStyle(
                            color: Color(0xFFFFC72C),
                            fontSize: 34,
                            fontFamily: 'Silkscreen',
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(-2, -2),
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                              Shadow(
                                offset: Offset(2, -2),
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                              Shadow(
                                offset: Offset(-2, 2),
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                              Shadow(
                                offset: Offset(2, 2),
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isDaily
                              ? 'DAILY  ·  ${difficulty.toUpperCase()}'
                              : 'LEVEL $level  ·  ${difficulty.toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _PauseStat(
                                icon: Icons.timer,
                                value: _formatTime(elapsedSeconds),
                                label: 'TIME',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PauseStat(
                                icon: Icons.favorite,
                                value: '${maxMistakes - mistakes}/$maxMistakes',
                                label: 'HEARTS',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PauseStat(
                                icon: Icons.pets,
                                value: '$completedAnimals/9',
                                label: 'SETS',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _ResultImageButton(
                          asset: 'lib/assets/icons/button.png',
                          label: 'RESUME PUZZLE',
                          width: 300,
                          labelOffsetY: -3,
                          onPressed: onResume,
                        ),
                        const SizedBox(height: 8),
                        _ResultImageButton(
                          asset: 'lib/assets/icons/button-2.png',
                          label: 'Save and Return Home',
                          width: 250,
                          onPressed: onHome,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}

class _PauseStat extends StatelessWidget {
  const _PauseStat({
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: forestPanelBlue.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color.fromARGB(255, 0, 0, 0), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: forestGold, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: forestPanelText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.onRetry,
    required this.onHome,
    this.spareHearts = 0,
    this.onUseHeart,
    this.isDaily = false,
  });
  final bool isDaily;
  final int spareHearts;
  final VoidCallback? onUseHeart;

  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return _OverlayShell(
      panelAsset: _failurePanelAsset,
      goldStars: 0,
      starsTopFactor: 0.14,
      contentTopFactor: 0.30,
      contentOffsetY: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PUZZLE FAILED',
            style: TextStyle(
              color: forestPanelText,
              fontSize: 25,
              fontFamily: 'Silkscreen',
              fontWeight: FontWeight.normal,
              shadows: [forestPixelShadow],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            onUseHeart != null
                ? 'You have $spareHearts spare ${spareHearts == 1 ? 'heart' : 'hearts'}.\nUse one now to continue with one heart?'
                : isDaily
                ? 'Your daily attempt is over. Come back tomorrow!'
                : 'Give the puzzle another try!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Fira Sans',
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          if (onUseHeart != null) ...[
            _ResultImageButton(
              asset: 'lib/assets/icons/button.png',
              label: 'Yes, Use One Heart',
              width: 290,
              onPressed: onUseHeart!,
            ),
            const SizedBox(height: 8),
          ],
          if (!isDaily)
            _ResultImageButton(
              asset: onUseHeart != null
                  ? 'lib/assets/icons/button-2.png'
                  : 'lib/assets/icons/button.png',
              label: onUseHeart != null ? 'No, Retry Level' : 'Retry Level',
              width: 250,
              onPressed: onRetry,
            ),
          const SizedBox(height: 8),
          _ResultImageButton(
            asset: 'lib/assets/icons/button-2.png',
            label: 'RETURN HOME',
            width: 212,
            onPressed: onHome,
          ),
        ],
      ),
    );
  }
}

class _VictoryOverlay extends StatelessWidget {
  const _VictoryOverlay({
    required this.reward,
    required this.score,
    required this.isDaily,
    required this.mistakes,
    required this.elapsedSeconds,
    required this.hintsUsed,
    required this.onNext,
    required this.onHome,
  });

  final int reward;
  final int score;
  final bool isDaily;
  final int mistakes;
  final int elapsedSeconds;
  final int hintsUsed;
  final VoidCallback onNext;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return _OverlayShell(
      panelAsset: _successPanelAsset,
      panelAspectRatio: 318 / 529,
      contentBottomFactor: 0.23,
      contentOffsetY: 5,
      goldStars: mistakes == 0 ? 3 : (mistakes == 1 ? 2 : 1),
      starsTopFactor: 0.27,
      contentTopFactor: 0.40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PUZZLE COMPLETE',
            style: TextStyle(
              color: forestPanelText,
              fontSize: 25,
              fontFamily: 'Silkscreen',
              fontWeight: FontWeight.normal,
              shadows: [forestPixelShadow],
            ),
          ),
          const SizedBox(height: 8),
          _CompletionStats(
            elapsedSeconds: elapsedSeconds,
            hintsUsed: hintsUsed,
            heartsLost: mistakes,
            score: score,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF321A10).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF7A3C18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'lib/assets/icons/coins.png',
                  width: 30,
                  height: 24,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    reward > 0
                        ? '$reward coin reward'
                        : 'Practice completed · rewards already collected',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Fira Sans',
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ResultImageButton(
            asset: 'lib/assets/icons/button.png',
            label: isDaily ? 'Back to Daily' : 'Next Level',
            width: 250,
            onPressed: onNext,
          ),
          const SizedBox(height: 8),
          _ResultImageButton(
            asset: 'lib/assets/icons/button-2.png',
            label: 'RETURN HOME',
            width: 212,
            onPressed: onHome,
          ),
        ],
      ),
    );
  }
}

class _CompletionStats extends StatelessWidget {
  const _CompletionStats({
    required this.elapsedSeconds,
    required this.hintsUsed,
    required this.heartsLost,
    required this.score,
  });

  final int elapsedSeconds;
  final int hintsUsed;
  final int heartsLost;
  final int score;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF17212B).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF7A3C18)),
      ),
      child: Row(
        children: [
          _CompletionStat(label: 'TIME', value: '$minutes:$seconds'),
          const _CompletionStatDivider(),
          _CompletionStat(label: 'HINTS', value: '$hintsUsed'),
          const _CompletionStatDivider(),
          _CompletionStat(label: 'HEARTS LOST', value: '$heartsLost'),
          const _CompletionStatDivider(),
          _CompletionStat(label: 'SCORE', value: '$score'),
        ],
      ),
    );
  }
}

class _CompletionStat extends StatelessWidget {
  const _CompletionStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: forestGold,
                fontFamily: 'Fira Sans',
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionStatDivider extends StatelessWidget {
  const _CompletionStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: const Color(0xFF7A3C18).withValues(alpha: 0.8),
    );
  }
}

class _ResultStars extends StatelessWidget {
  const _ResultStars({required this.goldStars});

  final int goldStars;

  @override
  Widget build(BuildContext context) {
    final earned = goldStars.clamp(0, 3);

    Widget star(int index, double size) {
      return Image.asset(
        index < earned
            ? 'lib/assets/icons/star.png'
            : 'lib/assets/icons/gray-star.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        excludeFromSemantics: true,
      );
    }

    return Semantics(
      label: '$earned of 3 stars earned',
      child: SizedBox(
        width: 190,
        height: 66,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(left: 18, top: 17, child: star(0, 44)),
            Positioned(top: 0, child: star(1, 52)),
            Positioned(right: 18, top: 17, child: star(2, 44)),
          ],
        ),
      ),
    );
  }
}

class _ResultImageButton extends StatelessWidget {
  const _ResultImageButton({
    required this.asset,
    required this.label,
    required this.width,
    required this.onPressed,
    this.labelOffsetY = 0,
  });

  final String asset;
  final String label;
  final double width;
  final VoidCallback onPressed;
  final double labelOffsetY;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ForestPressBounce(
        child: InkWell(
          onTap: onPressed,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: width,
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
                  ),
                  Transform.translate(
                    offset: Offset(0, labelOffsetY),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
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
    );
  }
}

class _OverlayShell extends StatelessWidget {
  const _OverlayShell({
    required this.panelAsset,
    this.panelAspectRatio = 318 / 447,
    this.contentBottomFactor = 0.065,
    this.contentOffsetY = 50,
    required this.goldStars,
    required this.starsTopFactor,
    required this.contentTopFactor,
    required this.child,
  });

  final String panelAsset;
  final double panelAspectRatio;
  final double contentBottomFactor;
  final double contentOffsetY;
  final int goldStars;
  final double starsTopFactor;
  final double contentTopFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AspectRatio(
              aspectRatio: panelAspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          panelAsset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Positioned(
                        top: height * starsTopFactor + contentOffsetY,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _ResultStars(goldStars: goldStars),
                        ),
                      ),
                      Positioned(
                        left: width * 0.14,
                        right: width * 0.14,
                        top: height * contentTopFactor + contentOffsetY,
                        bottom: height * contentBottomFactor - contentOffsetY,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(width: 300, child: child),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uses the same artwork and buttons as the puzzle completion board.
Future<bool?> showCompetitionPrizeBoard(
  BuildContext context,
  Map<String, dynamic> award,
) {
  final period = award['period'].toString().toUpperCase();
  final place = (award['rank'] as num?)?.toInt() ?? 1;
  final medal = switch (place) {
    1 => 'GOLD',
    2 => 'SILVER',
    _ => 'BRONZE',
  };
  final extras = <String>[
    '${award['coins']} coins',
    '${award['hints']} free hints',
    if ((award['hearts'] as num) > 0) '${award['hearts']} spare hearts',
    if (award['title'] != null) '${award['title']} title',
  ];
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: _OverlayShell(
        panelAsset: _successPanelAsset,
        panelAspectRatio: 318 / 529,
        goldStars: 4 - place.clamp(1, 3),
        starsTopFactor: 0.27,
        contentTopFactor: 0.40,
        contentBottomFactor: 0.23,
        contentOffsetY: 5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$period $medal!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: forestGold,
                fontSize: 23,
                fontFamily: 'Silkscreen',
                shadows: [forestPixelShadow],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You finished #$place!\nPeriod starting ${award['period_start']}\n${award['score']} points',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Fira Sans',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rewards added\n${extras.join(' · ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: forestGold,
                fontFamily: 'Fira Sans',
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 18),
            _ResultImageButton(
              asset: 'lib/assets/icons/button.png',
              label: 'Wonderful!',
              width: 250,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      ),
    ),
  );
}
