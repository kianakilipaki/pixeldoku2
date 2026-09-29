import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const forestGold = Color(0xFFEEC027);
const forestPanelBlue = Color(0xFF123D6D);
const forestPanelText = Color(0xFFFFE3A0);
const forestSectionBorder = Color(0xFFB3682D);

/// Plays a subtle but noticeable tactile response and respects device settings.
void forestTapHaptic() {
  unawaited(HapticFeedback.lightImpact());
}

const forestTitleGoldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFFFE75A),
    Color(0xFFFFD12A),
    Color(0xFFFFA40D),
    Color(0xFFE87505),
  ],
  stops: [0, 0.32, 0.68, 1],
);

const _headerPanel = 'lib/assets/wood/wood-panel-sm-lvs.png';
const _woodPanelLong = 'lib/assets/wood/wood-panel-long.png';

const forestPixelShadow = Shadow(
  offset: Offset(2, 2),
  blurRadius: 0,
  color: Colors.black,
);

LinearGradient profileBackgroundGradient(int colorValue) {
  final base = Color(colorValue);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(Colors.white, base, 0.38)!,
      base,
      Color.lerp(Colors.black, base, 0.62)!,
    ],
    stops: const [0, 0.52, 1],
  );
}

class ProfileGradientBackground extends StatelessWidget {
  const ProfileGradientBackground({
    super.key,
    required this.colorValue,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final int colorValue;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: profileBackgroundGradient(colorValue),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Paints a warm wood-tone gradient around section containers.
class ForestWoodBorder extends StatelessWidget {
  const ForestWoodBorder({super.key, required this.child, this.radius = 12});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _ForestWoodBorderPainter(radius: radius),
      child: child,
    );
  }
}

class _ForestWoodBorderPainter extends CustomPainter {
  const _ForestWoodBorderPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final bounds = Offset.zero & size;
    final frame = RRect.fromRectAndRadius(
      bounds.deflate(3),
      Radius.circular(radius),
    );
    final border = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF783602), Color(0xFF522301)],
      ).createShader(bounds)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawRRect(frame, border);
  }

  @override
  bool shouldRepaint(_ForestWoodBorderPainter oldDelegate) {
    return oldDelegate.radius != radius;
  }
}

/// Keep page artwork and controls above the phone's navigation area.
class ForestNavigationSafeArea extends StatelessWidget {
  const ForestNavigationSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        maintainBottomViewPadding: true,
        // The outer shell owns this inset; page SafeAreas must not add it twice.
        child: MediaQuery.removeViewPadding(
          context: context,
          removeBottom: true,
          child: child,
        ),
      ),
    );
  }
}

/// Preserve readable controls on short phones, scrolling only when necessary.
class ForestResponsiveViewport extends StatelessWidget {
  const ForestResponsiveViewport({
    super.key,
    required this.minimumHeight,
    required this.child,
  });

  final double minimumHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight < minimumHeight
            ? minimumHeight
            : constraints.maxHeight;
        return SingleChildScrollView(
          child: SizedBox(
            width: constraints.maxWidth,
            height: height,
            child: child,
          ),
        );
      },
    );
  }
}

/// Shared scenic shell and wood-plaque header for secondary pages.
class ForestPageShell extends StatelessWidget {
  const ForestPageShell({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('lib/assets/bg2.png', fit: BoxFit.cover),
          ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                  child: Row(
                    children: [
                      ForestIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _ForestTitlePlaque(title: title)),
                      if (trailing != null) ...[
                        const SizedBox(width: 10),
                        trailing!,
                      ] else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ForestScrollFade(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: child,
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

/// Softens the top and bottom edges of a scrolling viewport.
class ForestScrollFade extends StatefulWidget {
  const ForestScrollFade({super.key, required this.child});

  final Widget child;

  @override
  State<ForestScrollFade> createState() => _ForestScrollFadeState();
}

class _ForestScrollFadeState extends State<ForestScrollFade> {
  bool _showTopFade = false;
  bool _showBottomFade = false;
  bool _updateScheduled = false;
  ScrollMetrics? _pendingMetrics;

  void _scheduleFadeUpdate(ScrollMetrics metrics) {
    _pendingMetrics = metrics;
    if (_updateScheduled) return;

    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted || _pendingMetrics == null) return;

      final latest = _pendingMetrics!;
      _pendingMetrics = null;
      final showTop = latest.extentBefore > 0.5;
      final showBottom = latest.extentAfter > 0.5;
      if (showTop == _showTopFade && showBottom == _showBottomFade) return;

      setState(() {
        _showTopFade = showTop;
        _showBottomFade = showBottom;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) {
          _scheduleFadeUpdate(notification.metrics);
        }
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            _scheduleFadeUpdate(notification.metrics);
          }
          return false;
        },
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _showTopFade ? Colors.transparent : Colors.black,
              Colors.black,
              Colors.black,
              _showBottomFade ? Colors.transparent : Colors.black,
            ],
            stops: const [0, 0.045, 0.955, 1],
          ).createShader(bounds),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ForestTitlePlaque extends StatelessWidget {
  const _ForestTitlePlaque({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final titleFontSize = switch (title.toUpperCase()) {
      'LEADERBOARD' || 'COLLECTIONS' => 20.0,
      _ => 24.0,
    };

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_headerPanel),
          fit: BoxFit.contain,
        ),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Transform.translate(
          offset: const Offset(0, 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontFamily: 'Silkscreen',
                fontWeight: FontWeight.bold,
                shadows: [forestPixelShadow],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent blue content area with a warm border and wood title plaque.
class ForestSection extends StatelessWidget {
  const ForestSection({
    super.key,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 72, 14, 14),
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Container(
            width: double.infinity,
            padding: padding.subtract(const EdgeInsets.only(top: 20)),
            decoration: BoxDecoration(
              color: const Color(0xFF2A4864).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: forestSectionBorder, width: 3),
            ),
            child: child,
          ),
        ),
        Positioned(
          top: -10,
          left: 12,
          right: 12,
          child: AspectRatio(
            aspectRatio: 823 / 185,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_woodPanelLong),
                  fit: BoxFit.contain,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 38),
                  child: Transform.translate(
                    offset: const Offset(0, 5),
                    child: Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontFamily: 'Silkscreen',
                        fontWeight: FontWeight.bold,
                        shadows: [forestPixelShadow],
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
}

/// Consistent dark row used by settings, shop, and theme lists.
class ForestListRow extends StatelessWidget {
  const ForestListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ForestPressBounce(
      enabled: onTap != null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: const Color(0xFF111820).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF68431E), width: 2),
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    SizedBox(width: 40, child: Center(child: leading)),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            color: forestPanelText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Fira Sans',
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
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

/// Gives tappable controls a subtle, quick press-and-release bounce without
/// taking over their gestures or changing their layout.
class ForestPressBounce extends StatefulWidget {
  const ForestPressBounce({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.95,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<ForestPressBounce> createState() => _ForestPressBounceState();
}

class _ForestPressBounceState extends State<ForestPressBounce> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    if (value) forestTapHaptic();
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant ForestPressBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: Duration(milliseconds: _pressed ? 70 : 160),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

class ForestIconButton extends StatelessWidget {
  const ForestIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ForestPressBounce(
      child: IconButton(
        onPressed: onTap,
        tooltip: 'Back',
        iconSize: 32,
        color: forestSectionBorder,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        icon: icon == Icons.arrow_back
            ? Image.asset(
                'lib/assets/icons/backArrow.png',
                width: 32,
                height: 32,
                filterQuality: FilterQuality.none,
              )
            : Icon(icon),
      ),
    );
  }
}

class ForestButton extends StatelessWidget {
  const ForestButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.fontSize,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final double? fontSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ForestPressBounce(
      enabled: onPressed != null,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor:
              backgroundColor ??
              (danger ? const Color(0xFF9D2C1B) : forestPanelBlue),
          foregroundColor: forestPanelText,
          disabledBackgroundColor: Colors.black45,
          side: BorderSide(
            color: danger ? Colors.redAccent : forestSectionBorder,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
        ),
        onPressed: onPressed,
        child: Text(label.toUpperCase()),
      ),
    );
  }
}

class ForestCoinBadge extends StatelessWidget {
  const ForestCoinBadge({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF352108).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: forestGold, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('lib/assets/icons/coin.png', width: 18, height: 18),
          const SizedBox(width: 5),
          Text(
            '$coins',
            style: const TextStyle(
              color: forestPanelText,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
