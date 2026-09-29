import 'package:flutter/material.dart';
import 'package:pixeldoku/features/daily/daily_page.dart';
import 'package:pixeldoku/features/game/game_page.dart';
import 'package:pixeldoku/features/home/home_controller.dart';
import 'package:pixeldoku/features/profile/profile_page.dart';
import 'package:pixeldoku/features/profile/stats_page.dart';
import 'package:pixeldoku/features/settings/settings_page.dart';
import 'package:pixeldoku/features/shop/coin_shop_page.dart';
import 'package:pixeldoku/features/themes/themes_page.dart';
import 'package:pixeldoku/services/app_update_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

const _pixelGold = Color.fromARGB(255, 255, 208, 90);
const _homeProfilePanel = 'lib/assets/wood/wood-panel-sm.png';
const _homeProfilePanelHeight = 84.0;
const _homeMenuHeight = 132.0;

/// Main landing screen with player status, level entry, and home menu.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Coordinates home-screen state, save syncing, and navigation actions.
class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final HomeController _controller = HomeController();
  final AppUpdateService _updateService = AppUpdateService();
  bool _awardsChecked = false;
  String? _awardsUserId;
  bool _showingAwards = false;
  bool _updateChecked = false;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _awardsChecked = false);
    }
  }

  Future<void> _showAwards(AppState app) async {
    if (_showingAwards) return;
    _showingAwards = true;
    try {
      await app.checkCompetitionAwards();
      for (final award in List<Map<String, dynamic>>.from(
        app.pendingCompetitionAwards,
      )) {
        if (!mounted) return;
        final acknowledged = await showCompetitionPrizeBoard(context, award);
        if (acknowledged == true) {
          await app.acknowledgeCompetitionAward(award['id'].toString());
        }
      }
    } catch (_) {
      // An unacknowledged award remains on the server for the next visit.
    } finally {
      _showingAwards = false;
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate || _updateChecked) return;
    _checkingUpdate = true;
    _updateChecked = true;
    try {
      while (_showingAwards && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (!mounted) return;
      final update = await _updateService.checkForUpdate();
      if (!mounted || update == null) return;
      await _showUpdateDialog(update);
    } finally {
      _checkingUpdate = false;
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo update) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !update.isRequired,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xEE17283A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: forestSectionBorder, width: 3),
        ),
        title: const Text(
          'UPDATE AVAILABLE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: forestPanelText,
            fontFamily: 'Silkscreen',
            fontSize: 20,
            shadows: [forestPixelShadow],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update_alt, color: forestGold, size: 48),
            const SizedBox(height: 12),
            Text(
              update.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${update.currentVersion}  →  ${update.latestVersion}',
              style: const TextStyle(color: forestPanelText, fontSize: 13),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!update.isRequired)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('LATER'),
            ),
          SizedBox(
            width: 150,
            child: ForestButton(
              label: 'PLAY STORE',
              onPressed: () async {
                final opened = await _updateService.openStore(update);
                if (!dialogContext.mounted) return;
                if (!opened) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the Play Store.'),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final gameState = context.watch<GameState>();
    if (_awardsUserId != appState.user?.id) {
      _awardsUserId = appState.user?.id;
      _awardsChecked = false;
    }
    if (!appState.isLoading && !_awardsChecked) {
      _awardsChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAwards(appState);
      });
    }

    if (!appState.isLoading && !_updateChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkForUpdate();
      });
    }

    if (!appState.isLoading && !_controller.didSyncRemoteSaveToLocal) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _controller.syncRemoteSaveToLocal(appState);

        if (context.mounted) {
          setState(() {});
        }
      });
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset('lib/assets/bg.png', fit: BoxFit.fill),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _TopHud(appState: appState),
                        Flexible(
                          flex: 3,
                          child: Transform.translate(
                            offset: const Offset(0, 10),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _AnimalShowcase(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          flex: 2,
                          child: Transform.translate(
                            offset: const Offset(0, 10),
                            child: Image.asset(
                              'lib/assets/title.png',
                              width: MediaQuery.of(context).size.width * 0.88,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _LevelPill(level: appState.currentLevel),
                        const SizedBox(height: 6),
                        _StartButton(
                          enabled: _controller.canStartGame(appState),
                          label: _controller.gameButtonText(
                            appState,
                            gameState,
                          ),
                          onPressed: () =>
                              _startGame(context, appState, gameState),
                        ),
                      ],
                    ),
                  ),
                ),
                _BottomMenu(
                  onDaily: () => _openDaily(context),
                  onThemes: () => _openCollections(context),
                  onLeaderboard: () => _openLeaderboard(context),
                  onShop: () => _openShop(context),
                  onSettings: () => _openSettings(context),
                ),
              ],
            ),
          ),
          if (appState.isLoading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Image.asset(
                  'lib/assets/sleeping-kitty.gif',
                  width: 120,
                  height: 120,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startGame(
    BuildContext context,
    AppState appState,
    GameState gameState,
  ) async {
    if (!_controller.canStartGame(appState)) return;

    await _controller.startOrContinueGame(appState, gameState);

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GamePage()),
    );
  }

  void _openDaily(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DailyPage()),
    );
  }

  void _openLeaderboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaderboardPage()),
    );
  }

  void _openCollections(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CollectionsPage()),
    );
  }

  void _openShop(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CoinShopPage()));
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }
}

/// Top player HUD shown above the main home content.
class _TopHud extends StatelessWidget {
  const _TopHud({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _homeProfilePanelHeight,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxWidth: MediaQuery.sizeOf(context).width,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: _homeProfilePanelHeight,
          child: _ProfileCard(appState: appState),
        ),
      ),
    );
  }
}

/// Tappable profile summary with avatar, name, title, and edit affordance.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const nameStyle = TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontFamily: 'Silkscreen',
          fontWeight: FontWeight.bold,
          shadows: [_blackShadow],
        );
        final namePainter = TextPainter(
          text: TextSpan(text: appState.name.toUpperCase(), style: nameStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        const titleStyle = TextStyle(
          color: _pixelGold,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0,
          shadows: [_blackShadow],
        );
        final titlePainter = TextPainter(
          text: TextSpan(
            text: appState.playerTitle.toUpperCase(),
            style: titleStyle,
          ),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final widestText = namePainter.width > titlePainter.width + 23
            ? namePainter.width
            : titlePainter.width + 23;
        final desiredWidth = 95 + widestText + 28;
        namePainter.dispose();
        titlePainter.dispose();
        final minimumWidth = constraints.maxWidth < 220
            ? constraints.maxWidth
            : 220.0;
        final cardWidth = desiredWidth
            .clamp(minimumWidth, constraints.maxWidth)
            .toDouble();
        const cardHeight = _homeProfilePanelHeight;
        return Center(
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: ForestPressBounce(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      width: cardWidth,
                      height: _homeProfilePanelHeight,
                      margin: const EdgeInsets.only(left: 0),
                      padding: const EdgeInsets.fromLTRB(80, 9, 28, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        image: const DecorationImage(
                          image: AssetImage(_homeProfilePanel),
                          fit: BoxFit.fill,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  appState.name.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: nameStyle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Image.asset(
                                'lib/assets/icons/star.png',
                                width: 16,
                                height: 16,
                                excludeFromSemantics: true,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  appState.playerTitle.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: -15,
                      top: (cardHeight - 84) / 2,
                      child: Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFFE75A),
                              Color(0xFFFFD12A),
                              Color(0xFFFFA40D),
                              Color(0xFFE87505),
                            ],
                            stops: [0, 0.32, 0.68, 1],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                          child: ProfileGradientBackground(
                            colorValue: appState.profilePictureBgColor,
                            padding: const EdgeInsets.all(5),
                            child: Image.asset(
                              appState.profilePicture,
                              fit: BoxFit.contain,
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
        );
      },
    );
  }
}

/// Four-tile preview of animals from across the available themes.
class _AnimalShowcase extends StatelessWidget {
  const _AnimalShowcase();

  static const _icons = [
    'lib/assets/themes/birds/bird_1.png',
    'lib/assets/themes/dogs/dog_1.png',
    'lib/assets/themes/cats/cat_1.png',
    'lib/assets/themes/fish/fish_1.png',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color.fromARGB(255, 255, 208, 90),
      const Color.fromARGB(255, 73, 122, 20),
      const Color.fromARGB(255, 162, 39, 16),
      const Color.fromARGB(255, 24, 103, 214),
    ];

    return SizedBox(
      width: 150,
      height: 150,
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: List.generate(4, (index) {
          final tileColor = colors[index];
          final shineColor = Color.lerp(Colors.white, tileColor, 0.28)!;
          final deepColor = Color.lerp(Colors.black, tileColor, 0.62)!;
          final tileLightColor = Color.lerp(tileColor, shineColor, 0.38)!;

          return Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, shineColor, tileColor, deepColor],
                stops: const [0, 0.28, 0.62, 1],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  offset: Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [tileLightColor, tileColor],
                ),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    left: 3,
                    top: 3,
                    right: 3,
                    bottom: 3,
                    child: Image.asset(_icons[index], fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Compact badge showing the player's current level.
class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: _transparentPanelDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('lib/assets/icons/star.png', width: 21, height: 21),
          const SizedBox(width: 8),
          const Text(
            'LEVEL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontFamily: 'Silkscreen',
              fontWeight: FontWeight.normal,
              shadows: [_blackShadow],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$level',
            style: const TextStyle(
              color: _pixelGold,
              fontSize: 19,
              fontFamily: 'Silkscreen',
              fontWeight: FontWeight.normal,
              shadows: [_blackShadow],
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary call-to-action for starting or continuing the current puzzle.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final desiredWidth = screenWidth * 0.76;
    final buttonWidth = desiredWidth.clamp(240.0, 310.0).toDouble();

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ForestPressBounce(
        enabled: enabled,
        child: SizedBox(
          width: buttonWidth,
          child: AspectRatio(
            aspectRatio: 186 / 39,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? onPressed : null,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                          child: Text(
                            label.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontFamily: 'Silkscreen',
                              fontWeight: FontWeight.normal,
                              shadows: [_blackShadow],
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
      ),
    );
  }
}

/// Bottom home menu with shortcuts for themes, shop, daily play, rankings, and settings.
class _BottomMenu extends StatelessWidget {
  const _BottomMenu({
    required this.onDaily,
    required this.onThemes,
    required this.onLeaderboard,
    required this.onShop,
    required this.onSettings,
  });

  final VoidCallback onDaily;
  final VoidCallback onThemes;
  final VoidCallback onLeaderboard;
  final VoidCallback onShop;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _homeMenuHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 26, 0, 10),
        child: Row(
          children: [
            const Spacer(flex: 27),
            Expanded(
              flex: 72,
              child: _MenuTile(
                label: 'LEADERBOARD',
                asset: 'lib/assets/icons/medallion-simple.png',
                iconSize: 56,
                iconOffset: const Offset(3, 3),
                onTap: onLeaderboard,
              ),
            ),
            Expanded(
              flex: 67,
              child: _MenuTile(
                label: 'SHOP',
                asset: 'lib/assets/icons/shop-simple.png',
                iconSize: 60,
                iconOffset: const Offset(0, 3),
                onTap: onShop,
              ),
            ),
            Expanded(
              flex: 92,
              child: _MenuTile(
                label: 'DAILY',
                asset: 'lib/assets/icons/daily-simple.png',
                iconSize: 64,
                onTap: onDaily,
              ),
            ),
            Expanded(
              flex: 67,
              child: _MenuTile(
                label: 'THEMES',
                asset: 'lib/assets/icons/book-simple.png',
                iconSize: 60,
                iconOffset: const Offset(0, 3),
                onTap: onThemes,
              ),
            ),
            Expanded(
              flex: 64,
              child: _MenuTile(
                label: 'SETTINGS',
                asset: 'lib/assets/icons/gear-simple.png',
                iconSize: 50,
                iconOffset: const Offset(0, 3),
                onTap: onSettings,
              ),
            ),
            const Spacer(flex: 37),
          ],
        ),
      ),
    );
  }
}

/// Single icon-and-label item used by the bottom home menu.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.label,
    required this.asset,
    required this.iconSize,
    required this.onTap,
    this.iconOffset = Offset.zero,
  });

  final String label;
  final String asset;
  final double iconSize;
  final Offset iconOffset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ForestPressBounce(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 80,
            child: Transform.translate(
              offset: iconOffset,
              child: Center(
                child: SizedBox.square(
                  dimension: iconSize,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _transparentPanelDecoration() {
  return BoxDecoration(
    color: Colors.black.withValues(alpha: 0.24),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
    boxShadow: const [
      BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 0),
    ],
  );
}

const _blackShadow = Shadow(
  offset: Offset(2, 2),
  blurRadius: 0,
  color: Colors.black,
);
