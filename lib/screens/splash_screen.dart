import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:ui';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _heartController;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _setupAnimations();
    _startNavigationTimer();
  }

  void _initializeAudio() async {
    _audioPlayer = AudioPlayer();
    try {
      // تشغيل موسيقى رومانسية من الـ assets
      await _audioPlayer.play(AssetSource('audio/romantic_intro.mp3'));
      await _audioPlayer.setVolume(0.5);
    } catch (e) {
      debugPrint('خطأ في تشغيل الموسيقى: $e');
    }
  }

  void _setupAnimations() {
    _heartController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _heartController.repeat();
  }

  void _startNavigationTimer() {
    _navigationTimer = Timer(const Duration(seconds: 3), () {
      _navigateToHome();
    });
  }

  void _navigateToHome() async {
    await _audioPlayer.stop();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _heartController.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pearlWhite,
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    AppColors.white,
                    AppColors.surfaceRose,
                    AppColors.pearlWhite,
                  ],
                ),
              ),
            ),
          ),

          // Falling Petals/Hearts
          _buildFallingHeartsBackground(),

          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glassmorphic Main Heart
                _buildMainHeart(),

                const SizedBox(height: 60),

                // Main Title
                Column(
                  children: [
                    Text(
                          'Mohamed ❤️ Sara',
                          style: Theme.of(context).textTheme.displayLarge,
                          textAlign: TextAlign.center,
                        )
                        .animate()
                        .fadeIn(duration: 1200.ms, delay: 400.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCirc),

                    const SizedBox(height: 8),

                    Text(
                      'محمد ❤️ سارة',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.dustyRose.withValues(alpha: 0.6),
                            letterSpacing: 2,
                          ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 1200.ms, delay: 800.ms),
                  ],
                ),

                const SizedBox(height: 32),

                // Subtitle
                Text(
                      'Our Love Story Begins...',
                      style: Theme.of(context).textTheme.labelLarge,
                      textAlign: TextAlign.center,
                    )
                    .animate()
                    .fadeIn(duration: 1000.ms, delay: 1200.ms)
                    .shimmer(duration: 3000.ms, delay: 2000.ms),

                const SizedBox(height: 100),

                // Minimalist Loading
                _buildLoadingIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallingHeartsBackground() {
    return Stack(
      children: List.generate(15, (index) {
        final delay = (index * 300).ms;
        return Positioned(
          left: (index * 37) % MediaQuery.of(context).size.width,
          child:
              Icon(
                    Icons.favorite,
                    color: AppColors.dustyRose.withValues(alpha: 0.1),
                    size: 15 + (index % 4) * 8,
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .moveY(
                    begin: -50,
                    end: MediaQuery.of(context).size.height + 50,
                    duration: (6000 + (index * 500)).ms,
                    delay: delay,
                    curve: Curves.linear,
                  )
                  .rotate(begin: 0, end: 0.2, duration: 3000.ms)
                  .then()
                  .rotate(begin: 0.2, end: -0.2, duration: 3000.ms),
        );
      }),
    );
  }

  Widget _buildMainHeart() {
    return Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.dustyRose.withValues(alpha: 0.2),
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
                  color: AppColors.white.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Center(
                  child:
                      Icon(
                            Icons.favorite_rounded,
                            size: 70,
                            color: AppColors.dustyRose,
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .scale(
                            begin: const Offset(1.0, 1.0),
                            end: const Offset(1.15, 1.15),
                            duration: 1500.ms,
                            curve: Curves.easeInOut,
                          )
                          .then()
                          .scale(
                            begin: const Offset(1.15, 1.15),
                            end: const Offset(1.0, 1.0),
                            duration: 1500.ms,
                            curve: Curves.easeInOut,
                          ),
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

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  backgroundColor: AppColors.surfaceRose,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.dustyRose,
                  ),
                  minHeight: 2,
                ),
              )
              .animate()
              .fadeIn(delay: 1500.ms)
              .custom(
                duration: 1000.ms,
                builder: (context, value, child) =>
                    SizedBox(width: value * 120, child: child),
              ),

          const SizedBox(height: 12),

          Text(
            'Preparing our magic...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.lightText.withValues(alpha: 0.7),
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
