# ✨ Our Love Story V2.0 - Ethereal Romance (Cloud Firestore + Cloudinary + Rust Video Studio + ثنائي المحبة 2.0)

[![Flutter](https://img.shields.io/badge/Flutter-v3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean_Architecture_%2B_Riverpod-E1B162)](https://github.com/m4ohamed/our)
[![Video Engine](https://img.shields.io/badge/Video_Engine-Rust_FFI_%2B_Impeller_Canvas-DEA584?logo=rust)](https://www.rust-lang.org)

**Our Love Story** هو تطبيق متكامل لتوثيق أجمل لحظات الحب بين محمد وسارة، مبني وفق معمارية **Clean Architecture** مع **Riverpod**، ويدعم المزامنة الفورية على سيرفر **Cloud Firestore**، ورفع الصور والفيديوهات مجاناً عبر **Cloudinary**، ويضم **استوديو مونتاج وصناعة فيديو بالـ Keyframes (`VideoStudioScreen`)** مدعوماً بمحرك **Rust FFI**، بالإضافة إلى **سهرة الأزواج التفاعلية (ثنائي المحبة 2.0 - `CouplesNightScreen`)**.

## 💞 سهرة الأزواج التفاعلية - ثنائي المحبة 2.0 (`CouplesNightScreen`)

يضم التطبيق قسم سهرة وألعاب تفاعلية متكامل مبني بالكامل بـ **Flutter الأصلي (`Native Widgets & CustomPainter`)** ويدعم اللعب على **هاتف واحد (مرّر الهاتف)** أو **ربط هاتفين لحظياً عبر Cloud Firestore (`couples_rooms_v2/{pin}`)**:
1. **💬 كاشف القلوب (التوافق):** أسئلة مصنفة (`رومانسية`، `مواقف`، `أحلام`) يجيب عنها أحد الزوجين سراً ويخمنها الشريك لرفع مؤشر التناغم.
2. **🤔 تحدي مين فينا؟:** تصويت سري متزامن على مواقف يومية ورومانسية وكشف مدى الاتفاق بينكما.
3. **⭕ إكس-أو الذكية بـ 3 قلوب متحركة (بلا تعادل!):** لكل لاعب 3 قلوب كحد أقصى (`❤️` و`💜`)، وعند وضع القلب الرابع يختفي أقدم قلب تلقائياً مع تنبيه `ستختفي`، مما يلغي التعادل الممل.
4. **⚡ مبارزة النبض السريع:** تحدي سرعة البديهة بالضغط عند الإشارة الخضراء `🟢` وتجنب الفخ الأحمر `🔴` بحساب أجزاء الثانية.
5. **🎡 عجلة الدلال ومحفظة القسائم (`Love Coupons Wallet`):** عجلة مكافآت مرسومة عبر `CustomPainter` بسرعة 60 إطار/ثانية مع حفظ كل مكافأة في محفظة القسائم الدائمة وإمكانية إضافة مكافآت مخصصة.
6. **🔥 شريط النبض الفوري:** إرسال إيموجي متطاير حي (`❤️ 😍 💋 🌹 😂 🔥`) يظهر على شاشة الهاتفين في نفس اللحظة.

## 🔥 خطوة تفعيل ملف `google-services.json` الجاهز لديك

بما أنك قمت بتحميل ملف `google-services.json` من لوحة تحكم Firebase، كل ما عليك فعله هو:
1. انسخ ملف **`google-services.json`** وضعه مباشرة داخل المجلد:
   ```text
   android/app/google-services.json
   ```
2. تم إعداد ملفات `android/settings.gradle.kts` و`android/app/build.gradle.kts` للتعرف تلقائياً على وجود `google-services.json` وتفعيل إضافة `com.google.gms.google-services` فوراً أثناء بناء الـ APK.
3. إذا كنت تبني الـ APK عبر **GitHub Actions** ولا ترغب برفع الملف مباشرة، يمكنك إما تضمينه في مستودعك الخاص (بما أن المستودع Private)، أو وضع محتوى الملف داخل **GitHub Settings > Secrets and variables > Actions** باسم `GOOGLE_SERVICES_JSON` وسيقوم سير العمل بحقنه تلقائياً قبل البناء.

## 🎬 استوديو صناعة الفيديو والـ Keyframes (`VideoStudioScreen`)

يعتمد التطبيق على بنية هجينة (Hybrid Architecture) مستوحاة من مشاريع المونتاج المكتوبة بـ Rust مثل `FilmCraft` و`EffectCraft`:
- **نظام التوقيت الدقيق (`254,016,000,000` Ticks/Sec)** ومنحنيات الحركة (`Auto-Bezier` و`Cubic-Bezier` و`Hold`).
- **معالجة الألوان السينمائية (`Lumetri Color Grading`)** عبر مصفوفة ألوان `4x5` مع فلاتر جاهزة وتأثير `Vignette`.
- **سجل تراجع وإعادة (`Undo / Redo Stack`)** ومحرّك تصدير فيديو حقيقي.
