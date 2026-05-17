# ✨ Our Love Story - Ethereal Romance

[![Flutter](https://img.shields.io/badge/Flutter-v3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Design System](https://img.shields.io/badge/Design-Ethereal_Romance-FFD700)](https://github.com/m4ohamed/our)

**Our Love Story** هو تطبيق فاخر ومميز مصمم لتوثيق أجمل لحظات الحب بين محمد وسارة. تم إعادة تصميمه بالكامل باستخدام نظام التصميم السحابي **"Ethereal Romance"** ليقدم تجربة بصرية سينمائية تعتمد على الشفافية (Glassmorphism) والحركات الناعمة.

---

## 🎨 نظام التصميم (Ethereal Romance)

يعتمد التطبيق على فلسفة "Pearl & Petal" التي تمزج بين النقاء والرومانسية:
- **لوحة الألوان**:
  - `Pearl White`: للخلفيات المضيئة والصفاء.
  - `Dusty Rose`: للأجزاء التفاعلية واللمسات العاطفية.
  - `Champagne Gold`: للأيقونات والعناوين الفاخرة.
  - `Soft Taupe`: للنصوص الجانبية والتفاصيل الدقيقة.
- **الواجهة الزجاجية (Glassmorphism)**: استخدام مكثف لـ `BackdropFilter` لإنشاء طبقات شفافة تعطي عمقاً فائقاً.
- **الخطوط**: 
  - `Noto Serif`: للعناوين الرسمية والقصصية.
  - `Manrope`: للنصوص التفصيلية لسهولة القراءة.

---

## 🚀 المميزات الرئيسية

- **لوحة تحكم سينمائية**: واجهة رئيسية تعرض عدد أيام الحب بتصميم عصري.
- **خط زمني تفاعلي**: سرد لقصة الحب من خلال الأحداث والمحطات الهامة (Milestones).
- **ألبوم الذكريات**: معرض صور ذكي (Masonry Layout) مع فلاتر حية وحركات انتقال سلسة.
- **عداد يوم الزفاف**: مؤقت تنازلي بلمسات لؤلؤية واحتفالات مبهجة.
- **صندوق المفاجآت**: ميزة "Unboxing" لرسائل الحب السرية مع تأثيرات جزيئية (Particles).

---

## 📁 هيكلية المشروع (Project Structure)

```text
lib/
├── main.dart                 # نقطة الانطلاق وإعدادات الثيم العام
├── theme/
│   └── app_theme.dart        # تعريف ألوان Ethereal Romance والخطوط
├── models/
│   ├── media_file.dart       # نموذج بيانات الصور والفيديوهات
│   └── timeline_event.dart    # نموذج بيانات أحداث الخط الزمني
├── screens/
│   ├── splash_screen.dart     # واجهة الدخول السينمائية
│   ├── home_screen.dart       # لوحة التحكم الرئيسية (Dashboard)
│   ├── timeline_screen.dart   # شاشة عرض قصة الحب (Milestones)
│   ├── memories_album_screen.dart # معرض الصور والذكريات
│   ├── countdown_screen.dart  # مؤقت يوم الزفاف
│   ├── surprise_screen.dart   # شاشة الرسائل السرية والمفاجآت
│   └── settings_screen.dart   # إعدادات التطبيق والموسيقى
├── widgets/
│   └── event_detail_dialog.dart # مكونات تفاعلية لعرض تفاصيل الأحداث
└── assets/                    # الموارد الخارجية (صور، صوتيات، خطوط)
```

---

## 🛠 التكنولوجيا المستخدمة

- **Framework**: Flutter (للاندرويد والـ iOS)
- **State Management**: Provider / Local States
- **Animations**: `flutter_animate`
- **Typography**: `google_fonts` (Noto Serif & Manrope)
- **UI Components**: `flutter_staggered_grid_view`, `timeline_tile`, `glassmorphism` effects.

---

## 📥 التشغيل

للتشغيل محلياً:

1. قم بتحميل المستودع:
   ```bash
   git clone https://github.com/m4ohamed/our.git
   ```
2. قم بتثبيت المكتبات:
   ```bash
   flutter pub get
   ```
3. ابدأ التشغيل:
   ```bash
   flutter run
   ```

---

**صُنع بكل حب ❤️ لتكون قصة محمد وسارة خالدة إلى الأبد.**
