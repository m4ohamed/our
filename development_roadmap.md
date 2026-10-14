# خريطة تطوير المشروع (Development Roadmap)

## 📍 الحالة الحالية للمشروع (Current Project Status)
تطبيق **Our Love Story** هو تطبيق ذكريات مصمم بمعمارية نظيفة (Clean Architecture) ومزود بميزات متقدمة تشمل:
- **إدارة الحالة (State Management):** استخدام `flutter_riverpod` و `riverpod_annotation`.
- **التخزين المحلي (Local Storage):** الاعتماد على `Hive` لتخزين الأحداث والذكريات، و `shared_preferences` للإعدادات.
- **الواجهة والتأثيرات (UI & Animations):** دعم خطوط جوجل `google_fonts`، وتأثيرات حركية `flutter_animate` و `confetti`.
- **الوسائط والصوتيات (Media & Audio):** تشغيل الموسيقى الخلفية عبر `audioplayers`، وعرض الصور المتقدم عبر `photo_view` و `cached_network_image`.
- **الأمان والخصوصية (Security):** إعداد قفل للتطبيق برمز PIN باستخدام `local_auth` و `crypto`.
- **تعدد اللغات (Localization):** دعم كامل للغتين العربية والإنجليزية عبر ملفات `ARB` وحزم `flutter_intl`.

---

## 📅 ما تم إنجازه اليوم (Today's Milestone)
- **التقييم الشامل للمشروع:** تم إجراء فحص دقيق وشامل باستخدام أدوات `MCP Dart` و `Flutter Explorer MCP`.
- **تحليل البيانات التجريبية (Mockup Data):** تم حصر 11 حدثاً تجريبياً في `DemoEventsSeed` وتحديد آلية عمل المستودع `HiveTimelineRepository` التي تقوم بإعادة زرع البيانات تلقائياً، وتم وضع خطة لتمكين المستخدم من حذفها واستبدالها ببيانات حقيقية من داخل التطبيق.
- **تصنيف تحذيرات الألوان (Color Warnings Analysis):** تم تحليل 62 تحذيراً للألوان الثابتة وتصنيفها بدقة إلى ألوان تتطلب التغيير لدعم الثيمات (مثل الأبيض والأسود والخلفيات الثابتة) وألوان يفضل بقاؤها (مثل الشفاف والأحمر التحذيري).
- **إعداد وتفعيل Firebase و Cloud Firestore ومزامنة ملف google-services.json:**
  - تم إنشاء مشروع Firebase جديد باسم `our-love-story-2026` وتفعيله بالكامل.
  - تم إنشاء وتفعيل قاعدة بيانات Cloud Firestore الرسمية بنمط `FIRESTORE_NATIVE` في نطاق `eur3`.
  - تم تسجيل تطبيق Android بحزمة `com.our.loveStory` واستخراج ملف `google-services.json` الأصلي وحفظه في مسار التطبيق الرئيسي `android/app/google-services.json`.
  - تم تحديث بيانات الاتصال الاحتياطية المدمجة في `FirebaseOnlineService.fallbackFirebaseOptions` لتعمل على المشروع الجديد مباشرة.
  - تم ربط إعدادات المشروع عبر `.firebaserc` و `firebase.json` و `firestore.rules`.

---

## 🚀 الخطوات القادمة (Next Steps)
1. **إدارة البيانات التجريبية (Demo Data Management):** استكمال ربط خيار إيقاف الزرع التلقائي للبيانات التجريبية (`_seedDemoEvents`) ومسحها نهائياً في واجهة المستخدم.
2. **تحسين الثيمات (Theme Refactoring):** استبدال الألوان الثابتة في ملفات واجهة المستخدم (UI) باستخدام `Theme.of(context).colorScheme`.
3. **تحسين الأداء (Performance Optimization):** مراجعة استهلاك الذاكرة لصور الألبوم والتأكد من التخزين المؤقت الفعال (Caching).

