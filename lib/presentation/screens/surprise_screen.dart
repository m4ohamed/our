import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/glass_container.dart';
import '../providers/audio_provider.dart';
import '../providers/app_providers.dart';

const _messages = [
  'حبيبتي سارة، أنتِ النور الذي يضيء أيامي.',
  'كل لحظة معكِ هي حكاية عشق لا تنتهي.',
  'أنتِ أجمل صدفة غيرت مجرى حياتي للأبد.',
  'أحبكِ اليوم، غداً، وإلى نهاية العمر.',
  'شكراً لأنكِ جعلتِ لقصتنا معنىً جميلاً.',
  'عيوني رأت الدنيا جميلة حين رأتكِ.',
  'أنتِ بيتي الذي أعود إليه كلما تعبت.',
];

// Provider بسيط يحتفظ بالرسالة العشوائية
final _surpriseMessageProvider = Provider<String>((ref) {
  return _messages[Random().nextInt(_messages.length)];
});

class SurpriseScreen extends ConsumerStatefulWidget {
  const SurpriseScreen({super.key});

  @override
  ConsumerState<SurpriseScreen> createState() => _SurpriseScreenState();
}

class _SurpriseScreenState extends ConsumerState<SurpriseScreen>
    with SingleTickerProviderStateMixin {
  bool _isOpened = false;
  bool _showContent = false;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // تشغيل موسيقى المقدمة للمفاجأة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(isMusicEnabledProvider)) {
        ref.read(audioControllerProvider).playSurpriseIntro();
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _handleOpen() async {
    if (_isOpened) return;
    setState(() => _isOpened = true);

    // تشغيل صوت المفاجأة
    final musicEnabled = ref.read(isMusicEnabledProvider);
    if (musicEnabled) {
      ref.read(audioControllerProvider).playSurpriseReveal();
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _showContent = true);
  }

  @override
  Widget build(BuildContext context) {
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
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
          if (_isOpened) _OpenParticle(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.pagePadding,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: _showContent
                      ? _LetterSection(key: const ValueKey('letter'))
                      : _EnvelopeSection(
                          key: const ValueKey('envelope'),
                          isOpened: _isOpened,
                          floatController: _floatController,
                          onTap: _handleOpen,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Envelope ────────────────────────────────────────────────────────────────

class _EnvelopeSection extends StatelessWidget {
  final bool isOpened;
  final AnimationController floatController;
  final VoidCallback onTap;

  const _EnvelopeSection({
    super.key,
    required this.isOpened,
    required this.floatController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: floatController,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 10 * floatController.value),
          child: child,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: Icon(
                isOpened ? Icons.drafts_rounded : Icons.mail_rounded,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ).animate(target: isOpened ? 1 : 0).scale(duration: 600.ms),
            ),
            const SizedBox(height: 40),
            Text(
              'لديكِ رسالة سرية...',
              style: GoogleFonts.notoSerif(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 12),
            Text(
              'اضغطي للفتح',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}

// ─── Letter ───────────────────────────────────────────────────────────────────

class _LetterSection extends ConsumerWidget {
  const _LetterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(_surpriseMessageProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            children: [
              Icon(
                Icons.auto_stories_rounded,
                color: Theme.of(context).colorScheme.secondary,
                size: 32,
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.7,
                  fontStyle: FontStyle.italic,
                ),
              ).animate().fadeIn(duration: 1200.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 32),
              Text(
                'بكل الحب، ${AppConstants.partner1Name}',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
        const SizedBox(height: 48),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.favorite_rounded, size: 18),
          label: const Text('حفظ في قلبي'),
        ).animate().fadeIn(delay: 1500.ms).scale(),
      ],
    );
  }
}

// ─── Open Particle Effect ─────────────────────────────────────────────────────

class _OpenParticle extends StatelessWidget {
  const _OpenParticle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RepaintBoundary(
        child:
            Icon(
                  Icons.favorite_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                )
                .animate(onPlay: (c) => c.repeat())
                .custom(
                  duration: 4.seconds,
                  builder: (_, value, child) => Opacity(
                    opacity: (1 - value).clamp(0.0, 1.0),
                    child: Transform.scale(scale: value * 10, child: child),
                  ),
                ),
      ),
    );
  }
}
