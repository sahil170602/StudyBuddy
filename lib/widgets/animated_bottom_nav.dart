// lib/widgets/animated_bottom_nav.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/siri_bubble.dart';

typedef IndexCallback = void Function(int index);
typedef VoidCallbackOpt = void Function();

class AnimatedBottomNav extends StatefulWidget {
  final int currentIndex;
  final IndexCallback onTap;
  final VoidCallbackOpt? centerActionOnTap;
  final int assistantUnreadCount;

  const AnimatedBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.centerActionOnTap,
    this.assistantUnreadCount = 0,
  }) : super(key: key);

  @override
  State<AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<AnimatedBottomNav>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _glowController;

  static const double _navBaseHeight = 86.0; // visual bar area (excludes safe area)
  static const double _glassRadius = 22.0;
  static const double _horizontalPadding = 12.0;

  @override
  void initState() {
    super.initState();

    // repeated animations: need multiple tickers -> use TickerProviderStateMixin
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 370),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  static const _icons = <IconData>[
    Icons.dashboard_customize,
    Icons.folder_shared,
    Icons.chat, // center replaced by SiriBubble
    Icons.notifications_active,
    Icons.school,
  ];

  static const _labels = <String>[
    'Dashboard',
    'My Stuff',
    'Assistant',
    'Notifications',
    'Quiz',
  ];

  // glow widget behind active icon (animated)
  Widget _activeGlow(Color color, bool active) {
    // Avoid heavy builds inside the builder — do only small UI work.
    return AnimatedBuilder(
      animation: active ? _pulseController : _glowController,
      builder: (context, child) {
        final t = active ? _pulseController.value : 0.0;
        final double scale = 1.0 + (active ? (t * 0.18) : 0.0);
        final double alpha = active ? (0.18 + (t * 0.18)) : 0.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withOpacity(alpha), color.withOpacity(alpha * 0.2)],
              ),
              boxShadow: [
                BoxShadow(color: color.withOpacity(alpha * 0.9), blurRadius: 18 * (1 + t), spreadRadius: 0.6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int logicalIndex,
      {required bool active, required VoidCallback onTap}) {
    final icon = _icons[logicalIndex];
    final label = _labels[logicalIndex];
    final color = active ? Colors.blueAccent : Colors.white70;
    final double iconSize = active ? 26 : 22;

    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: _navBaseHeight,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (active) _activeGlow(Colors.blueAccent, active),
                    Icon(icon, size: iconSize, color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(double availableWidth) {
    final double desired = 74.0;
    final double size = desired.clamp(56.0, availableWidth * 0.28);

    return SizedBox(
      width: size + 18,
      height: size + 18,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final t = _pulseController.value;
            final double ringSize = (size + 18) + (t * 8);
            final double opacity = (1.0 - t) * 0.28;

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(opacity * 0.5),
                  ),
                ),

                SiriBubble(
                  size: size,
                  showPulse: true,
                  baseTint: Colors.deepPurple.shade900,
                  unreadCount: widget.assistantUnreadCount,
                  onTap: () {
                    if (widget.centerActionOnTap != null) {
                      widget.centerActionOnTap!();
                    } else {
                      widget.onTap(2);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final totalHeight = _navBaseHeight + safeBottom;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _horizontalPadding,
            right: _horizontalPadding,
            bottom: safeBottom,
            height: _navBaseHeight - 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_glassRadius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(_glassRadius),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      _buildNavItem(0, active: widget.currentIndex == 0, onTap: () => widget.onTap(0)),
                      _buildNavItem(1, active: widget.currentIndex == 1, onTap: () => widget.onTap(1)),

                      SizedBox(width: 90),

                      _buildNavItem(3, active: widget.currentIndex == 3, onTap: () => widget.onTap(3)),
                      _buildNavItem(4, active: widget.currentIndex == 4, onTap: () => widget.onTap(4)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: safeBottom + (_navBaseHeight / 2) - 36,
            left: 0,
            right: 0,
            child: Center(child: _buildCenterButton(MediaQuery.of(context).size.width - (_horizontalPadding * 2))),
          ),
        ],
      ),
    );
  }
}
