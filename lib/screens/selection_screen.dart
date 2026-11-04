import 'dart:math' as math;

import 'package:exp_track/screens/transaction_screen.dart';
import 'package:exp_track/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';

class BankSelectionScreen extends StatefulWidget {
  const BankSelectionScreen({super.key});

  @override
  State<BankSelectionScreen> createState() => _BankSelectionScreenState();
}

class _BankSelectionScreenState extends State<BankSelectionScreen> with TickerProviderStateMixin {

  final List<String> uaeBanks = [
    'Emirates NBD',
    'First Abu Dhabi Bank (FAB)',
    'Abu Dhabi Commercial Bank (ADCB)',
    'Dubai Islamic Bank (DIB)',
    'Mashreq Bank',
    'Abu Dhabi Islamic Bank (ADIB)',
    'Commercial Bank of Dubai (CBD)',
    'RAKBANK',
    'Sharjah Islamic Bank (SIB)',
    'National Bank of Fujairah (NBF)',
  ];
  
  String? selectedBank;
  // One entrance sequence: glow -> donut draws -> icon -> title -> tagline
  late final AnimationController _entryController;

  // Slow loop used only for the soft glow behind the donut
  late final AnimationController _pulseController;

  late final Animation<double> _glowFade;
  late final Animation<double> _donut;
  late final Animation<double> _iconFade;
  late final Animation<double> _iconScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleTracking;
  late final Animation<double> _taglineFade;

  CurvedAnimation _interval(double begin, double end, Curve curve) {
    return CurvedAnimation(
      parent: _entryController,
      curve: Interval(begin, end, curve: curve),
    );
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _glowFade = _interval(0.0, 0.3, Curves.easeOut);
    _donut = _interval(0.08, 0.75, Curves.linear);
    _iconFade = _interval(0.5, 0.65, Curves.easeOut);
    _iconScale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(_interval(0.5, 0.78, Curves.easeOutBack));
    _titleFade = _interval(0.62, 0.85, Curves.easeOut);
    _titleTracking = Tween<double>(begin: 5.0, end: -0.5)
        .animate(_interval(0.62, 0.9, Curves.easeOutCubic));
    _taglineFade = _interval(0.8, 1.0, Curves.easeOut);

    // Respect the "remove animations" accessibility setting
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduceMotion) {
      _entryController.value = 1.0;
      _init();
    } else {
      _pulseController.repeat(reverse: true);
      _entryController.forward().whenComplete(_init);
    }
  }

  Future<void> _init()async{
    await Future.delayed(Duration(milliseconds: 500));
    if(!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) =>TransactionListScreen(bank: "Dubai Islamic Bank")));
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildGlow() {
    return FadeTransition(
      opacity: _glowFade,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + 0.06 * _pulseController.value,
            child: child,
          );
        },
        child: Container(
          height: 340,
          width: 340,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.mint.withValues(alpha: 0.20),
                AppColors.mint.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonut() {
    return SizedBox(
      height: 190,
      width: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(190, 190),
            painter: _DonutPainter(progress: _donut),
          ),
          FadeTransition(
            opacity: _iconFade,
            child: ScaleTransition(
              scale: _iconScale,
              child: Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 42,
                  color: AppColors.mint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return FadeTransition(
      opacity: _titleFade,
      child: AnimatedBuilder(
        animation: _titleTracking,
        builder: (context, child) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Expense Tracker',
              style: GoogleFonts.sora(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: _titleTracking.value,
                color: AppColors.mist,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _taglineFade,
      child: Text(
        'Know where every dirham goes',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.slate,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.ink,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.navy, AppColors.ink],
            ),
          ),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow sits behind the donut, slightly above screen center
                Align(
                  alignment: const Alignment(0, -0.22),
                  child: _buildGlow(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDonut(),
                      const SizedBox(height: 44),
                      _buildTitle(),
                      const SizedBox(height: 12),
                      _buildTagline(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slice {
  const _Slice(this.fraction, this.color);
  final double fraction;
  final Color color;
}

/// Draws a spending-breakdown donut that sweeps in one slice at a time.
class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  // Fractions add up to 1.0
  static const _slices = <_Slice>[
    _Slice(0.38, AppColors.mint),
    _Slice(0.27, AppColors.sky),
    _Slice(0.21, AppColors.amber),
    _Slice(0.14, AppColors.coral),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    const stroke = 16.0;
    const gap = 0.32; // radians, wide enough that round caps don't touch

    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint track so the ring reads before the slices arrive
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(center, radius, track);

    var start = -math.pi / 2 + gap / 2;
    for (var i = 0; i < _slices.length; i++) {
      final slice = _slices[i];
      final full = slice.fraction * 2 * math.pi - gap;

      // Each slice starts a little after the previous one
      final local = ((t - i * 0.16) / 0.5).clamp(0.0, 1.0);
      final sweep = full * Curves.easeOutCubic.transform(local);

      if (sweep > 0) {
        final glow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = slice.color.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = slice.color;

        canvas.drawArc(rect, start, sweep, false, glow);
        canvas.drawArc(rect, start, sweep, false, arc);
      }

      start += slice.fraction * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => false;
}