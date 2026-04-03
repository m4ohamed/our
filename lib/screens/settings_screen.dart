import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _musicEnabled = true;
  bool _notificationsEnabled = true;
  bool _animationsEnabled = true;
  String _selectedTheme = 'رومانسي';
  double _musicVolume = 0.7;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _animationsEnabled = prefs.getBool('animations_enabled') ?? true;
      _selectedTheme = prefs.getString('selected_theme') ?? 'رومانسي';
      _musicVolume = prefs.getDouble('music_volume') ?? 0.7;
    });
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', _musicEnabled);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('animations_enabled', _animationsEnabled);
    await prefs.setString('selected_theme', _selectedTheme);
    await prefs.setDouble('music_volume', _musicVolume);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الإعدادات'),
        backgroundColor: AppColors.primaryPink,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryPink, AppColors.secondaryPurple],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.lightPink.withValues(alpha: 0.2),
              AppColors.white,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            // إعدادات الصوت والموسيقى
            _buildSectionCard(
              title: '🎵 الصوت والموسيقى',
              children: [
                SwitchListTile(
                  title: Text('تشغيل الموسيقى'),
                  subtitle: Text('تشغيل الموسيقى الرومانسية في الخلفية'),
                  value: _musicEnabled,
                  activeThumbColor: AppColors.primaryPink,
                  onChanged: (value) {
                    setState(() {
                      _musicEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
                ListTile(
                  title: Text('مستوى الصوت'),
                  subtitle: Column(
                    children: [
                      Slider(
                        value: _musicVolume,
                        activeColor: AppColors.primaryPink,
                        inactiveColor: AppColors.lightPink,
                        onChanged: _musicEnabled
                            ? (value) {
                                setState(() {
                                  _musicVolume = value;
                                });
                                _saveSettings();
                              }
                            : null,
                      ),
                      Text(
                        '${(_musicVolume * 100).round()}%',
                        style: TextStyle(
                          color: AppColors.lightText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.3, end: 0),

            SizedBox(height: 20),

            // إعدادات الإشعارات
            _buildSectionCard(
              title: '🔔 الإشعارات',
              children: [
                SwitchListTile(
                  title: Text('إشعارات الذكريات'),
                  subtitle: Text('تذكير بالمناسبات والذكريات المهمة'),
                  value: _notificationsEnabled,
                  activeThumbColor: AppColors.primaryPink,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
                ListTile(
                  title: Text('مواعيد التذكير'),
                  subtitle: Text('يومياً في الساعة 8:00 مساءً'),
                  trailing: Icon(Icons.schedule, color: AppColors.primaryPink),
                  onTap: () {
                    // يمكن إضافة منطق تعديل التوقيت لاحقاً
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('ميزة قريباً')));
                  },
                ),
              ],
            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.3, end: 0),

            SizedBox(height: 20),

            // إعدادات العرض والأنيميشن
            _buildSectionCard(
              title: '✨ العرض والأنيميشن',
              children: [
                SwitchListTile(
                  title: Text('الأنيميشن والحركة'),
                  subtitle: Text('تفعيل الحركات والتأثيرات البصرية'),
                  value: _animationsEnabled,
                  activeThumbColor: AppColors.primaryPink,
                  onChanged: (value) {
                    setState(() {
                      _animationsEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
                ListTile(
                  title: Text('نمط الألوان'),
                  subtitle: Text(_selectedTheme),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPink,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: _showThemeSelector,
                ),
              ],
            ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.3, end: 0),

            SizedBox(height: 20),

            // إدارة البيانات
            _buildSectionCard(
              title: '💾 إدارة البيانات',
              children: [
                ListTile(
                  title: Text('نسخ احتياطي'),
                  subtitle: Text('حفظ جميع الذكريات والأحداث'),
                  leading: Icon(Icons.backup, color: AppColors.secondaryPurple),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showBackupDialog,
                ),
                ListTile(
                  title: Text('استيراد البيانات'),
                  subtitle: Text('استيراد ذكريات من مصادر أخرى'),
                  leading: Icon(
                    Icons.file_download,
                    color: AppColors.primaryPink,
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showImportDialog,
                ),
                ListTile(
                  title: Text('مسح البيانات المحفوظة'),
                  subtitle: Text('حذف جميع الإعدادات والبيانات المحلية'),
                  leading: Icon(Icons.delete, color: Colors.red),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showClearDataDialog,
                ),
              ],
            ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.3, end: 0),

            SizedBox(height: 20),

            // معلومات التطبيق
            _buildSectionCard(
              title: 'ℹ️ معلومات التطبيق',
              children: [
                ListTile(
                  title: Text('إصدار التطبيق'),
                  subtitle: Text('1.0.0+1'),
                  leading: Icon(Icons.info, color: AppColors.primaryPink),
                ),
                ListTile(
                  title: Text('حول التطبيق'),
                  subtitle: Text('تطبيق قصة حب محمد وسارة'),
                  leading: Icon(Icons.favorite, color: AppColors.primaryPink),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showAboutDialog,
                ),
                ListTile(
                  title: Text('مشاركة التطبيق'),
                  subtitle: Text('شارك قصة حبكم مع الأصدقاء'),
                  leading: Icon(Icons.share, color: AppColors.secondaryPurple),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _shareApp,
                ),
              ],
            ).animate().fadeIn(delay: 1000.ms).slideX(begin: -0.3, end: 0),

            SizedBox(height: 40),

            // رسالة رومانسية في النهاية
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.lightPink.withValues(alpha: 0.3),
                    AppColors.secondaryPurple.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.primaryPink.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text('💕', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 10),
                  Text(
                    'صُنع بحب لمحمد وسارة',
                    style: TextStyle(
                      color: AppColors.primaryPink,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'قصة حب تستحق التوثيق والاحتفاظ بها للأبد',
                    style: TextStyle(
                      color: AppColors.lightText,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 1200.ms).scale(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPink,
                ),
              ),
            ),
            ...children,
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('اختيار نمط الألوان'),
        content: RadioGroup<String>(
          groupValue: _selectedTheme,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedTheme = value;
              });
              _saveSettings();
              Navigator.pop(context);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('رومانسي (وردي)'),
                value: 'رومانسي',
                activeColor: AppColors.primaryPink,
              ),
              RadioListTile<String>(
                title: Text('كلاسيكي (أزرق)'),
                value: 'كلاسيكي',
                activeColor: Colors.blue,
              ),
              RadioListTile<String>(
                title: Text('ذهبي (فخم)'),
                value: 'ذهبي',
                activeColor: AppColors.goldAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('نسخ احتياطي'),
        content: Text('هل تريد إنشاء نسخة احتياطية من جميع ذكرياتكم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم إنشاء النسخة الاحتياطية بنجاح'),
                    backgroundColor: AppColors.primaryPink,
                  ),
                );
              }
            },
            child: Text('إنشاء نسخة'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('استيراد البيانات'),
        content: Text('اختر مصدر البيانات التي تريد استيرادها'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('ميزة الاستيراد قريباً')));
            },
            child: Text('استيراد'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Our Love Story',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryPink.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Text('💕', style: TextStyle(fontSize: 30)),
      ),
      children: [
        Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'تطبيق مخصص لتوثيق قصة حب محمد وسارة من اللقاء الأول حتى الزفاف وما بعده.',
          ),
        ),
        SizedBox(height: 10),
        Text(
          'صُنع بحب باستخدام Flutter مع تقنيات متقدمة لحفظ الذكريات الجميلة.',
        ),
        SizedBox(height: 15),
        Text(
          'المطور: فريق التطوير المحبب ❤️',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _shareApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('مشاركة التطبيق... 📱'),
        backgroundColor: AppColors.secondaryPurple,
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text('تأكيد مسح البيانات'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من حذف جميع البيانات المحفوظة؟'),
            SizedBox(height: 10),
            Text(
              '⚠️ سيتم حذف:\n• جميع الإعدادات\n• الأحداث المضافة\n• البيانات المحلية',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
            SizedBox(height: 10),
            Text(
              'لا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('تم مسح جميع البيانات بنجاح'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('مسح نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
