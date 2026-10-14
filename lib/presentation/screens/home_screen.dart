// lib/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generated/l10n.dart';
import '../providers/app_providers.dart';
import '../../core/widgets/glass_container.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/timeline_event_entity.dart';
import '../../theme/app_theme.dart';
import 'baby_countdown_screen.dart';
import 'countdown_screen.dart';
import 'couples_night_screen.dart';
import 'memories_album_screen.dart';
import 'settings_screen.dart';
import 'surprise_screen.dart';
import 'timeline_screen.dart';
import 'video_studio_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final animationsEnabled = ref.watch(isAnimationsEnabledProvider);
    final nextMilestone = ref.watch(nextMilestoneReminderProvider);

    return Scaffold(
      body: Stack(
        children: [
          const _Background(),

          if (animationsEnabled) const _FloatingBackground(),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(context, ref, s),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildOnlinePresenceBar(context, ref),
                        const SizedBox(height: 14),
                        _buildHeroCard(context, ref, s, animationsEnabled),
                        if (nextMilestone != null) ...[
                          const SizedBox(height: 16),
                          _buildReminderBanner(context, nextMilestone, s),
                        ],
                        const SizedBox(height: 16),
                        _buildCouplesNightBanner(context),
                        const SizedBox(height: 24),
                        _NavigationGrid(s: s),
                        const SizedBox(height: 40),
                        _buildFooter(context, s),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// شريط الحالة الأونلاين + تبديل هوية الهاتف (محمد / سارة) + إرسال نبض فوري عبر OneSignal
  Widget _buildOnlinePresenceBar(BuildContext context, WidgetRef ref) {
    final myRole = ref.watch(myPartnerRoleProvider);
    final coupleDocAsync = ref.watch(coupleOnlineDocStreamProvider);
    final isFirestoreConnected = ref.watch(firestoreInstanceProvider) != null;

    final data = coupleDocAsync.value;
    final partnerRole = myRole == 'p1' ? 'p2' : 'p1';
    final partnerName = myRole == 'p1' ? 'سارة' : 'محمد';
    final myName = myRole == 'p1' ? 'محمد' : 'سارة';
    final partnerOnline = data != null && data['${partnerRole}Online'] == true;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 18,
      child: Row(
        children: [
          // زر تبديل هوية صاحب هذا الهاتف
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              final nextRole = myRole == 'p1' ? 'p2' : 'p1';
              ref.read(myPartnerRoleProvider.notifier).setRole(nextRole);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    myRole == 'p1' ? '🤴' : '👸',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'جهاز $myName',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // حالة اتصال الشريك أونلاين
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !isFirestoreConnected
                  ? Theme.of(context).colorScheme.outline
                  : (partnerOnline
                        ? AppTheme.successColor(context)
                        : AppTheme.warningColor(context)),
              boxShadow: partnerOnline
                  ? [
                      BoxShadow(
                        color: AppTheme.successColor(context),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              !isFirestoreConnected
                  ? 'وضع الكاش المحلي'
                  : (partnerOnline
                        ? '$partnerName متصلة الآن أونلاين 🟢'
                        : 'متصل بالسحابة • $partnerName بالخارج'),
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // زر إرسال نبض شوق فوري عبر OneSignal وFirestore
          InkWell(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final oneSignal = ref.read(oneSignalServiceProvider);
              await oneSignal.sendNotificationToPartner(
                title: 'نبضة شوق من $myName 💖',
                message: '$myName يفكر فيكِ الآن ويرسل لكِ قبلة دافئة 💋✨',
                category: 'love_pulse',
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🔔 تم إرسال نبضة شوق وإشعار فوري إلى $partnerName 💕',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🔔 نبض شوق',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouplesNightBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CouplesNightScreen()),
      ),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('💞', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ثنائي المحبة 2.0 • سهرة الأزواج',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '5 ألعاب تفاعلية، ربط هاتفين، وعجلة قسائم الدلال 🎡🎟️',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_fill_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref, S s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.transparent(context),
      elevation: 0,
      leading: IconButton(
        tooltip: isDark ? 'الوضع النهاري ☀️' : 'وضع السهرة الليلي 🕯️',
        onPressed: () {
          ref
              .read(settingsProvider.notifier)
              .setThemeMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
        },
        icon: Text(
          isDark ? '☀️' : '🕯️',
          style: const TextStyle(fontSize: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          s.journeyTogether,
          style: GoogleFonts.cairo(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: Icon(
              Icons.settings_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    WidgetRef ref,
    S s,
    bool animationsEnabled,
  ) {
    final daysTogether = ref.watch(daysTogetherProvider);
    final heartIcon = Icon(
      Icons.favorite_rounded,
      color: Theme.of(context).colorScheme.primary,
      size: 48,
    );

    return GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          animationsEnabled
              ? heartIcon
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.2, 1.2),
                      duration: 2000.ms,
                      curve: Curves.easeInOut,
                    )
              : heartIcon,
          const SizedBox(height: 18),
          Text(
            s.daysTogether(daysTogether),
            style: GoogleFonts.cairo(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.daysOfLove,
            style: GoogleFonts.cairo(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 24),
          _buildNamesBar(context, s),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildReminderBanner(
    BuildContext context,
    TimelineEventEntity milestone,
    S s,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TimelineScreen()),
      ),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(milestone.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.upcomingAnniversary,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${milestone.title} (${milestone.date.day}/${milestone.date.month})',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.notifications_active_outlined,
              size: 18,
              color: theme.colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamesBar(BuildContext context, S s) {
    final names = s.coupleName.split(' ❤️ ');
    final name1 = names.isNotEmpty ? names.first : 'محمد';
    final name2 = names.length > 1 ? names.last : 'سارة';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NameAnchor(name: name1),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('❤️', style: TextStyle(fontSize: 18)),
        ),
        _NameAnchor(name: name2),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, S s) {
    return Column(
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          color: Theme.of(context).colorScheme.secondary,
          size: 20,
        ),
        const SizedBox(height: 12),
        Text(
          s.footerMessage,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate().fadeIn(delay: 1000.ms);
  }
}

class _NavigationGrid extends StatelessWidget {
  final S s;
  const _NavigationGrid({required this.s});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.88,
      children: [
        _NavCard(
          title: 'ثنائي المحبة 2.0',
          subtitle: 'سهرة الأزواج والألعاب 🎲',
          icon: Icons.sports_esports_rounded,
          color: Theme.of(context).colorScheme.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CouplesNightScreen()),
          ),
        ),
        _NavCard(
          title: 'استوديو الفيديو',
          subtitle: 'مونتاج Keyframes 🎬',
          icon: Icons.movie_filter_rounded,
          color: Theme.of(context).colorScheme.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VideoStudioScreen()),
          ),
        ),
        _NavCard(
          title: s.timeline,
          subtitle: s.timelineSubtitle,
          icon: Icons.auto_stories_rounded,
          color: Theme.of(context).colorScheme.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimelineScreen()),
          ),
        ),
        _NavCard(
          title: s.memories,
          subtitle: s.memoriesSubtitle,
          icon: Icons.favorite_border_rounded,
          color: Theme.of(context).colorScheme.tertiary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MemoriesAlbumScreen()),
          ),
        ),
        _NavCard(
          title: s.surprise,
          subtitle: s.surpriseSubtitle,
          icon: Icons.card_giftcard_rounded,
          color: Theme.of(context).colorScheme.secondary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SurpriseScreen()),
          ),
        ),
        _NavCard(
          title: s.babyArrivalTitle,
          subtitle: s.babyArrivalSubtitle,
          icon: Icons.child_care_rounded,
          color: Theme.of(context).colorScheme.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BabyCountdownScreen()),
          ),
        ),
        _NavCard(
          title: s.countdown,
          subtitle: s.countdownSubtitle,
          icon: Icons.timer_outlined,
          color: Theme.of(context).colorScheme.secondary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CountdownScreen()),
          ),
        ),
        _NavCard(
          title: 'عجلة الدلال',
          subtitle: 'قسائم ومكافآت 🎡🎟️',
          icon: Icons.redeem_rounded,
          color: Theme.of(context).colorScheme.tertiary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CouplesNightScreen(initialTab: 'wheel'),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }
}

class _NavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NameAnchor extends StatelessWidget {
  final String name;
  const _NameAnchor({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        name,
        style: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.tertiary,
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.pageGradientColors(context),
          ),
        ),
      ),
    );
  }
}

class _FloatingBackground extends StatelessWidget {
  const _FloatingBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: List.generate(5, (i) {
          return Positioned(
                left: (i * 100.0) % 400,
                top: (i * 150.0) % 800,
                child: Icon(
                  Icons.favorite,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.04),
                  size: 100 + (i * 20.0),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: 0,
                end: 30,
                duration: (3000 + (i * 500)).ms,
                curve: Curves.easeInOut,
              );
        }),
      ),
    );
  }
}
