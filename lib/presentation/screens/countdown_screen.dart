// lib/presentation/screens/countdown_screen.dart
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/glass_container.dart';
import '../providers/app_providers.dart';

// Provider منفصل يتحدث كل ثانية
final _tickProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

class CountdownScreen extends ConsumerStatefulWidget {
  const CountdownScreen({super.key});

  @override
  ConsumerState<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends ConsumerState<CountdownScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // نستمع للـ tick لكن نحسب الوقت هنا
    ref.watch(_tickProvider);

    final isPast = ref.watch(isWeddingPastProvider);
    final weddingDate = AppConstants.weddingDate;

    if (!isPast) {
      final now = DateTime.now();
      if (now.day == weddingDate.day &&
          now.month == weddingDate.month &&
          now.year == weddingDate.year) {
        _confettiController.play();
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.3, -0.4),
                    radius: 1.2,
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
                Theme.of(context).colorScheme.onSurface,
              ],
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.pagePadding,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 60),
                  isPast ? _buildPastState(weddingDate) : _buildCountdown(),
                  const SizedBox(height: 60),
                  _buildVenueInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        RepaintBoundary(
          child:
              Icon(
                    Icons.favorite_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 40,
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    duration: 1.seconds,
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                  ),
        ),
        const SizedBox(height: 16),
        Text(
          AppConstants.coupleName,
          style: GoogleFonts.notoSerif(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 1,
          ),
        ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          DateTime.now().isAfter(AppConstants.weddingDate)
              ? 'قصة حبنا المستمرة'
              : 'نعد الأيام لنكون معاً',
          style: GoogleFonts.manrope(
            fontSize: 16,
            color: Theme.of(context).colorScheme.outline,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildCountdown() {
    final now = DateTime.now();
    final remaining = AppConstants.weddingDate.difference(now);
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TimeUnit(value: days, label: 'يوم'),
        _Separator(),
        _TimeUnit(value: hours, label: 'ساعة'),
        _Separator(),
        _TimeUnit(value: minutes, label: 'دقيقة'),
        _Separator(),
        _TimeUnit(value: seconds, label: 'ثانية'),
      ],
    ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildPastState(DateTime date) {
    final daysSince = DateTime.now().difference(date).inDays;
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(
            'منذ أن بدأت رحلتنا الحقيقية',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$daysSince يوم من الحب',
            style: GoogleFonts.dancingScript(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${date.day}/${date.month}/${date.year}',
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildVenueInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            AppConstants.weddingVenue,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.access_time_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            AppConstants.weddingTime,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1.seconds);
  }
}

// ─── Time Unit Widget ────────────────────────────────────────────────────────

class _TimeUnit extends StatelessWidget {
  final int value;
  final String label;

  const _TimeUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 80,
          child: GlassContainer(
            child: Center(
              child: Text(
                value.toString().padLeft(2, '0'),
                style: GoogleFonts.notoSerif(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25, left: 4, right: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 24,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
