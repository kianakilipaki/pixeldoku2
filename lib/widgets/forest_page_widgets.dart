import 'package:flutter/material.dart';

const forestGold = Color(0xFFEEC027);
const forestPanelBlue = Color(0xFF123D6D);
const forestPanelText = Color(0xFFFFE3A0);

const forestShinyGold = LinearGradient(
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

const _headerPanel = 'lib/assets/wood-panel-sm-lvs.png';
const _woodPanelLong = 'lib/assets/wood-panel-long.png';

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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            style: const TextStyle(
              color: forestPanelText,
              fontSize: 24,
              fontFamily: 'Silkscreen',
              fontWeight: FontWeight.bold,
              shadows: [forestPixelShadow],
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent brown content area with a small wood title plaque.
class ForestSection extends StatelessWidget {
  const ForestSection({
    super.key,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 92, 14, 14),
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
          child: ForestWoodBorder(
            child: Container(
              width: double.infinity,
              padding: padding,
              decoration: BoxDecoration(
                color: const Color(0xFF30190B).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, offset: Offset(0, 4)),
                ],
              ),
              child: child,
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF111820).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
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
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: forestPanelBlue,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: forestGold, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 27),
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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: danger ? const Color(0xFF9D2C1B) : forestPanelBlue,
        foregroundColor: forestPanelText,
        disabledBackgroundColor: Colors.black45,
        side: BorderSide(color: danger ? Colors.redAccent : forestGold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: onPressed,
      child: Text(label.toUpperCase()),
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
