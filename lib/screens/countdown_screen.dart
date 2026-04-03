import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _pulseController;
  late ConfettiController _confettiController;
  AudioPlayer? _audioPlayer;

  // تاريخ الزفاف (يمكن تعديله حسب الحاجة)
  final DateTime weddingDate = DateTime(2025, 9, 17);

  Duration _timeRemaining = const Duration();
  bool _isWeddingDay = false;
  bool _isPastWedding = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 10),
    );
    _calculateTimeRemaining();
    _startTimer();
    _initAudio();
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _confettiController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _initAudio() {
    _audioPlayer = AudioPlayer();
  }

  void _calculateTimeRemaining() {
    final now = DateTime.now();
    final difference = weddingDate.difference(now);

    if (mounted) {
      setState(() {
        if (difference.isNegative) {
          _isPastWedding = true;
          _timeRemaining = Duration.zero;
        } else if (difference.inDays == 0 &&
            now.day == weddingDate.day &&
            now.month == weddingDate.month) {
          _isWeddingDay = true;
          _timeRemaining = difference;
          _confettiController.play();
        } else {
          _timeRemaining = difference;
        }
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTimeRemaining();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.darkText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Ethereal Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.3, -0.4),
                  radius: 1.2,
                  colors: [
                    AppColors.surfaceRose,
                    AppColors.pearlWhite,
                    AppColors.pearlWhite,
                  ],
                ),
              ),
            ),
          ),

          // Confetti Overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                AppColors.dustyRose,
                AppColors.champagneGold,
                Colors.white,
              ],
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 60),
                  _buildMainDisplay(),
                  const SizedBox(height: 60),
                  _buildFooter(),
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
        Icon(
              Icons.favorite_rounded,
              color: AppColors.dustyRose.withValues(alpha: 0.6),
              size: 40,
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              duration: 1.seconds,
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
            ),
        const SizedBox(height: 16),
        Text(
          'محمد ❤️ سارة',
          style: GoogleFonts.notoSerif(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            letterSpacing: 1,
          ),
        ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          _isPastWedding ? 'قصة حبنا المستمرة' : 'نعد الأيام لنكون معاً',
          style: GoogleFonts.manrope(
            fontSize: 16,
            color: AppColors.softTaupe,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildMainDisplay() {
    if (_isPastWedding) {
      return _buildStatusBox(
        'منذ أن بدأت رحلتنا الحقيقية',
        weddingDate,
        isPast: true,
      );
    }
    if (_isWeddingDay) {
      return _buildStatusBox('اليوم هو يوم السعد!', weddingDate);
    }

    final days = _timeRemaining.inDays;
    final hours = _timeRemaining.inHours % 24;
    final minutes = _timeRemaining.inMinutes % 60;
    final seconds = _timeRemaining.inSeconds % 60;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTimeUnit(days, 'يوم'),
            _buildSeparator(),
            _buildTimeUnit(hours, 'ساعة'),
            _buildSeparator(),
            _buildTimeUnit(minutes, 'دقيقة'),
            _buildSeparator(),
            _buildTimeUnit(seconds, 'ثانية'),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildTimeUnit(int value, String label) {
    return Column(
      children: [
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 70,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.softTaupe.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                value.toString().padLeft(2, '0'),
                style: GoogleFonts.notoSerif(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
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
            color: AppColors.softTaupe,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25, left: 4, right: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 24,
          color: AppColors.dustyRose.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBox(String title, DateTime date, {bool isPast = false}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.surfaceRose, width: 2),
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  color: AppColors.dustyRose,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRose.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: AppColors.dustyRose,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'قاعة اللؤلؤة الملكية',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.darkText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.access_time_rounded,
            color: AppColors.dustyRose,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '8:00 مساءً',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.darkText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1.seconds);
  }
}
