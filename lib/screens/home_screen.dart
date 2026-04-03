import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'timeline_screen.dart';
import 'countdown_screen.dart';
import 'surprise_screen.dart';
import 'memories_album_screen.dart';
import 'settings_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pearlWhite,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Our Love Story',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.darkText,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.lightText,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.8, -0.6),
                  radius: 1.5,
                  colors: [
                    AppColors.surfaceRose,
                    AppColors.white,
                    AppColors.pearlWhite,
                  ],
                ),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Section: Our Photo & Days Together
                  _buildHeroSection(context)
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 48),

                  // Section Title
                  Text(
                    'JOURNEY TOGETHER',
                    style: Theme.of(context).textTheme.labelLarge,
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 24),

                  // Staggered Navigation Grid
                  _buildNavigationGrid(context),

                  const SizedBox(height: 48),

                  // Quote / Emotional Footnote
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: AppColors.dustyRose,
                          size: 16,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '"Every moment with you is a cinematic heirloom."',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppColors.lightText.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 1200.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final daysTogether = DateTime.now()
        .difference(DateTime(2025, 1, 31))
        .inDays;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Circular Photo with Glass Border
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.dustyRose.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/our.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.surfaceRose,
                      child: const Icon(
                        Icons.favorite,
                        color: AppColors.dustyRose,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Days Counter
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Days of Love',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.lightText),
              ),
              Text(
                '$daysTogether',
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontSize: 64, height: 1),
              ),
              const SizedBox(height: 8),
              Container(height: 2, width: 40, color: AppColors.champagneGold),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 20) / 2;
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildGlassTile(
              context,
              'Timeline',
              '🕒',
              'Our milestones',
              itemWidth,
              200,
              () => _navigateToScreen(context, 'التايم لاين'),
              index: 0,
            ),
            _buildGlassTile(
              context,
              'Memories',
              '📷',
              'Captured hearts',
              itemWidth,
              160,
              () => _navigateToScreen(context, 'الألبوم'),
              index: 1,
            ),
            _buildGlassTile(
              context,
              'Surprise',
              '💌',
              'For you only',
              itemWidth,
              160,
              () => _navigateToScreen(context, 'المفاجأة'),
              index: 2,
            ),
            _buildGlassTile(
              context,
              'Wait...',
              '⏳',
              'Upcoming bliss',
              itemWidth,
              200,
              () => _navigateToScreen(context, 'العد التنازلي'),
              index: 3,
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassTile(
    BuildContext context,
    String title,
    String emoji,
    String subtitle,
    double width,
    double height,
    VoidCallback onTap, {
    required int index,
  }) {
    return GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.6),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.white.withValues(alpha: 0.4),
                        AppColors.surfaceRose.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 32)),
                      const Spacer(),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.lightText.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (600 + index * 100).ms)
        .slideY(begin: 0.2, end: 0);
  }

  void _navigateToScreen(BuildContext context, String title) {
    Widget screen;
    switch (title) {
      case 'العد التنازلي':
        screen = const CountdownScreen();
        break;
      case 'التايم لاين':
        screen = const TimelineScreen();
        break;
      case 'الألبوم':
        screen = const MemoriesAlbumScreen();
        break;
      case 'المفاجأة':
        screen = const SurpriseScreen();
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
