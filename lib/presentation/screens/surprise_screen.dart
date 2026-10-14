// lib/presentation/screens/surprise_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/glass_container.dart';
import '../../generated/l10n.dart';
import '../providers/audio_provider.dart';
import '../providers/app_providers.dart';
import 'couples_night_screen.dart';

const _defaultMessages = [
  'حبيبتي سارة، أنتِ النور الذي يضيء أيامي.',
  'كل لحظة معكِ هي حكاية عشق لا تنتهي.',
  'أنتِ أجمل صدفة غيرت مجرى حياتي للأبد.',
  'أحبكِ اليوم، غداً، وإلى نهاية العمر.',
  'شكراً لأنكِ جعلتِ لقصتنا معنىً جميلاً.',
  'عيوني رأت الدنيا جميلة حين رأتكِ.',
  'أنتِ بيتي الذي أعود إليه كلما تعبت.',
];

class SurpriseScreen extends ConsumerStatefulWidget {
  const SurpriseScreen({super.key});

  @override
  ConsumerState<SurpriseScreen> createState() => _SurpriseScreenState();
}

class _SurpriseScreenState extends ConsumerState<SurpriseScreen>
    with SingleTickerProviderStateMixin {
  bool _isOpened = false;
  bool _showContent = false;
  String _currentMessage = _defaultMessages.first;
  late AnimationController _floatController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _surpriseSub;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _initRealtimeSurpriseSync();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(isMusicEnabledProvider)) {
        ref.read(audioControllerProvider).playSurpriseIntro();
      }
    });
  }

  /// مزامنة فورية حية (Live Stream) لرسائل المفاجآت عبر Cloud Firestore
  void _initRealtimeSurpriseSync() {
    final prefs = ref.read(sharedPreferencesProvider);
    final firestore = ref.read(firestoreInstanceProvider);

    final custom = List<String>.from(
      prefs.getStringList(AppConstants.keyCustomSurpriseMessages) ?? [],
    );
    final allInitial = [..._defaultMessages, ...custom];
    _currentMessage = allInitial[Random().nextInt(allInitial.length)];

    if (firestore != null) {
      // رفع أي رسائل مخصصة محلية إلى السحابة أولاً
      for (final msg in custom) {
        firestore
            .collection(AppConstants.firestoreSurpriseCollection)
            .doc(msg.hashCode.toString())
            .set({
              'text': msg,
              'author': AppConstants.partner1Name,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      // الاستماع الفوري لأي رسالة جديدة يضيفها الشريك من هاتفه الآخر
      _surpriseSub = firestore
          .collection(AppConstants.firestoreSurpriseCollection)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snap) async {
            final updatedCustom = List<String>.from(
              prefs.getStringList(AppConstants.keyCustomSurpriseMessages) ?? [],
            );
            final savedInHeart = List<String>.from(
              prefs.getStringList(AppConstants.keySavedSurpriseMessages) ?? [],
            );

            bool changed = false;
            String? newestMessage;

            for (final doc in snap.docs) {
              final data = doc.data();
              final text = (data['text'] as String?)?.trim() ?? '';
              if (text.isEmpty) continue;
              newestMessage ??= text;

              if (!updatedCustom.contains(text) &&
                  !_defaultMessages.contains(text)) {
                updatedCustom.add(text);
                changed = true;
              }
              if (data['isSavedInHeart'] == true &&
                  !savedInHeart.contains(text)) {
                savedInHeart.add(text);
                changed = true;
              }
            }

            if (changed) {
              await prefs.setStringList(
                AppConstants.keyCustomSurpriseMessages,
                updatedCustom,
              );
              await prefs.setStringList(
                AppConstants.keySavedSurpriseMessages,
                savedInHeart,
              );
              if (mounted && newestMessage != null) {
                setState(() {
                  _currentMessage = newestMessage!;
                });
              }
            }
          });
    }
  }

  @override
  void dispose() {
    _surpriseSub?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _handleOpen() async {
    if (_isOpened) return;
    setState(() => _isOpened = true);

    final musicEnabled = ref.read(isMusicEnabledProvider);
    if (musicEnabled) {
      ref.read(audioControllerProvider).playSurpriseReveal();
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _showContent = true);
  }

  Future<void> _saveCurrentInHeart(S s) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final firestore = ref.read(firestoreInstanceProvider);
    final saved = List<String>.from(
      prefs.getStringList(AppConstants.keySavedSurpriseMessages) ?? [],
    );
    if (!saved.contains(_currentMessage)) {
      saved.add(_currentMessage);
      await prefs.setStringList(AppConstants.keySavedSurpriseMessages, saved);
      if (firestore != null) {
        try {
          await firestore
              .collection(AppConstants.firestoreSurpriseCollection)
              .doc(_currentMessage.hashCode.toString())
              .set({
                'text': _currentMessage,
                'isSavedInHeart': true,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        } catch (_) {}
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.messageSavedInHeart),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  void _showAddMessageDialog(S s) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          s.addSecretMessage,
          style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: s.writeSecretMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              final prefs = ref.read(sharedPreferencesProvider);
              final firestore = ref.read(firestoreInstanceProvider);
              final custom = List<String>.from(
                prefs.getStringList(AppConstants.keyCustomSurpriseMessages) ??
                    [],
              );
              if (!custom.contains(text)) {
                custom.add(text);
                await prefs.setStringList(
                  AppConstants.keyCustomSurpriseMessages,
                  custom,
                );
              }

              if (firestore != null) {
                try {
                  await firestore
                      .collection(AppConstants.firestoreSurpriseCollection)
                      .doc(text.hashCode.toString())
                      .set({
                        'text': text,
                        'author': AppConstants.partner1Name,
                        'createdAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                } catch (_) {}
              }
              final oneSignal = ref.read(oneSignalServiceProvider);
              await oneSignal.sendNotificationToPartner(
                title: 'رسالة حب سرية جديدة 💌',
                message: 'كتب لكِ ${oneSignal.myName} رسالة سرية جديدة في صندوق المفاجآت ✨',
                category: 'surprise',
              );

              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                setState(() {
                  _currentMessage = text;
                });
              }
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
  }

  void _showSavedMessagesSheet(S s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final prefs = ref.read(sharedPreferencesProvider);
          final saved = List<String>.from(
            prefs.getStringList(AppConstants.keySavedSurpriseMessages) ?? [],
          );
          final theme = Theme.of(context);

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '❤️ ${s.savedMessages}',
                  style: GoogleFonts.notoSerif(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                if (saved.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        s.noSavedMessagesYet,
                        style: GoogleFonts.manrope(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: saved.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (_, i) => ListTile(
                        leading: Icon(
                          Icons.favorite_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          saved[i],
                          style: GoogleFonts.notoSerif(fontSize: 15),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () async {
                            final removedText = saved.removeAt(i);
                            await prefs.setStringList(
                              AppConstants.keySavedSurpriseMessages,
                              saved,
                            );
                            final firestore = ref.read(
                              firestoreInstanceProvider,
                            );
                            if (firestore != null) {
                              try {
                                await firestore
                                    .collection(
                                      AppConstants.firestoreSurpriseCollection,
                                    )
                                    .doc(removedText.hashCode.toString())
                                    .delete();
                              } catch (_) {}
                            }
                            setModalState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final animationsEnabled = ref.watch(isAnimationsEnabledProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'عجلة وقسائم الدلال 🎟️',
            icon: Icon(
              Icons.redeem_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CouplesNightScreen(initialTab: 'wheel'),
              ),
            ),
          ),
          IconButton(
            tooltip: s.savedMessages,
            icon: Icon(
              Icons.bookmarks_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => _showSavedMessagesSheet(s),
          ),
          IconButton(
            tooltip: s.addSecretMessage,
            icon: Icon(
              Icons.add_comment_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => _showAddMessageDialog(s),
          ),
        ],
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
          if (_isOpened && animationsEnabled) const _OpenParticle(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.pagePadding,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: _showContent
                      ? _LetterSection(
                          key: const ValueKey('letter'),
                          message: _currentMessage,
                          onSaveInHeart: () => _saveCurrentInHeart(s),
                          s: s,
                        )
                      : _EnvelopeSection(
                          key: const ValueKey('envelope'),
                          isOpened: _isOpened,
                          floatController: _floatController,
                          onTap: _handleOpen,
                          s: s,
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

class _EnvelopeSection extends StatelessWidget {
  final bool isOpened;
  final AnimationController floatController;
  final VoidCallback onTap;
  final S s;

  const _EnvelopeSection({
    super.key,
    required this.isOpened,
    required this.floatController,
    required this.onTap,
    required this.s,
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
              s.secretMessage,
              style: GoogleFonts.notoSerif(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 12),
            Text(
              s.tapToOpen,
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

class _LetterSection extends StatelessWidget {
  final String message;
  final VoidCallback onSaveInHeart;
  final S s;

  const _LetterSection({
    super.key,
    required this.message,
    required this.onSaveInHeart,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
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
                s.withLove(AppConstants.partner1Name),
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
          onPressed: onSaveInHeart,
          icon: const Icon(Icons.favorite_rounded, size: 18),
          label: Text(s.saveInHeart),
        ).animate().fadeIn(delay: 1000.ms).scale(),
      ],
    );
  }
}

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
