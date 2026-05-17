// lib/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generated/l10n.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';
import '../providers/app_providers.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final s = S.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(s.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: settingsAsync.when(
        data: (settings) => _SettingsBody(settings: settings),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        error: (e, _) => Center(child: Text('${s.errorLoadingMemories}: $e')),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  final AppSettingsEntity settings;

  const _SettingsBody({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);
    final s = S.of(context);
    final currentLocale = ref.watch(localeProvider);

    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: [
        // ─── اللغة ────────────────────────────────────────────────────────
        _SectionCard(
          title: '🌐 ${s.language}',
          delay: 0,
          children: [
            ListTile(
              title: Text(s.changeLanguage, style: GoogleFonts.manrope()),
              subtitle: Text(
                currentLocale.languageCode == 'ar' ? s.arabic : s.english,
                style: GoogleFonts.manrope(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChoiceChip(
                    label: const Text('AR'),
                    selected: currentLocale.languageCode == 'ar',
                    onSelected: (val) {
                      if (val) {
                        ref.read(settingsProvider.notifier).setLanguage('ar');
                      }
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: currentLocale.languageCode == 'ar'
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('EN'),
                    selected: currentLocale.languageCode == 'en',
                    onSelected: (val) {
                      if (val) {
                        ref.read(settingsProvider.notifier).setLanguage('en');
                      }
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: currentLocale.languageCode == 'en'
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── الصوت والموسيقى ──────────────────────────────────────────────
        _SectionCard(
          title: '🎵 ${s.audioAndMusic}',
          delay: 100,
          children: [
            SwitchListTile(
              title: Text(s.playMusic, style: GoogleFonts.manrope()),
              subtitle: Text(
                s.romanticBackgroundMusic,
                style: GoogleFonts.manrope(fontSize: 12),
              ),
              value: settings.musicEnabled,
              thumbColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.primary,
              ),
              onChanged: (_) => notifier.toggleMusic(),
            ),
            if (settings.musicEnabled) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.volume_down,
                      color: Theme.of(context).colorScheme.outline,
                      size: 18,
                    ),
                    Expanded(
                      child: Slider(
                        value: settings.musicVolume,
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        onChanged: (v) => notifier.setMusicVolume(v),
                      ),
                    ),
                    Icon(
                      Icons.volume_up,
                      color: Theme.of(context).colorScheme.outline,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // ─── الإشعارات ────────────────────────────────────────────────────
        _SectionCard(
          title: '🔔 ${s.notifications}',
          delay: 200,
          children: [
            SwitchListTile(
              title: Text(
                s.memoriesNotifications,
                style: GoogleFonts.manrope(),
              ),
              subtitle: Text(
                s.remindImportantEvents,
                style: GoogleFonts.manrope(fontSize: 12),
              ),
              value: settings.notificationsEnabled,
              thumbColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.primary,
              ),
              onChanged: (_) => notifier.toggleNotifications(),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── العرض والتحريك ───────────────────────────────────────────────
        _SectionCard(
          title: '✨ ${s.displayAndAnimations}',
          delay: 300,
          children: [
            SwitchListTile(
              title: Text(s.animationsAndMotion, style: GoogleFonts.manrope()),
              subtitle: Text(
                s.enableVisualEffects,
                style: GoogleFonts.manrope(fontSize: 12),
              ),
              value: settings.animationsEnabled,
              thumbColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.primary,
              ),
              onChanged: (_) => notifier.toggleAnimations(),
            ),
            ListTile(
              title: Text(s.appearanceMode, style: GoogleFonts.manrope()),
              subtitle: Text(
                settings.themeMode == AppThemeMode.dark ? s.dark : s.light,
                style: GoogleFonts.manrope(fontSize: 12),
              ),
              trailing: Switch(
                value: settings.themeMode == AppThemeMode.dark,
                thumbColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.primary,
                ),
                onChanged: (isDark) => notifier.setThemeMode(
                  isDark ? AppThemeMode.dark : AppThemeMode.light,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── الأمان ───────────────────────────────────────────────────────
        _SectionCard(
          title: '🔒 ${s.securityAndPrivacy}',
          delay: 400,
          children: [
            SwitchListTile(
              title: Text(s.lockWithPin, style: GoogleFonts.manrope()),
              subtitle: Text(
                settings.pinEnabled ? s.enabledTapToEdit : s.disabled,
                style: GoogleFonts.manrope(fontSize: 12),
              ),
              value: settings.pinEnabled,
              thumbColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.primary,
              ),
              onChanged: (val) async {
                if (val) {
                  final pinSet = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                  );
                  if (pinSet == true) {
                    notifier.saveSettings(settings.copyWith(pinEnabled: true));
                  }
                } else {
                  notifier.saveSettings(
                    settings.copyWith(pinEnabled: false, pinHash: null),
                  );
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── إدارة البيانات ───────────────────────────────────────────────
        _SectionCard(
          title: '💾 ${s.dataManagement}',
          delay: 500,
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
              ),
              title: Text(
                s.deleteAllData,
                style: GoogleFonts.manrope(color: Colors.redAccent),
              ),
              subtitle: Text(
                s.resetAppCompletely,
                style: GoogleFonts.manrope(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmReset(context, ref, s),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── معلومات التطبيق ──────────────────────────────────────────────
        _SectionCard(
          title: 'ℹ️ ${s.appInfo}',
          delay: 600,
          children: [
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(s.version, style: GoogleFonts.manrope()),
              trailing: Text(
                AppConstants.appVersion,
                style: GoogleFonts.manrope(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.favorite,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(s.aboutApp, style: GoogleFonts.manrope()),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () => _showAbout(context, s),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ─── Footer رومانسي ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              const Text('💕', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(
                s.madeWithLoveFor(AppConstants.coupleName),
                style: GoogleFonts.notoSerif(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 600.ms).scale(),

        const SizedBox(height: 40),
      ],
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref, S s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              s.confirmReset,
              style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(s.areYouSureDeleteAll, style: GoogleFonts.manrope()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(settingsProvider.notifier).reset();
              await ref.read(timelineProvider.notifier).deleteAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(s.dataCleared),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(s.delete),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context, S s) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: const Text('💕', style: TextStyle(fontSize: 28)),
      ),
      children: [
        Text(
          s.appDescription(AppConstants.coupleName),
          style: GoogleFonts.manrope(),
        ),
        const SizedBox(height: 8),
        Text(s.builtWithFlutter, style: GoogleFonts.manrope()),
      ],
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final int delay;

  const _SectionCard({
    required this.title,
    required this.children,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  style: GoogleFonts.notoSerif(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              ...children,
              const SizedBox(height: 8),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: delay.ms, duration: 400.ms)
        .slideX(begin: -0.05, end: 0);
  }
}
