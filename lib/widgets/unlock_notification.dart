import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';

void showUnlockNotification(
  BuildContext context, {
  required String label,
  required VoidCallback onOpen,
}) {
  late OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) =>
        _UnlockNotification(label: label, onOpen: onOpen, onDismiss: remove),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
}

class _UnlockNotification extends StatefulWidget {
  const _UnlockNotification({
    required this.label,
    required this.onOpen,
    required this.onDismiss,
  });

  final String label;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  State<_UnlockNotification> createState() => _UnlockNotificationState();
}

class _UnlockNotificationState extends State<_UnlockNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _slide = Tween(
      begin: const Offset(-1.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _timer = Timer(const Duration(seconds: 4), _dismiss);
  }

  Future<void> _dismiss({bool open = false}) async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismiss();
    if (open) widget.onOpen();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          child: SlideTransition(
            position: _slide,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Material(
                color: const Color(0xFF162839).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(10),
                child: ForestPressBounce(
                  child: InkWell(
                    onTap: () => _dismiss(open: true),
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: forestSectionBorder,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'lib/assets/icons/star.png',
                            width: 30,
                            height: 30,
                            filterQuality: FilterQuality.none,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ACHIEVEMENT UNLOCKED',
                                  style: TextStyle(
                                    color: forestGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.label.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: forestPanelText,
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
      ),
    );
  }
}
