// File: lib/widgets/siri_bubble.dart
// Reusable Siri-like animated bubble widget with unread badge support.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SiriBubble extends StatefulWidget {
  /// Diameter of the bubble in logical pixels.
  final double size;

  /// Called when the bubble is tapped.
  final VoidCallback? onTap;

  /// Whether to show a subtle ambient pulsing ring (default true).
  final bool showPulse;

  /// Background color used as a tint when blending (keeps it adaptive for themes).
  final Color baseTint;

  /// Unread count for assistant — if >0 shows a red badge. Default 0 (hidden).
  final int unreadCount;

  const SiriBubble({
    Key? key,
    this.size = 120,
    this.onTap,
    this.showPulse = true,
    this.baseTint = const Color(0xFF0A0A1A),
    this.unreadCount = 0,
  }) : super(key: key);

  @override
  State<SiriBubble> createState() => _SiriBubbleState();
}

class _SiriBubbleState extends State<SiriBubble> with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _swirlController;
  late final AnimationController _pulseController;
  late final AnimationController _badgePulseController;
  late final Animation<double> _rotAnim;
  late final Animation<double> _swirlAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _badgeAnim;

  // interactive scale on tap
  double _tapScale = 1.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _rotAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(CurvedAnimation(parent: _rotationController, curve: Curves.linear));
    _swirlController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _swirlAnim = CurvedAnimation(parent: _swirlController, curve: Curves.easeInOut);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    // badge pulse — only active when unreadCount > 0
    _badgePulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _badgeAnim = CurvedAnimation(parent: _badgePulseController, curve: Curves.easeInOut);

    if (widget.unreadCount > 0) {
      _badgePulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant SiriBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // start/stop badge animation when unread changes cross zero boundary
    if (oldWidget.unreadCount == 0 && widget.unreadCount > 0) {
      _badgePulseController.repeat(reverse: true);
    } else if (oldWidget.unreadCount > 0 && widget.unreadCount == 0) {
      _badgePulseController.stop();
      _badgePulseController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _swirlController.dispose();
    _pulseController.dispose();
    _badgePulseController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails d) => setState(() => _tapScale = 0.92);
  void _onTapUp(TapUpDetails d) { setState(() => _tapScale = 1.0); widget.onTap?.call(); }
  void _onTapCancel() => setState(() => _tapScale = 1.0);

  @override
  Widget build(BuildContext context) {
    final diameter = widget.size;
    final layerSize = diameter;
    final paletteA = [Color(0xFF7B61FF), Color(0xFF11D3FF)];
    final paletteB = [Color(0xFFFF6EC7), Color(0xFF9D7AFF)];
    final paletteC = [Color(0xFF64FFDA), Color(0xFF3A84FF)];

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotAnim, _swirlAnim, _pulseAnim, _badgeAnim]),
        builder: (context, child) {
          final rot = _rotAnim.value;
          final swirl = _swirlAnim.value;
          final pulse = _pulseAnim.value;
          final badgePulse = _badgeAnim.value;
          final blobRotationA = rot * 0.6 + (swirl * 0.9);
          final blobRotationB = -rot * 0.4 + (swirl * 0.5);
          final blobRotationC = rot * 0.9 - (swirl * 0.7);
          final tx = (math.sin(swirl * math.pi * 2) * 6);
          final ty = (math.cos(swirl * math.pi * 2) * 6);
          final ringAlpha = (0.16 + (pulse * 0.14)).clamp(0.05, 0.32);

          return Transform.scale(
            scale: _tapScale,
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (widget.showPulse)
                    Container(
                      width: layerSize * (1.0 + 0.24 * pulse),
                      height: layerSize * (1.0 + 0.24 * pulse),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.baseTint.withOpacity(ringAlpha),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(ringAlpha * 0.7),
                            blurRadius: 38 * (1 + pulse),
                            spreadRadius: 6 * pulse,
                          )
                        ],
                      ),
                    ),

                  ClipOval(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 6.0 * (1.0 - 0.1 * pulse), sigmaY: 6.0 * (1.0 - 0.1 * pulse)),
                      child: Container(
                        width: layerSize,
                        height: layerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Colors.white.withOpacity(0.04), Colors.white.withOpacity(0.02), Colors.transparent],
                            stops: const [0.0, 0.55, 1.0],
                            center: Alignment(-0.3, -0.3),
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
                        ),
                      ),
                    ),
                  ),

                  // Blob A
                  Transform.translate(
                    offset: Offset(tx * 0.9, ty * 0.6),
                    child: Transform.rotate(
                      angle: blobRotationA,
                      child: Opacity(
                        opacity: 0.98,
                        child: SizedBox(
                          width: layerSize * 0.86,
                          height: layerSize * 0.86,
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment(-0.4 + swirl * 0.12, -0.14 + swirl * 0.06),
                                child: Container(
                                  width: layerSize * 0.78,
                                  height: layerSize * 0.78,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [paletteA[0].withOpacity(0.92), paletteA[1].withOpacity(0.25)],
                                      stops: const [0.0, 0.95],
                                      center: Alignment(-0.25, -0.25),
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment(0.32 + swirl * 0.08, 0.18 - swirl * 0.05),
                                child: Container(
                                  width: layerSize * 0.44,
                                  height: layerSize * 0.44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [paletteB[1].withOpacity(0.75), paletteB[0].withOpacity(0.12)],
                                      stops: const [0.0, 0.95],
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

                  // Blob B
                  Transform.translate(
                    offset: Offset(-tx * 0.8, -ty * 0.5),
                    child: Transform.rotate(
                      angle: blobRotationB,
                      child: Opacity(
                        opacity: 0.95,
                        child: SizedBox(
                          width: layerSize * 0.72,
                          height: layerSize * 0.72,
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment(0.2 - swirl * 0.08, -0.18 + swirl * 0.06),
                                child: Container(
                                  width: layerSize * 0.6,
                                  height: layerSize * 0.6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [paletteC[0].withOpacity(0.86), paletteC[1].withOpacity(0.22)],
                                      stops: const [0.0, 0.96],
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment(-0.26 + swirl * 0.05, 0.3 - swirl * 0.06),
                                child: Container(
                                  width: layerSize * 0.34,
                                  height: layerSize * 0.34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [paletteB[0].withOpacity(0.9), paletteB[1].withOpacity(0.18)],
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

                  Container(
                    width: layerSize,
                    height: layerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        startAngle: 0,
                        endAngle: math.pi * 2,
                        colors: [Colors.white.withOpacity(0.035), Colors.white.withOpacity(0.01), Colors.white.withOpacity(0.035)],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment(-0.05, -0.05),
                    child: Container(
                      width: layerSize * 0.14,
                      height: layerSize * 0.14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.06)]),
                        boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.18), blurRadius: 10, spreadRadius: 2)],
                      ),
                    ),
                  ),

                  Container(
                    width: layerSize,
                    height: layerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
                    ),
                  ),

                  // -------------------- Unread badge (top-right) --------------------
                  if (widget.unreadCount > 0)
                    Positioned(
                      // place slightly outside the bubble edge for better visibility
                      right: -layerSize * 0.06,
                      top: -layerSize * 0.06,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.12).animate(_badgeAnim),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.redAccent.withOpacity(0.35), blurRadius: 8 * (0.9 + 0.2 * badgePulse), spreadRadius: 0.5),
                            ],
                            border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.6),
                          ),
                          child: Center(
                            child: Text(
                              widget.unreadCount <= 9 ? '${widget.unreadCount}' : '9+',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
