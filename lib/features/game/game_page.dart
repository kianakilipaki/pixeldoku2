import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pixeldoku/features/game/game_controller.dart';
import 'package:pixeldoku/features/shop/coin_shop_page.dart';
import 'package:pixeldoku/services/audio_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

const _pixelGold = Color(0xFFEEC027);
const _boardPanelAsset = 'lib/assets/wood-panel-lg-lvs.png';
const _animalPanelAsset = 'lib/assets/wood-panel-md.png';
const _gameInk = Color(0xFF171C1A);
const _woodLight = Color(0xFF783602);
const _buttonBorderBrown = Color(0xFF8B5A2B);
const _givenCell = Color(0xFFD6D5CF);
const _playerCell = Color(0xFFECE3D2);
const _selectedCell = Color(0xFFD6AD55);
const _sameAnimalCell = Color(0xFFA9C0C8);
const _helperCell = Color(0xFFC4CECD);
const _wrongCell = Color(0xFFA96057);
const _hintedCell = Color(0xFFA7B684);

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
  ({int row, int col})? _hintCell;
  Timer? _hintFlashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _controller.setGameState(context.read<GameState>());
    _controller.setAppState(appState);
    _syncAudio(appState);
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
    final theme = appState.activeThemeData;
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
                const SizedBox(height: 12),
                _LevelStatsRow(
                  level: gameState.currentLevel,
                  difficulty: gameState.difficulty,
                  elapsedSeconds: gameState.elapsedSeconds,
                  isDaily: gameState.isDaily,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
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
                const SizedBox(height: 16),
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
              onRetry: gameState.retryGame,
              onHome: () => _returnHome(gameState),
            ),
          if (gameState.gameCompleted)
            _VictoryOverlay(
              reward: gameState.completionReward,
              isDaily: gameState.isDaily,
              onNext: () async {
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

    final title = achievements.length == 1
        ? achievements.first
        : '${achievements.first} +${achievements.length - 1} more';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: _pixelGold),
            const SizedBox(width: 10),
            Expanded(child: Text('Achievement unlocked: $title')),
          ],
        ),
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

  Future<void> _syncAudio(AppState appState) async {
    final theme = appState.activeThemeData;
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Row(
            children: List.generate(maxMistakes, (index) {
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Image.asset(icon, width: 22, height: 22),
            const SizedBox(width: 4),
            Text('$value', style: const TextStyle(color: Colors.white)),
          ],
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
          color: _gameInk.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _woodLight, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, offset: Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        final size = constraints.biggest.shortestSide;
        return Transform.scale(
          scale: 1.16,
          child: SizedBox.square(
            dimension: size,
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
                  left: size * 0.14,
                  right: size * 0.14,
                  top: size * 0.16,
                  bottom: size * 0.12,
                  child: ClipRect(child: child),
                ),
              ],
            ),
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
          onTap: () => onCellTap(row, col),
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
              padding: const EdgeInsets.all(3),
              child: value == 0
                  ? _Notes(notes: notes[row][col], icons: themeIcons)
                  : Image.asset(themeIcons[value - 1], fit: BoxFit.contain),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filled(
              onPressed: onPressed,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(52),
                backgroundColor: selected
                    ? accent.withValues(alpha: 0.68)
                    : _gameInk.withValues(alpha: 0.94),
                foregroundColor: Colors.white,
                shape: CircleBorder(
                  side: const BorderSide(color: _buttonBorderBrown, width: 1.5),
                ),
                shadowColor: Colors.black,
                elevation: 4,
              ),
              icon: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(asset, width: 26, height: 26),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: forestPanelText,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                shadows: [forestPixelShadow],
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage(_animalPanelAsset),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 5,
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          childAspectRatio: 1.15,
          children: [
            for (int index = 0; index < icons.length; index++)
              InkWell(
                onTap: completed[index] ? null : () => onAnimal(index + 1),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: AnimatedScale(
                    scale: selectedAnimal == index + 1 ? 1.12 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: Opacity(
                      opacity: completed[index] ? 0.35 : 1,
                      child: Image.asset(icons[index]),
                    ),
                  ),
                ),
              ),
            IconButton(
              onPressed: onDeselect,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              icon: Image.asset(
                'lib/assets/icons/clear.png',
                width: 28,
                height: 28,
              ),
            ),
          ],
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
                  child: AspectRatio(
                    aspectRatio: 540 / 624,
                    child: _PauseBoardPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'PAUSED',
                            style: TextStyle(
                              color: forestPanelText,
                              fontSize: 28,
                              fontFamily: 'Silkscreen',
                              fontWeight: FontWeight.bold,
                              shadows: [forestPixelShadow],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Image.asset(
                            'lib/assets/sleeping-kitty.gif',
                            height: 116,
                            semanticLabel: 'Sleeping cat',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isDaily
                                ? 'DAILY  ·  ${difficulty.toUpperCase()}'
                                : 'LEVEL $level  ·  ${difficulty.toUpperCase()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
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
                                  value:
                                      '${maxMistakes - mistakes}/$maxMistakes',
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
                          ForestButton(
                            label: 'Resume Puzzle',
                            onPressed: onResume,
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: onHome,
                            icon: const Icon(Icons.home, color: Colors.white70),
                            label: const Text(
                              'SAVE & RETURN HOME',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
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

class _PauseBoardPanel extends StatelessWidget {
  const _PauseBoardPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                _boardPanelAsset,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            Positioned(
              left: width * 0.085,
              right: width * 0.085,
              top: height * 0.14,
              bottom: height * 0.10,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(width: 400, child: child),
                ),
              ),
            ),
          ],
        );
      },
    );
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
        color: forestPanelBlue.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF783602), width: 2),
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
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: forestPanelText, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.onRetry, required this.onHome});

  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return _OverlayShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'GAME OVER',
            style: TextStyle(
              color: forestPanelText,
              fontSize: 28,
              fontFamily: 'Silkscreen',
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          ForestButton(label: 'Retry Level', onPressed: onRetry),
          TextButton(
            onPressed: onHome,
            child: const Text(
              'RETURN HOME',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _VictoryOverlay extends StatelessWidget {
  const _VictoryOverlay({
    required this.reward,
    required this.isDaily,
    required this.onNext,
    required this.onHome,
  });

  final int reward;
  final bool isDaily;
  final VoidCallback onNext;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return _OverlayShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PUZZLE COMPLETE',
            style: TextStyle(
              color: forestPanelText,
              fontSize: 28,
              fontFamily: 'Silkscreen',
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reward > 0
                ? isDaily
                      ? 'Daily reward: $reward coins + ${AppState.dailyBonusPoints} bonus points'
                      : 'Reward: $reward coins'
                : 'Best time submitted · rewards already collected',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Fira Sans',
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          ForestButton(
            label: isDaily ? 'Back to Daily' : 'Next Level',
            onPressed: onNext,
          ),
          TextButton(
            onPressed: onHome,
            child: const Text(
              'RETURN HOME',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayShell extends StatelessWidget {
  const _OverlayShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ForestWoodBorder(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF241307).withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
