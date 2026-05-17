// lib/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generated/l10n.dart';
import '../providers/app_providers.dart';
import '../../core/widgets/glass_container.dart';
import 'baby_countdown_screen.dart';
import 'countdown_screen.dart';
import 'memories_album_screen.dart';
import 'settings_screen.dart';
import 'surprise_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          const _Background(),

          // Floating Hearts Background
          const _FloatingBackground(),

          // Main Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(context, s),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildHeroCard(context, ref, s),
                        const SizedBox(height: 32),
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

  Widget _buildAppBar(BuildContext context, S s) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          s.journeyTogether,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: Icon(
              Icons.settings_outlined,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context, WidgetRef ref, S s) {
    final daysTogether = ref.watch(daysTogetherProvider);

    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
                Icons.favorite_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 48,
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.2, 1.2),
                duration: 2000.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 24),
          Text(
            s.daysTogether(daysTogether),
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(fontSize: 36),
          ),
          const SizedBox(height: 8),
          Text(
            s.daysOfLove,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              letterSpacing: 2,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          _buildNamesBar(context, s),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildNamesBar(BuildContext context, S s) {
    final names = s.coupleName.split(' ❤️ ');
    final name1 = names.isNotEmpty ? names.first : 'Mohammad';
    final name2 = names.length > 1 ? names.last : 'Sara';

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
        const SizedBox(height: 16),
        Text(
          s.footerMessage,
          style: GoogleFonts.dancingScript(
            fontSize: 20,
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
      childAspectRatio: 0.85,
      children: [
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
          title: s.countdown,
          subtitle: s.countdownSubtitle,
          icon: Icons.timer_outlined,
          color: Theme.of(context).colorScheme.secondary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CountdownScreen()),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.notoSerif(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w600,
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
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        name,
        style: GoogleFonts.notoSerif(
          fontSize: 16,
          fontWeight: FontWeight.bold,
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.light
                ? [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surface,
                  ]
                : [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    Theme.of(context).colorScheme.surface,
                  ],
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
                  ).colorScheme.primary.withValues(alpha: 0.03),
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
