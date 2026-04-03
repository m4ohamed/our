import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SurpriseScreen extends StatefulWidget {
  const SurpriseScreen({super.key});

  @override
  State<SurpriseScreen> createState() => _SurpriseScreenState();
}

class _SurpriseScreenState extends State<SurpriseScreen>
    with TickerProviderStateMixin {
  late AnimationController _envelopeController;
  late AnimationController _floatingController;
  AudioPlayer? _audioPlayer;

  bool _isOpened = false;
  bool _showContent = false;

  final List<String> _loveMessages = [
    'حبيبتي سارة، أنتِ النور الذي يضيء أيامي.',
    'كل لحظة معكِ هي حكاية عشق لا تنتهي.',
    'أنتِ أجمل صدفة غيرت مجرى حياتي للأبد.',
    'أحبكِ اليوم، غداً، وإلى نهاية العمر.',
    'شكراً لأنكِ جعلتِ لقصتنا معنىً جميلاً.',
  ];

  late String _currentMessage;

  @override
  void initState() {
    super.initState();
    _currentMessage = _loveMessages[Random().nextInt(_loveMessages.length)];
    _envelopeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _initAudio();
  }

  @override
  void dispose() {
    _envelopeController.dispose();
    _floatingController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _initAudio() {
    _audioPlayer = AudioPlayer();
  }

  void _handleOpen() async {
    if (_isOpened) return;

    setState(() {
      _isOpened = true;
    });

    await _envelopeController.forward();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showContent = true;
        });
      }
    });

    try {
      await _audioPlayer?.play(AssetSource('audio/romantic_surprise.mp3'));
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surfaceRose,
                    AppColors.pearlWhite,
                    AppColors.pearlWhite,
                  ],
                ),
              ),
            ),
          ),

          // Animated Particles
          if (_isOpened) _buildParticles(),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_showContent)
                      _buildEnvelopeSection()
                    else
                      _buildLetterSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvelopeSection() {
    return GestureDetector(
      onTap: _handleOpen,
      child: AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 10 * _floatingController.value),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Glow
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.dustyRose.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    // Envelope Icon
                    Icon(
                          _isOpened ? Icons.drafts_rounded : Icons.mail_rounded,
                          size: 120,
                          color: AppColors.dustyRose,
                        )
                        .animate(target: _isOpened ? 1 : 0)
                        .scale(duration: 600.ms)
                        .fadeOut(),

                    if (!_isOpened)
                      const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 30,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            duration: 800.ms,
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.2, 1.2),
                          ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  'لديكِ رسالة سرية...',
                  style: GoogleFonts.notoSerif(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 12),
                Text(
                  'اضغطي للفتح',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppColors.softTaupe,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLetterSection() {
    return Column(
      children: [
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.softTaupe.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.champagneGold,
                    size: 32,
                  ),
                  const SizedBox(height: 24),
                  Text(
                        _currentMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSerif(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 1200.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 32),
                  Text(
                    'بكل الحب، محمد',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dustyRose,
                      letterSpacing: 1.2,
                    ),
                  ).animate().fadeIn(delay: 800.ms),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        _buildActionButton(),
      ],
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.favorite_rounded, size: 18),
      label: const Text('حفظ في قلبي'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.dustyRose,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ).animate().fadeIn(delay: 1500.ms).scale();
  }

  Widget _buildParticles() {
    return Center(
      child: const Icon(Icons.favorite_rounded, color: AppColors.surfaceRose)
          .animate(onPlay: (c) => c.repeat())
          .custom(
            duration: 4.seconds,
            builder: (context, value, child) {
              return Opacity(
                opacity: (1 - value).clamp(0, 1),
                child: Transform.scale(scale: value * 10, child: child),
              );
            },
          ),
    );
  }
}
