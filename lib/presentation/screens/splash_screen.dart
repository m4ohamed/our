// lib/presentation/screens/splash_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generated/l10n.dart';

import '../providers/audio_provider.dart';
import '../providers/app_providers.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _navTimer = Timer(const Duration(seconds: 3), _navigateToNext);
  }

  void _initAudio() {
    final audioCtrl = ref.read(audioControllerProvider);
    final musicEnabled = ref.read(isMusicEnabledProvider);
    final volume = ref.read(musicVolumeProvider);
    if (musicEnabled) {
      audioCtrl.playWeddingCelebration(volume);
    }
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;
    final settings = await ref.read(settingsProvider.future);
    if (!mounted) return;

    final shouldRequirePin =
        settings.pinEnabled &&
        settings.pinHash != null &&
        settings.pinHash!.isNotEmpty;

    final Widget targetScreen = shouldRequirePin
        ? PinVerifyScreen(
            onVerified: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          )
        : const HomeScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => targetScreen,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationsEnabled = ref.watch(isAnimationsEnabledProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),

          if (animationsEnabled) const _FallingHearts(),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMainHeart(animationsEnabled),
                const SizedBox(height: 60),
                _buildTitles(context),
                const SizedBox(height: 100),
                _buildLoader(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainHeart(bool animationsEnabled) {
    final heartIcon = Icon(
      Icons.favorite_rounded,
      size: 70,
      color: Theme.of(context).colorScheme.primary,
    );

    return RepaintBoundary(
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.5),
                    ),
                  ),
                  child: animationsEnabled
                      ? heartIcon
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(1.0, 1.0),
                              end: const Offset(1.15, 1.15),
                              duration: 1500.ms,
                              curve: Curves.easeInOut,
                            )
                      : heartIcon,
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 1000.ms)
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          curve: Curves.elasticOut,
        );
  }

  Widget _buildTitles(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Text(
              s.coupleName,
              style: Theme.of(context).textTheme.displayLarge,
              textAlign: TextAlign.center,
            )
            .animate()
            .fadeIn(duration: 1200.ms, delay: 400.ms)
            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCirc),

        const SizedBox(height: 8),

        Text(
          s.appName,
          style: GoogleFonts.notoSerif(
            fontSize: 20,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 1200.ms, delay: 800.ms),

        const SizedBox(height: 32),

        Text(
              s.loveStoryBegins,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            )
            .animate()
            .fadeIn(duration: 1000.ms, delay: 1200.ms)
            .shimmer(duration: 3000.ms, delay: 2000.ms),
      ],
    );
  }

  Widget _buildLoader(BuildContext context) {
    final s = S.of(context);
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: 2,
            ),
          ).animate().fadeIn(delay: 1500.ms),

          const SizedBox(height: 12),

          Text(
            s.preparingMagic,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              letterSpacing: 1.5,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 2000.ms),
        ],
      ),
    );
  }
}

class _FallingHearts extends StatelessWidget {
  const _FallingHearts();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return RepaintBoundary(
      child: Stack(
        children: List.generate(8, (i) {
          return Positioned(
            left: (i * 53.0) % screenWidth,
            child:
                Icon(
                      Icons.favorite,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08),
                      size: 14 + (i % 4) * 8,
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .moveY(
                      begin: -50,
                      end: screenHeight + 50,
                      duration: (7000 + i * 600).ms,
                      delay: (i * 400).ms,
                      curve: Curves.linear,
                    ),
          );
        }),
      ),
    );
  }
}
