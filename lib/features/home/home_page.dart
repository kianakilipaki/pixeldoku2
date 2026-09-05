import 'package:flutter/material.dart';
import 'package:pixeldoku/features/daily/daily_page.dart';
import 'package:pixeldoku/features/game/game_page.dart';
import 'package:pixeldoku/features/home/home_controller.dart';
import 'package:pixeldoku/features/profile/profile_page.dart';
import 'package:pixeldoku/features/profile/stats_page.dart';
import 'package:pixeldoku/features/settings/settings_page.dart';
import 'package:pixeldoku/features/shop/coin_shop_page.dart';
import 'package:pixeldoku/features/themes/themes_page.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

const _pixelBlue = Color(0xFF1985DF);
const _pixelGold = Color(0xFFEEC027);
const _startGreen = Color(0xFF65C900);
const _homeProfilePanel = 'lib/assets/wood-panel-sm-lvs.png';
const _homeProfilePanelAspectRatio = 583 / 176;
const _homeMenuHeight = 132.0;

/// Main landing screen with player status, level entry, and home menu.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Coordinates home-screen state, save syncing, and navigation actions.
class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final gameState = context.watch<GameState>();

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
                      children: [
                        _TopHud(appState: appState),
                        const Spacer(),
                        const _AnimalShowcase(),
                        const SizedBox(height: 8),
                        Image.asset(
                          'lib/assets/title.png',
                          width: MediaQuery.of(context).size.width * 0.88,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        _LevelPill(level: appState.currentLevel),
                        const SizedBox(height: 14),
                        _StartButton(
                          enabled: _controller.canStartGame(appState),
                          label: _controller.gameButtonText(
                            appState,
                            gameState,
                          ),
                          onPressed: () =>
                              _startGame(context, appState, gameState),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
                _BottomMenu(
                  onDaily: () => _openDaily(context),
                  onThemes: () => _openThemes(context),
                  onStats: () => _openStats(context),
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

  void _openStats(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatsPage()),
    );
  }

  void _openThemes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ThemesPage()),
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
      height: 160,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxWidth: MediaQuery.sizeOf(context).width,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: 160,
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
        final cardWidth = (constraints.maxWidth * 0.82).clamp(280.0, 340.0);
        final panelHeight = (cardWidth) / _homeProfilePanelAspectRatio;
        final cardHeight = panelHeight > 84 ? panelHeight : 84.0;
        return Center(
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
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
                    height: panelHeight,
                    margin: const EdgeInsets.only(left: 0),
                    padding: const EdgeInsets.fromLTRB(95, 9, 38, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      image: const DecorationImage(
                        image: AssetImage(_homeProfilePanel),
                        fit: BoxFit.contain,
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontFamily: 'Silkscreen',
                                  fontWeight: FontWeight.bold,
                                  shadows: [_blackShadow],
                                ),
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
                                style: const TextStyle(
                                  color: _pixelGold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0,
                                  shadows: [_blackShadow],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Color(0xFFFFF4A8),
                          _pixelGold,
                          Color(0xFF8A5B09),
                        ],
                        stops: [0, 0.28, 0.62, 1],
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Four-tile preview of the active theme's animal icons.
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
      _pixelBlue,
      const Color(0xFF9453CE),
      _pixelGold,
      const Color(0xFF5EC43B),
    ];

    return SizedBox(
      width: 170,
      height: 170,
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: _transparentPanelDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('lib/assets/icons/star.png', width: 23, height: 23),
          const SizedBox(width: 10),
          const Text(
            'LEVEL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Silkscreen',
              fontWeight: FontWeight.normal,
              shadows: [_blackShadow],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$level',
            style: const TextStyle(
              color: _pixelGold,
              fontSize: 20,
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
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.76,
      height: 74,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _startGreen,
          disabledBackgroundColor: Colors.grey.shade500,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFC8FF4C), width: 3),
          ),
        ),
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
    );
  }
}

/// Bottom home menu with shortcuts for daily rewards, themes, stats, shop, and settings.
class _BottomMenu extends StatelessWidget {
  const _BottomMenu({
    required this.onDaily,
    required this.onThemes,
    required this.onStats,
    required this.onShop,
    required this.onSettings,
  });

  final VoidCallback onDaily;
  final VoidCallback onThemes;
  final VoidCallback onStats;
  final VoidCallback onShop;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _homeMenuHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _MenuTile(
                label: 'THEMES',
                asset: 'lib/assets/icons/book.png',
                onTap: onThemes,
              ),
            ),
            Expanded(
              child: _MenuTile(
                label: 'DAILY',
                asset: 'lib/assets/icons/daily.png',
                onTap: onDaily,
              ),
            ),
            Expanded(
              child: _MenuTile(
                label: 'SHOP',
                asset: 'lib/assets/icons/shop.png',
                onTap: onShop,
              ),
            ),
            Expanded(
              child: _MenuTile(
                label: 'STATS',
                asset: 'lib/assets/icons/stats.png',
                onTap: onStats,
              ),
            ),
            Expanded(
              child: _MenuTile(
                label: 'SETTINGS',
                asset: 'lib/assets/icons/gear.png',
                onTap: onSettings,
              ),
            ),
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
    required this.onTap,
  });

  final String label;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 74,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
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
