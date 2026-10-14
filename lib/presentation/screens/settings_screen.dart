// lib/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generated/l10n.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';
import '../providers/app_providers.dart';
import '../providers/media_provider.dart';
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
    final isFirestoreConnected = ref.watch(firestoreInstanceProvider) != null;
    final cloudinary = ref.watch(cloudinaryServiceProvider);
    final oneSignal = ref.watch(oneSignalServiceProvider);
    final myRole = ref.watch(myPartnerRoleProvider);

    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: [
        // ─── هوية الشريك على هذا الهاتف (محمد / سارة) ─────────────────────
        _SectionCard(
          title: '💑 هوية الشريك على هذا الهاتف',
          delay: 0,
          children: [
            ListTile(
              leading: Text(
                myRole == 'p1' ? '🤴' : '👸',
                style: const TextStyle(fontSize: 26),
              ),
              title: Text(
                'صاحب هذا الهاتف: ${myRole == "p1" ? AppConstants.partner1Name : AppConstants.partner2Name}',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'يُستخدم لتحديد حالة الاتصال أونلاين وإرسال إشعارات OneSignal للطرف الآخر',
                style: GoogleFonts.cairo(fontSize: 11.5),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChoiceChip(
                    label: Text(
                      '🤴 ${AppConstants.partner1Name}',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                    ),
                    selected: myRole == 'p1',
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: myRole == 'p1'
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    onSelected: (v) {
                      if (v) {
                        ref.read(myPartnerRoleProvider.notifier).setRole('p1');
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(
                      '👸 ${AppConstants.partner2Name}',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                    ),
                    selected: myRole == 'p2',
                    selectedColor: Theme.of(context).colorScheme.tertiary,
                    labelStyle: TextStyle(
                      color: myRole == 'p2'
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    onSelected: (v) {
                      if (v) {
                        ref.read(myPartnerRoleProvider.notifier).setRole('p2');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── السحابة والتخزين وإشعارات OneSignal ─────────────────────────
        _SectionCard(
          title: '☁️ المزامنة أونلاين وإشعارات OneSignal',
          delay: 50,
          children: [
            ListTile(
              leading: Icon(
                isFirestoreConnected
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                color: isFirestoreConnected
                    ? const Color(0xFF10B981)
                    : Theme.of(context).colorScheme.outline,
              ),
              title: Text(
                'Cloud Firestore (مزامنة فورية ثنائية الاتجاه)',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                isFirestoreConnected
                    ? 'متصل أونلاين 🟢 (الأحداث، الذكريات، الرسائل، وسهرة الأزواج)'
                    : 'يعمل في وضع الكاش المحلي (أضف google-services.json لتفعيل السيرفر)',
                style: GoogleFonts.cairo(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: 'مزامنة كافة البيانات السحابية الآن',
                icon: Icon(
                  Icons.sync_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => _syncAllOnlineNow(context, ref),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.notifications_active_rounded,
                color: oneSignal.isFullyConfigured
                    ? const Color(0xFF10B981)
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'OneSignal Push Notifications',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                oneSignal.isFullyConfigured
                    ? 'مفعّل 🟢 (App ID: ${oneSignal.appId.substring(0, oneSignal.appId.length.clamp(0, 8))}...)'
                    : 'اضغط لإدخال OneSignal App ID و REST API Key لإرسال إشعارات فورية للهاتف الآخر',
                style: GoogleFonts.cairo(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'إرسال إشعار تجريبي للشريك الآن 🔔',
                    icon: const Icon(Icons.send_rounded, size: 19),
                    onPressed: () => _sendTestNotification(context, ref),
                  ),
                  const Icon(Icons.edit_outlined, size: 18),
                ],
              ),
              onTap: () => _showOneSignalDialog(context, ref, s),
            ),
            ListTile(
              leading: Icon(
                Icons.cloud_upload_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Cloudinary Storage (صور + فيديو)',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                cloudinary.isConfigured
                    ? 'Cloud: ${cloudinary.cloudName} (${cloudinary.uploadPreset})'
                    : 'اضغط لإعداد Cloud Name و Upload Preset لرفع الصور والفيديوهات مجاناً',
                style: GoogleFonts.cairo(fontSize: 12),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _showCloudinaryDialog(context, ref, s),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── اللغة ────────────────────────────────────────────────────────
        _SectionCard(
          title: '🌐 ${s.language}',
          delay: 80,
          children: [
            ListTile(
              title: Text(s.changeLanguage, style: GoogleFonts.cairo()),
              subtitle: Text(
                currentLocale.languageCode == 'ar' ? s.arabic : s.english,
                style: GoogleFonts.cairo(fontSize: 12),
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
          title: s.audioAndMusic,
          delay: 100,
          children: [
            SwitchListTile(
              title: Text(s.playMusic, style: GoogleFonts.cairo()),
              subtitle: Text(
                s.romanticBackgroundMusic,
                style: GoogleFonts.cairo(fontSize: 12),
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

        // ─── الإشعارات والتذكيرات ─────────────────────────────────────────
        _SectionCard(
          title: s.notifications,
          delay: 200,
          children: [
            SwitchListTile(
              title: Text(
                s.memoriesNotifications,
                style: GoogleFonts.cairo(),
              ),
              subtitle: Text(
                s.remindImportantEvents,
                style: GoogleFonts.cairo(fontSize: 12),
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

        // ─── العرض والثيم (Light / Velvet Night Dark) ──────────────────────
        _SectionCard(
          title: s.displayAndAnimations,
          delay: 300,
          children: [
            SwitchListTile(
              title: Text(s.animationsAndMotion, style: GoogleFonts.cairo()),
              subtitle: Text(
                s.enableVisualEffects,
                style: GoogleFonts.cairo(fontSize: 12),
              ),
              value: settings.animationsEnabled,
              thumbColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.primary,
              ),
              onChanged: (_) => notifier.toggleAnimations(),
            ),
            ListTile(
              title: Text(s.appearanceMode, style: GoogleFonts.cairo()),
              subtitle: Text(
                settings.themeMode == AppThemeMode.dark
                    ? '🕯️ وضع السهرة الليلي الدافئ (${s.dark})'
                    : '☀️ وضع النهار الوردي المشرق (${s.light})',
                style: GoogleFonts.cairo(fontSize: 12),
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
          title: s.securityAndPrivacy,
          delay: 400,
          children: [
            SwitchListTile(
              title: Text(s.lockWithPin, style: GoogleFonts.cairo()),
              subtitle: GestureDetector(
                onTap: settings.pinEnabled
                    ? () {
                        Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PinSetupScreen(),
                          ),
                        );
                      }
                    : null,
                child: Text(
                  settings.pinEnabled ? s.enabledTapToEdit : s.disabled,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: settings.pinEnabled
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
              value: settings.pinEnabled,
              thumbColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.primary,
              ),
              onChanged: (val) async {
                if (val) {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                  );
                } else {
                  notifier.saveSettings(
                    settings.copyWith(
                      pinEnabled: false,
                      pinHash: null,
                      biometricEnabled: false,
                    ),
                  );
                }
              },
            ),
            if (settings.pinEnabled)
              SwitchListTile(
                title: Text(s.biometricUnlock, style: GoogleFonts.cairo()),
                subtitle: Text(
                  s.biometricSubtitle,
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                value: settings.biometricEnabled,
                thumbColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.primary,
                ),
                onChanged: (_) => notifier.toggleBiometric(),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── إدارة البيانات ───────────────────────────────────────────────
        _SectionCard(
          title: s.dataManagement,
          delay: 500,
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
              ),
              title: Text(
                s.deleteAllData,
                style: GoogleFonts.cairo(color: Colors.redAccent),
              ),
              subtitle: Text(
                s.resetAppCompletely,
                style: GoogleFonts.cairo(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmReset(context, ref, s),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── معلومات التطبيق ──────────────────────────────────────────────
        _SectionCard(
          title: s.appInfo,
          delay: 600,
          children: [
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(s.version, style: GoogleFonts.cairo()),
              trailing: Text(
                AppConstants.appVersion,
                style: GoogleFonts.cairo(
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
              title: Text(s.aboutApp, style: GoogleFonts.cairo()),
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
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
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
                style: GoogleFonts.cairo(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
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

  Future<void> _syncAllOnlineNow(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 جاري مزامنة الأحداث والذكريات مع السحابة...'),
        duration: Duration(seconds: 1),
      ),
    );
    await ref.read(timelineRepositoryProvider).getAllEvents();
    await ref.read(mediaRepositoryProvider).getAllMedia();
    await ref
        .read(oneSignalServiceProvider)
        .updateOnlinePresence(isOnline: true);
    ref.invalidate(timelineProvider);
    ref.invalidate(mediaProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✅ تمت مزامنة كافة البيانات أونلاين بنجاح مع Cloud Firestore!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _sendTestNotification(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final oneSignal = ref.read(oneSignalServiceProvider);
    final ok = await oneSignal.sendNotificationToPartner(
      title: 'إشعار حب من ${oneSignal.myName} 💖',
      message: 'أحبكِ يا ${oneSignal.partnerName}! تم تفعيل الإشعارات الفورية بين هاتفينا 🔔✨',
      category: 'test',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '🔔 تم إرسال الإشعار الفوري إلى هاتف ${oneSignal.partnerName} بنجاح!'
                : '⚠️ تعذر إرسال الإشعار، تحقق من الاتصال أو مفاتيح OneSignal',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  void _showOneSignalDialog(BuildContext context, WidgetRef ref, S s) {
    final oneSignal = ref.read(oneSignalServiceProvider);
    final appIdCtrl = TextEditingController(text: oneSignal.appId);
    final apiKeyCtrl = TextEditingController(text: oneSignal.restApiKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          '🔔 إعداد إشعارات OneSignal',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل الـ App ID والـ REST API Key من لوحة تحكم OneSignal لإرسال إشعارات Push فورية لهاتف شريكك حتى عندما يكون التطبيق مغلقاً:',
              style: GoogleFonts.cairo(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: appIdCtrl,
              decoration: const InputDecoration(
                labelText: 'OneSignal App ID',
                hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                prefixIcon: Icon(Icons.notifications_active_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: apiKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'OneSignal REST API Key',
                hintText: 'os_v2_app_...',
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              await oneSignal.saveConfig(
                appId: appIdCtrl.text,
                restApiKey: apiKeyCtrl.text,
              );
              ref.invalidate(oneSignalServiceProvider);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      '✅ تم حفظ وتفعيل إشعارات OneSignal بنجاح!',
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
  }

  void _showCloudinaryDialog(BuildContext context, WidgetRef ref, S s) {
    final cloudinary = ref.read(cloudinaryServiceProvider);
    final cloudNameCtrl = TextEditingController(text: cloudinary.cloudName);
    final presetCtrl = TextEditingController(text: cloudinary.uploadPreset);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'إعداد Cloudinary',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cloudNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Cloud Name',
                hintText: 'مثال: dxyz12345',
                prefixIcon: Icon(Icons.cloud_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: presetCtrl,
              decoration: const InputDecoration(
                labelText: 'Unsigned Upload Preset',
                hintText: 'our_love_story_unsigned',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              await cloudinary.saveConfig(
                cloudName: cloudNameCtrl.text,
                uploadPreset: presetCtrl.text,
              );
              ref.invalidate(cloudinaryServiceProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.save),
          ),
        ],
      ),
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
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(s.areYouSureDeleteAll, style: GoogleFonts.cairo()),
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
              await ref.read(mediaProvider.notifier).deleteAll();
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
          style: GoogleFonts.cairo(),
        ),
        const SizedBox(height: 8),
        Text(s.builtWithFlutter, style: GoogleFonts.cairo()),
      ],
    );
  }
}

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
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
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
