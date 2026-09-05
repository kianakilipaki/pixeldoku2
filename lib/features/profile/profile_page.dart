import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pixeldoku/models/title_catalog.dart';
import 'package:pixeldoku/services/auth_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _gold = Color(0xFFEEC027);
const _panelText = Color(0xFFFFE3A0);
const _largePanel = 'lib/assets/wood-panel-curved.png';
const _headerPanel = 'lib/assets/wood-panel-sm-lvs.png';
const _woodPanelLong = 'lib/assets/wood-panel-long.png';
const _lockAsset = 'lib/assets/icons/lock.png';
const _largePanelAspectRatio = 508 / 593;
const _headerPanelAspectRatio = 583 / 176;

/// Metallic border used by the stats, section bodies, and authentication card.
/// Alternating light and dark stops keep the frame readable over the artwork.
const _shinyGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFF1A8),
    Color(0xFFFFCB36),
    Color(0xFF9B5A08),
    Color(0xFFFFDF62),
    Color(0xFFB36A0A),
  ],
  stops: [0, 0.2, 0.48, 0.72, 1],
);

/// Player customization, progression, title, and account management screen.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();

  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  bool _isWorking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _user = _authService.currentUser;
    _authSubscription = _authService.authStateChanges.listen((state) async {
      if (!mounted) return;

      setState(() {
        _user = state.session?.user ?? _authService.currentUser;
        _errorMessage = null;
      });

      if (_isLoggedInUser(_user)) {
        await _authService.ensureCurrentUserExists();
      }

      if (mounted) {
        await context.read<AppState>().reloadAfterAuthChange();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });

    try {
      await _authService.signOut();

      if (!mounted) return;

      setState(() {
        _user = _authService.currentUser;
      });

      await context.read<AppState>().reloadAfterAuthChange();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  bool _isLoggedInUser(User? user) {
    return user != null && !user.isAnonymous;
  }

  String _displayName(User user) {
    final metadata = user.userMetadata ?? {};
    final name = metadata['full_name'] ?? metadata['name'];

    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }

    return user.email ?? 'Signed-in User';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = _user ?? appState.user;
    final isLoggedIn = _isLoggedInUser(user);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Keep the scene visible beneath the translucent profile surfaces.
          Image.asset('lib/assets/bg2.png', fit: BoxFit.cover),
          ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
          SafeArea(
            child: Column(
              children: [
                _ProfileHeader(onBack: () => Navigator.pop(context)),
                Expanded(
                  child: ForestScrollFade(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 18),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HeroProfilePanel(
                                appState: appState,
                                displayName: isLoggedIn && user != null
                                    ? _displayName(user)
                                    : appState.name,
                              ),
                              const SizedBox(height: 12),
                              _ProfileBackgroundPanel(appState: appState),
                              const SizedBox(height: 12),
                              _ProfilePicturesPanel(appState: appState),
                              const SizedBox(height: 12),
                              _TitlePanel(appState: appState),
                              const SizedBox(height: 12),
                              _AuthPanel(
                                isWorking: _isWorking,
                                isLoggedIn: isLoggedIn,
                                errorMessage: _errorMessage,
                                onSignIn: _signInWithGoogle,
                                onSignOut: _signOut,
                                email: isLoggedIn && user != null
                                    ? user.email
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

/// Top navigation row with a standalone back button and decorated title plaque.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final panelWidth = math.min(MediaQuery.sizeOf(context).width * 0.62, 560.0);
    final panelHeight = panelWidth / _headerPanelAspectRatio;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SizedBox(
        height: panelHeight + 4,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: panelWidth,
              child: _ProfileTitleFrame(
                child: SizedBox(
                  height: panelHeight,
                  child: DecoratedBox(
                    decoration: _woodDecoration(_headerPanel, radius: 10),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'PROFILE',
                          style: TextStyle(
                            color: _panelText,
                            fontSize: 30,
                            fontFamily: 'Silkscreen',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0,
                            shadows: [_pixelShadow],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _ProfileBackButton(onTap: onBack),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone back control displayed directly over the scene.
class _ProfileBackButton extends StatelessWidget {
  const _ProfileBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Back',
      iconSize: 32,
      color: Colors.white,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 54, height: 54),
      icon: const Icon(Icons.arrow_back),
    );
  }
}

/// Primary identity card containing the avatar, editable name, title, and stats.
class _HeroProfilePanel extends StatelessWidget {
  const _HeroProfilePanel({required this.appState, required this.displayName});

  final AppState appState;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return _ProfileBoardFrame(
      child: AspectRatio(
        aspectRatio: _largePanelAspectRatio,
        child: _WoodPanel(
          asset: _largePanel,
          padding: const EdgeInsets.fromLTRB(44, 36, 44, 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 197,
                height: 197,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _shinyGoldGradient,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  child: ProfileGradientBackground(
                    colorValue: appState.profilePictureBgColor,
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(appState.profilePicture),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NAME',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: appState.name,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontFamily: 'Silkscreen',
                        fontWeight: FontWeight.bold,
                        shadows: [_pixelShadow],
                      ),
                      decoration: const InputDecoration(
                        suffixIcon: Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onFieldSubmitted: appState.setPlayerName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _TitleBadge(title: appState.playerTitle),
                ),
              ),
              const SizedBox(height: 12),
              _StatsStrip(appState: appState),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays the active player title inside the identity card.
class _TitleBadge extends StatelessWidget {
  const _TitleBadge({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'lib/assets/icons/star.png',
          width: 16,
          height: 16,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            title.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0,
              shadows: [_pixelShadow],
            ),
          ),
        ),
      ],
    );
  }
}

/// Palette used to customize the circular profile-picture background.
class _ProfileBackgroundPanel extends StatelessWidget {
  const _ProfileBackgroundPanel({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'PROFILE BACKGROUND',
      padding: const EdgeInsets.fromLTRB(24, 92, 24, 24),
      child: Wrap(
        spacing: 18,
        runSpacing: 16,
        children:
            const [
              0xFFEEC027,
              0xFFD67A20,
              0xFF9A5A2E,
              0xFF5A3825,
              0xFF6E7F32,
              0xFF3F8F4F,
              0xFF216A55,
              0xFF2B8C87,
              0xFF2878B8,
              0xFF314B78,
              0xFF55417F,
              0xFF8B9BA8,
            ].map((colorValue) {
              final selected = colorValue == appState.profilePictureBgColor;

              return GestureDetector(
                onTap: () => appState.setProfilePictureBgColor(colorValue),
                child: Container(
                  width: 36,
                  height: 36,
                  padding: EdgeInsets.all(selected ? 4 : 0),
                  decoration: BoxDecoration(
                    gradient: selected ? _shinyGoldGradient : null,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: profileBackgroundGradient(colorValue),
                      shape: BoxShape.circle,
                      border: selected
                          ? null
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 2,
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

/// Scrollable picker for unlocked and locked profile-picture assets.
class _ProfilePicturesPanel extends StatelessWidget {
  const _ProfilePicturesPanel({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'PROFILE PICTURES',
      padding: const EdgeInsets.fromLTRB(18, 92, 18, 22),
      child: SizedBox(
        height: 360,
        child: Scrollbar(
          child: ForestScrollFade(
            child: GridView.count(
              crossAxisCount: 5,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              children: appState.allProfilePictures.map((asset) {
                final selected = asset == appState.profilePicture;
                final unlocked = appState.unlockedProfilePictures.contains(
                  asset,
                );

                return GestureDetector(
                  onTap: unlocked
                      ? () => appState.setProfilePicture(asset)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: selected ? _shinyGoldGradient : null,
                      color: selected ? null : const Color(0xFF1B1B1B),
                      borderRadius: BorderRadius.circular(8),
                      border: selected
                          ? null
                          : Border.all(
                              color: const Color(0xFF63401F),
                              width: 2,
                            ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: unlocked
                                ? const Color(0xFF222222)
                                : const Color(0xFF151515),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Opacity(
                            opacity: unlocked ? 1 : 0.25,
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Image.asset(asset),
                            ),
                          ),
                        ),
                        if (!unlocked)
                          Center(
                            child: Image.asset(
                              _lockAsset,
                              width: 26,
                              height: 26,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Active title summary followed by categorized title choices.
class _TitlePanel extends StatelessWidget {
  const _TitlePanel({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final selected = TitleCatalog.byName(appState.playerTitle);

    return _SectionPanel(
      title: 'PROFILE TITLE',
      padding: const EdgeInsets.fromLTRB(18, 92, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: _shinyGoldGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF123D6D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'lib/assets/icons/star.png',
                    width: 42,
                    height: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.name.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [_pixelShadow],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selected.unlockText,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: Scrollbar(
              child: ForestScrollFade(
                child: ListView(
                  children: TitleCategory.values.map((category) {
                    final titles = TitleCatalog.byCategory(category);
                    if (titles.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TitleCatalog.categoryName(category).toUpperCase(),
                            style: const TextStyle(
                              color: _panelText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: titles.map((title) {
                              final unlocked = title.isUnlocked(appState);
                              final active = title.name == appState.playerTitle;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: _TitleOption(
                                  title: title.name,
                                  locked: !unlocked,
                                  selected: active,
                                  onTap: unlocked
                                      ? () =>
                                            appState.setPlayerTitle(title.name)
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable title row with locked, unlocked, and active states.
class _TitleOption extends StatelessWidget {
  const _TitleOption({
    required this.title,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool locked;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(selected ? 2 : 0),
        decoration: BoxDecoration(
          gradient: selected ? _shinyGoldGradient : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF123D6D) : const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? null
                : Border.all(color: const Color(0xFF5B3518), width: 2),
          ),
          child: Row(
            children: [
              if (locked) ...[
                Image.asset(_lockAsset, width: 20, height: 20),
                const SizedBox(width: 8),
              ] else ...[
                Image.asset(
                  'lib/assets/icons/trophy.png',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: locked ? const Color(0xFFB3946D) : _panelText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check, color: Color(0xFF4BE34B), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified progression strip enclosed by one continuous metallic frame.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: _shinyGoldGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black45, offset: Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF123D6D).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: 'lib/assets/icons/star.png',
                value: '${appState.currentLevel}',
                label: 'LEVEL',
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatTile(
                icon: 'lib/assets/icons/trophy.png',
                value: '${appState.statistics['levels_completed'] ?? 0}',
                label: 'SOLVED',
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatTile(
                icon: 'lib/assets/icons/trophy.png',
                value: '${appState.statistics['perfect_runs'] ?? 0}',
                label: 'PERFECT',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle separator between values inside the shared stats frame.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      color: const Color(0xFF75A9CF).withValues(alpha: 0.75),
    );
  }
}

/// Icon, value, and label for a single progression statistic.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(icon, width: 26, height: 26),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _panelText,
                  fontSize: 20,
                  fontFamily: 'Silkscreen',
                  fontWeight: FontWeight.normal,
                  shadows: [_pixelShadow],
                ),
              ),
              Text(label, style: const TextStyle(color: _gold, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Login/logout surface kept separate from the wood-themed content sections.
class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.isWorking,
    required this.isLoggedIn,
    required this.errorMessage,
    required this.onSignIn,
    required this.onSignOut,
    required this.email,
  });

  final bool isWorking;
  final bool isLoggedIn;
  final String? errorMessage;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (email != null) ...[
          Text(
            email!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
        ],
        if (isLoggedIn)
          ElevatedButton(
            onPressed: isWorking ? null : onSignOut,
            child: Text(isWorking ? 'Please wait...' : 'Sign out'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: _GoogleMaterialButton(
              enabled: !isWorking,
              label: isWorking ? 'Please wait...' : 'Sign in with Google',
              onPressed: onSignIn,
            ),
          ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
      ],
    );
  }
}

/// Flutter equivalent of Google's dark Material sign-in button.
class _GoogleMaterialButton extends StatelessWidget {
  const _GoogleMaterialButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.disabled)
              ? const Color(0x61131314)
              : const Color(0xFF131314);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.disabled)
              ? const Color(0x61E3E3E3)
              : const Color(0xFFE3E3E3);
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)) {
            return Colors.white.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          return BorderSide(
            color: states.contains(WidgetState.disabled)
                ? const Color(0x1F8E918F)
                : const Color(0xFF8E918F),
          );
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: .25,
          ),
        ),
        elevation: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.hovered) ? 2 : 0;
        }),
      ),
      onPressed: enabled ? onPressed : null,
      child: Row(
        children: [
          Opacity(opacity: enabled ? 1 : 0.38, child: const _GoogleLogo()),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 30),
        ],
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

/// Draws the four-color Google mark without requiring an SVG dependency.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.19;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      rect,
      _radians(200),
      _radians(110),
      false,
      paint..color = const Color(0xFFEA4335),
    );
    canvas.drawArc(
      rect,
      _radians(145),
      _radians(55),
      false,
      paint..color = const Color(0xFFFBBC05),
    );
    canvas.drawArc(
      rect,
      _radians(45),
      _radians(100),
      false,
      paint..color = const Color(0xFF34A853),
    );
    canvas.drawArc(
      rect,
      _radians(310),
      _radians(95),
      false,
      paint..color = const Color(0xFF4285F4),
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width * 0.93, size.height * 0.5),
      paint
        ..color = const Color(0xFF4285F4)
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}

/// Dark translucent section body with an overlapping wood title plaque.
///
/// The brown fill stays translucent so the scenic background remains visible.
class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 92, 18, 22),
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ForestWoodBorder(
              child: Container(
                width: double.infinity,
                padding: padding,
                decoration: BoxDecoration(
                  color: const Color(0xFF30190B).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      offset: Offset(0, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
          Positioned(
            top: -16,
            left: 8,
            right: 8,
            child: AspectRatio(
              aspectRatio: 823 / 185,
              child: DecoratedBox(
                decoration: _woodDecoration(
                  _woodPanelLong,
                  radius: 8,
                  fit: BoxFit.contain,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Silkscreen',
                        fontWeight: FontWeight.bold,
                        shadows: [_pixelShadow],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full wood surface reserved for the main player identity card.
class _WoodPanel extends StatelessWidget {
  const _WoodPanel({required this.child, required this.asset, this.padding});

  final Widget child;
  final String asset;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _woodDecoration(asset, radius: 12),
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(18, 16, 18, 36),
        child: child,
      ),
    );
  }
}

/// Frames the main identity card.
class _ProfileBoardFrame extends StatelessWidget {
  const _ProfileBoardFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Frames the main PROFILE plaque.
class _ProfileTitleFrame extends StatelessWidget {
  const _ProfileTitleFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

BoxDecoration _woodDecoration(
  String asset, {
  required double radius,
  BoxFit fit = BoxFit.contain,
}) {
  return BoxDecoration(
    image: DecorationImage(image: AssetImage(asset), fit: fit),
  );
}

const _pixelShadow = Shadow(
  offset: Offset(2, 2),
  blurRadius: 0,
  color: Colors.black,
);
