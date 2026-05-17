// lib/presentation/screens/baby_countdown_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/glass_container.dart';
import '../../generated/l10n.dart';

final _tickProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

class BabyCountdownScreen extends ConsumerWidget {
  const BabyCountdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_tickProvider);
    final s = S.of(context);
    final theme = Theme.of(context);

    final now = DateTime.now();
    final arrivalDate = AppConstants.babyExpectedDate;
    final difference = arrivalDate.difference(now);

    final isArrived = difference.isNegative;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background with soft baby blue colors
          const _BabyArrivalBackground(),

          // Decorative Elements (Clouds/Stars)
          const _CloudDecoration(),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Baby Icon / Illustration Area
                    _buildBabyIllustration(context),

                    const SizedBox(height: 40),

                    // Title
                    Text(
                          s.babyArrivalTitle,
                          style: GoogleFonts.notoSerif(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 8),

                    Text(
                      s.babyArrivalSubtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 800.ms),

                    const SizedBox(height: 48),

                    if (!isArrived) ...[
                      _buildCountdownGrid(context, difference, s),
                    ] else ...[
                      _buildArrivalMessage(context, s),
                    ],

                    const SizedBox(height: 60),

                    // Specific Baby Name Badge
                    _buildNameBadge(context, AppConstants.babyName),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBabyIllustration(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.child_care_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.1, 1.1),
          duration: 2500.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .shake(hz: 2);
  }

  Widget _buildCountdownGrid(BuildContext context, Duration diff, S s) {
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CountdownItem(value: days.toString(), label: s.days),
                _CountdownItem(value: hours.toString(), label: s.hours),
                _CountdownItem(value: minutes.toString(), label: s.minutes),
                _CountdownItem(value: seconds.toString(), label: s.seconds),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              s.timeUntilArrival,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(delay: 400.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildArrivalMessage(BuildContext context, S s) {
    return Column(
      children: [
        Icon(
          Icons.celebration_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        Text(
          "Welcome Moaz!", // Fallback if no specific localized arrival string yet
          style: GoogleFonts.notoSerif(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNameBadge(BuildContext context, String name) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.star_rounded,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5, end: 0);
  }
}

class _CountdownItem extends StatelessWidget {
  final String value;
  final String label;

  const _CountdownItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 70,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              value.padLeft(2, '0'),
              style: GoogleFonts.manrope(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _BabyArrivalBackground extends StatelessWidget {
  const _BabyArrivalBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLight
                ? [
                    const Color(0xFFE3F2FD), // Very light blue
                    const Color(0xFFF3E5F5), // Light lavender
                    theme.colorScheme.surface,
                  ]
                : [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    const Color(
                      0xFF1A237E,
                    ).withValues(alpha: 0.1), // Deep blue tint
                  ],
          ),
        ),
      ),
    );
  }
}

class _CloudDecoration extends StatelessWidget {
  const _CloudDecoration();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          _buildElement(
            context,
            Icons.cloud_rounded,
            top: 100,
            left: 20,
            size: 120,
            opacity: 0.1,
            duration: 8.seconds,
          ),
          _buildElement(
            context,
            Icons.cloud_rounded,
            top: 400,
            right: -20,
            size: 180,
            opacity: 0.08,
            duration: 12.seconds,
          ),
          _buildElement(
            context,
            Icons.star_rounded,
            bottom: 100,
            left: 50,
            size: 40,
            opacity: 0.15,
            duration: 4.seconds,
          ),
          _buildElement(
            context,
            Icons.star_rounded,
            top: 200,
            right: 80,
            size: 30,
            opacity: 0.1,
            duration: 6.seconds,
          ),
        ],
      ),
    );
  }

  Widget _buildElement(
    BuildContext context,
    IconData icon, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double opacity,
    required Duration duration,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child:
          Icon(
                icon,
                size: size,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: opacity),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -20,
                end: 20,
                duration: duration,
                curve: Curves.easeInOut,
              ),
    );
  }
}
