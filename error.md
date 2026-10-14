# سجل الأخطاء والتحسينات (Error Log & Fixes)

## 1. حالة التحليل الحالية (Current Analysis State)
- **فحص الأكواد (Dart Analyzer / MCP Dart):** لا توجد أخطاء برمجية أو نحوية (`No errors`).
- **التشخيصات (Diagnostics):** نظيفة بالكامل (`[]`).

## 2. التحذيرات المكتشفة (Detected Warnings)
تم اكتشاف 62 تحذيراً متعلقاً بالألوان الثابتة (Hardcoded Colors) في ملفات واجهة المستخدم، منها:
- `Colors.white`, `Colors.transparent`, `Colors.redAccent`, `Colors.dustyRose`, `Colors.pearlWhite`, `Colors.softTaupe`, `Color(0xFFE3F2FD)`, `Color(0xFFF3E5F5)`.
- **الملفات المتأثرة:** 
  - `lib/presentation/widgets/event_form_sheet.dart`
  - `lib/presentation/widgets/event_detail_sheet.dart`
  - `lib/presentation/screens/timeline_screen.dart`
  - `lib/presentation/screens/memories_album_screen.dart`
  - `lib/presentation/screens/settings_screen.dart`
  - `lib/presentation/screens/baby_countdown_screen.dart`
  - `lib/presentation/screens/surprise_screen.dart`
  - `lib/presentation/screens/pin_setup_screen.dart`

## 3. الأخطاء المحتملة لتفاديها قبل كتابة الكود (Potential Errors to Avoid)
- **إعادة زرع البيانات التجريبية (Demo Data Reseeding):** عند قيام المستخدم بحذف حدث تجريبي، يقوم `HiveTimelineRepository._seedDemoEvents` بإعادة إضافته تلقائياً لأن `_box.containsKey` يصبح `false`. **الحل:** تمرير `SharedPreferences` إلى المستودع والتحقق من المفتاح `AppConstants.keyEnableDemoData` قبل الزرع.
- **تحديث الكيانات (Entity & CopyWith):** نسيان إضافة الحقل الجديد `enableDemoData` في دوال `copyWith` أو `==` أو `hashCode` في `AppSettingsEntity`. **الحل:** تحديث الكيان بشكل كامل وشامل.

## 4. خطة الإصلاح المقترحة (Fix Strategy)
- استبدال الألوان الثابتة باستخدام نظام التقييم اللوني للتطبيق من خلال `Theme.of(context).colorScheme` أو عبر تخصيص الألوان داخل `AppTheme`.
- التأكد من دعم الوضعين الليلي والنهاري (Light/Dark mode) بشكل ديناميكي دون الاعتماد على قيم ثابتة.
