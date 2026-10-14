// lib/presentation/screens/couples_night_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';
import '../providers/app_providers.dart';

// ============================================================================
// DATA MODELS & CONTENT POOLS (ثنائي المحبة V2.0)
// ============================================================================

class TawafoqQuestion {
  final String category;
  final String question;
  final List<String> options;

  const TawafoqQuestion({
    required this.category,
    required this.question,
    required this.options,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'question': question,
    'options': options,
  };

  factory TawafoqQuestion.fromJson(Map<String, dynamic> json) {
    return TawafoqQuestion(
      category: (json['category'] as String?) ?? 'رومانسية',
      question: (json['question'] as String?) ?? '',
      options: List<String>.from(json['options'] as List? ?? const []),
    );
  }
}

class RewardWheelItem {
  final String text;
  final int colorValue;

  const RewardWheelItem({required this.text, required this.colorValue});

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {'text': text, 'colorValue': colorValue};

  factory RewardWheelItem.fromJson(Map<String, dynamic> json) {
    return RewardWheelItem(
      text: (json['text'] as String?) ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFF43F5E,
    );
  }
}

class LoveCouponItem {
  final int id;
  final String title;
  final String earner;
  final bool done;

  const LoveCouponItem({
    required this.id,
    required this.title,
    required this.earner,
    required this.done,
  });

  LoveCouponItem copyWith({bool? done}) => LoveCouponItem(
    id: id,
    title: title,
    earner: earner,
    done: done ?? this.done,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'earner': earner,
    'done': done,
  };

  factory LoveCouponItem.fromJson(Map<String, dynamic> json) {
    return LoveCouponItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      earner: (json['earner'] as String?) ?? AppConstants.partner1Name,
      done: (json['done'] as bool?) ?? false,
    );
  }
}

const List<TawafoqQuestion> kDefaultTawafoqQuestions = [
  TawafoqQuestion(
    category: 'رومانسية',
    question: 'أكثر تفصيلة صغيرة من شريكك تذيب قلبك فوراً:',
    options: [
      'نظرة عين حنونة وسط الزحام',
      'مسكة يد دافئة بدون سبب',
      'رسالة شوق مفاجئة وسط اليوم',
      'ضمّة طويلة بعد يوم متعب',
    ],
  ),
  TawafoqQuestion(
    category: 'رومانسية',
    question: 'المكان المثالي لقضاء ذكرى زواجنا القادمة:',
    options: [
      'عشاء هادئ على ضوء الشموع في المنزل',
      'شاليه خاص على البحر بعيداً عن الناس',
      'فندق فاخر مع جلسة استجمام ومساج',
      'رحلة مغامرة واستكشاف مدينة جديدة',
    ],
  ),
  TawafoqQuestion(
    category: 'مواقف',
    question: 'عندما نختلف في أمر بسيط، أسرع طريقة ترضيني هي:',
    options: [
      'اعتذار لطيف مع ابتسامة دافئة',
      'ترك مساحة قصيرة للهدوء ثم الحوار',
      'مزحة ذكية تضحكني وتنهي التوتر',
      'كوب قهوة أو أكلة أحبها كعربون صلح',
    ],
  ),
  TawafoqQuestion(
    category: 'مواقف',
    question: 'في السهرات المنزلية، المزاج الغالب عندي يكون:',
    options: [
      'مشاهدة فيلم أو مسلسل مع تسالي',
      'الحديث والفضفضة والضحك معاً',
      'اللعب والتحديات التفاعلية مثل الآن',
      'الاسترخاء الهادئ قبل النوم مبكراً',
    ],
  ),
  TawafoqQuestion(
    category: 'أحلام',
    question: 'لو ربحنا إجازة مدفوعة التكاليف لمدة أسبوع، سأختار:',
    options: [
      'طبيعة خضراء وأكواخ ريفية هادئة',
      'جزيرة استوائية وشاطئ فيروزي',
      'عاصمة أوروبية للتسوق والمقاهي',
      'رحلة روحانية هادئة ومريحة للقلب',
    ],
  ),
  TawafoqQuestion(
    category: 'أحلام',
    question: 'أهم هدف مشترك أتمنى أن نحققه معاً خلال العامين القادمين:',
    options: [
      'السفر لوجهة كنا نحلم بها طويلاً',
      'تطوير منزلنا وإضافة لمسات فخمة',
      'بناء مشروع أو ادخار مالي قوي',
      'تخصيص وقت أسبوعي ثابت لدلالنا',
    ],
  ),
];

const List<String> kDefaultWhosMoreQuestions = [
  'مين فينا يبادر بمصالحة الثاني أولاً بعد أي خلاف بسيط؟ 🕊️',
  'مين فينا يأخذ وقتاً أطول في التجهز واللبس قبل الخروج؟ 🪞',
  'مين فينا يغلب عليه النعاس أولاً أثناء مشاهدة فيلم بالسهرة؟ 😴',
  'مين فينا أكثر رومانسية ويعبّر عن مشاعره بالكلام أكثر؟ 💌',
  'مين فينا يصرف الفلوس أسرع على الأشياء اللطيفة والهدايا؟ 🛍️',
  'مين فينا يضحك أولاً لو حاولنا نمسك الضحكة في موقف جاد؟ 😂',
  'مين فينا يتذكر التواريخ والمناسبات الخاصة بدقة أكبر؟ 📅',
];

const List<RewardWheelItem> kDefaultRewards = [
  RewardWheelItem(text: 'مساج للكتفين والرقبة 10 دقائق 💆', colorValue: 0xFFF43F5E),
  RewardWheelItem(text: 'تحضير مشروب السهرة المفضل ☕', colorValue: 0xFF9333EA),
  RewardWheelItem(text: 'إعفاء كامل من مهام الليلة 👑', colorValue: 0xFFEC4899),
  RewardWheelItem(text: 'اختيار فيلم أو عشاء الغد 🍕', colorValue: 0xFF3B82F6),
  RewardWheelItem(text: 'ثلاث أمنيات لطيفة تنفذ الليلة ✨', colorValue: 0xFF10B981),
  RewardWheelItem(text: 'رسالة حب صوتية أو مكتوبة الآن 💌', colorValue: 0xFFF59E0B),
];

class _FlyingEmoji {
  final int id;
  final String emoji;
  final double leftFraction;

  const _FlyingEmoji({
    required this.id,
    required this.emoji,
    required this.leftFraction,
  });
}

// ============================================================================
// MAIN SCREEN: ثنائي المحبة V2.0 | سهرة الأزواج التفاعلية
// ============================================================================

class CouplesNightScreen extends ConsumerStatefulWidget {
  final String initialTab;

  const CouplesNightScreen({super.key, this.initialTab = 'home'});

  @override
  ConsumerState<CouplesNightScreen> createState() => _CouplesNightScreenState();
}

class _CouplesNightScreenState extends ConsumerState<CouplesNightScreen>
    with TickerProviderStateMixin {
  // Cloud Room & Role State
  String? _roomId;
  String _myRole = 'single'; // 'single' | 'p1' | 'p2'
  bool _partnerOnline = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sharedMetaSub;

  // Meta State
  String _p1Name = AppConstants.partner1Name;
  String _p2Name = AppConstants.partner2Name;
  int _p1Score = 0;
  int _p2Score = 0;
  int _harmony = 25;
  List<RewardWheelItem> _rewards = List.of(kDefaultRewards);
  List<LoveCouponItem> _coupons = [];

  // Active Game Mode
  late String _activeTab; // 'home' | 'tawafoq' | 'whosmore' | 'xo' | 'speed' | 'wheel'

  // Mode 2: Tawafoq State
  String _tawafoqCat = 'الكل';
  int _tawafoqQIdx = 0;
  String _tawafoqTurn = 'p1';
  String _tawafoqPhase = 'secret'; // 'secret' | 'pass_device' | 'guess' | 'reveal'
  int? _tawafoqSecretPick;
  int? _tawafoqGuessPick;

  // Mode 3: Who's More Likely State
  int _whosQIdx = 0;
  String? _whosP1Vote; // 'p1' | 'p2'
  String? _whosP2Vote;
  String _whosLocalStep = 'p1';

  // Mode 4: Infinite 3-Heart XO State
  List<String?> _xoBoard = List<String?>.filled(9, null);
  List<int> _xoP1Moves = [];
  List<int> _xoP2Moves = [];
  String _xoTurn = 'p1';
  String? _xoWinner;
  List<int>? _xoWinLine;

  // Mode 5: Speed Reflex Arena State
  Timer? _speedTimer;
  String _speedSignal = 'idle'; // 'idle' | 'wait' | 'green' | 'red'
  final Stopwatch _speedStopwatch = Stopwatch();
  String _speedBannerText = '⏱️ اضغط هنا لبدء جولة السرعة';
  Color _speedBannerColor = const Color(0xFFFDF2F8);
  bool _speedBannerDarkText = true;
  int _lastHandledSpeedEventId = 0;

  // Mode 6: Rewards Wheel State
  late AnimationController _wheelController;
  double _wheelStartAngle = 0.0;
  double _wheelCurrentAngle = 0.0;
  double _wheelTargetAngle = 0.0;
  int _wheelWinIdx = 0;
  bool _wheelSpinning = false;
  String _wheelBannerText = 'أدر العجلة لتربح قسيمة دلال ينفذها شريكك بحب!';
  int _lastHandledSpinId = 0;

  // Reactions & Confetti
  late ConfettiController _confettiController;
  final List<_FlyingEmoji> _flyingEmojis = [];
  int _lastHandledReactionId = 0;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..addListener(() {
      final t = Curves.easeOutCubic.transform(_wheelController.value);
      setState(() {
        _wheelCurrentAngle =
            _wheelStartAngle + (_wheelTargetAngle - _wheelStartAngle) * t;
      });
    })..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _wheelSpinning = false;
          if (_wheelWinIdx >= 0 && _wheelWinIdx < _rewards.length) {
            _wheelBannerText =
                '🎉 مبروك! ربحت قسيمة: (${_rewards[_wheelWinIdx].text}) وأضيفت للمحفظة 🎟️';
          }
        });
        _burstConfetti();
      }
    });

    _loadLocalState();
    _initPermanentOnlineMetaSync();
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _roomSub?.cancel();
    _sharedMetaSub?.cancel();
    _wheelController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ─── Local & Cloud Persistence ─────────────────────────────────────────────

  void _loadLocalState() {
    final prefs = ref.read(sharedPreferencesProvider);
    final rawState = prefs.getString(AppConstants.keyCouplesNightState);
    if (rawState != null && rawState.isNotEmpty) {
      try {
        final map = jsonDecode(rawState) as Map<String, dynamic>;
        _p1Name = (map['p1Name'] as String?) ?? AppConstants.partner1Name;
        _p2Name = (map['p2Name'] as String?) ?? AppConstants.partner2Name;
        _p1Score = (map['p1Score'] as num?)?.toInt() ?? 0;
        _p2Score = (map['p2Score'] as num?)?.toInt() ?? 0;
        _harmony = (map['harmony'] as num?)?.toInt() ?? 25;
        if (map['rewards'] is List) {
          _rewards = (map['rewards'] as List)
              .map((e) => RewardWheelItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {}
    }

    final rawCoupons = prefs.getString(AppConstants.keyLoveCoupons);
    if (rawCoupons != null && rawCoupons.isNotEmpty) {
      try {
        final list = jsonDecode(rawCoupons) as List;
        _coupons = list
            .map((e) => LoveCouponItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveLocalState() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      AppConstants.keyCouplesNightState,
      jsonEncode({
        'p1Name': _p1Name,
        'p2Name': _p2Name,
        'p1Score': _p1Score,
        'p2Score': _p2Score,
        'harmony': _harmony,
        'rewards': _rewards.map((r) => r.toJson()).toList(),
      }),
    );
    await prefs.setString(
      AppConstants.keyLoveCoupons,
      jsonEncode(_coupons.map((c) => c.toJson()).toList()),
    );
  }

  Map<String, dynamic> _serializeSession() => {
    'view': _activeTab,
    'tawafoq': {
      'cat': _tawafoqCat,
      'qIdx': _tawafoqQIdx,
      'turn': _tawafoqTurn,
      'phase': _tawafoqPhase,
      'secretPick': _tawafoqSecretPick,
      'guessPick': _tawafoqGuessPick,
    },
    'whos': {
      'qIdx': _whosQIdx,
      'p1Vote': _whosP1Vote,
      'p2Vote': _whosP2Vote,
      'localStep': _whosLocalStep,
    },
    'xo': {
      'board': _xoBoard,
      'p1Moves': _xoP1Moves,
      'p2Moves': _xoP2Moves,
      'turn': _xoTurn,
      'winner': _xoWinner,
      'winLine': _xoWinLine,
    },
    'wheel': {
      'spinId': _lastHandledSpinId,
      'targetAngle': _wheelTargetAngle,
      'winIdx': _wheelWinIdx,
    },
  };

  Map<String, dynamic> _serializeMeta() => {
    'p1Name': _p1Name,
    'p2Name': _p2Name,
    'p1Score': _p1Score,
    'p2Score': _p2Score,
    'harmony': _harmony,
    'rewards': _rewards.map((r) => r.toJson()).toList(),
    'coupons': _coupons.map((c) => c.toJson()).toList(),
  };


  /// مزامنة دائمة أونلاين لمحفظة قسائم الدلال والنقاط ومؤشر التناغم بين الهاتفين
  void _initPermanentOnlineMetaSync() {
    final firestore = ref.read(firestoreInstanceProvider);
    if (firestore == null) return;
    _sharedMetaSub = firestore
        .collection(AppConstants.firestoreCoupleDoc)
        .doc("main_couple")
        .snapshots()
        .listen((snap) {
          final data = snap.data();
          if (data == null || !mounted || _roomId != null) return;
          final meta = data["meta"] as Map<String, dynamic>?;
          if (meta == null) return;
          setState(() {
            _p1Name = (meta["p1Name"] as String?) ?? _p1Name;
            _p2Name = (meta["p2Name"] as String?) ?? _p2Name;
            _p1Score = (meta["p1Score"] as num?)?.toInt() ?? _p1Score;
            _p2Score = (meta["p2Score"] as num?)?.toInt() ?? _p2Score;
            _harmony = (meta["harmony"] as num?)?.toInt() ?? _harmony;
            if (meta["rewards"] is List) {
              _rewards = (meta["rewards"] as List)
                  .map((e) => RewardWheelItem.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList();
            }
            if (meta["coupons"] is List) {
              _coupons = (meta["coupons"] as List)
                  .map((e) => LoveCouponItem.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList();
            }
          });
          _saveLocalState();
        });
  }

  /// ربط مباشر فوري بغرفة الزوجين الدائمة (#1000) بضغطة واحدة بدون الحاجة لإدخال كود
  Future<void> _connectInstantSharedRoom(String role) async {
    final firestore = ref.read(firestoreInstanceProvider);
    if (firestore == null) return;
    HapticFeedback.mediumImpact();
    const pin = "1000";
    setState(() {
      _roomId = pin;
      _myRole = role;
    });
    final docRef = firestore.collection(AppConstants.firestoreRoomsCollection).doc(pin);
    final snap = await docRef.get();
    if (!snap.exists) {
      await docRef.set({
        "createdAt": FieldValue.serverTimestamp(),
        "p1Online": role == "p1",
        "p2Online": role == "p2",
        "meta": _serializeMeta(),
        "session": _serializeSession(),
      });
    } else {
      await docRef.set({
        role == "p1" ? "p1Online" : "p2Online": true,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _subscribeToRoom(pin);
    _burstConfetti();
    _showToast("🎉 تم الاتصال الفوري بغرفة الزوجين المشتركة (#1000)");
  }

  Future<void> _pushState() async {
    await _saveLocalState();
    final firestore = ref.read(firestoreInstanceProvider);
    if (firestore != null) {
      try {
        await firestore.collection(AppConstants.firestoreCoupleDoc).doc("main_couple").set({
          "meta": _serializeMeta(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    if (_roomId == null || firestore == null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      await firestore
          .collection(AppConstants.firestoreRoomsCollection)
          .doc(_roomId)
          .set({
            'meta': _serializeMeta(),
            'session': _serializeSession(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ─── Cloud Room Pairing (Firestore Real-time Sync) ─────────────────────────

  Future<String?> _createCloudRoom() async {
    final firestore = ref.read(firestoreInstanceProvider);
    if (firestore == null) {
      _showToast('⚠️ أضف ملف google-services.json لتفعيل الربط السحابي بين هاتفين');
      return null;
    }

    HapticFeedback.mediumImpact();
    final pin = (1000 + math.Random().nextInt(9000)).toString();
    setState(() {
      _roomId = pin;
      _myRole = 'p1';
      _partnerOnline = false;
    });

    try {
      await firestore
          .collection(AppConstants.firestoreRoomsCollection)
          .doc(pin)
          .set({
            'createdAt': FieldValue.serverTimestamp(),
            'p1Online': true,
            'p2Online': false,
            'meta': _serializeMeta(),
            'session': _serializeSession(),
          });
      _subscribeToRoom(pin);
      final oneSignal = ref.read(oneSignalServiceProvider);
      oneSignal.sendNotificationToPartner(
        title: 'دعوة لسهرة الأزواج التفاعلية 💞🎲',
        message: 'فتح ${oneSignal.myName} غرفة سهرة رقم #$pin وينتظرك الآن للعب!',
        category: 'couples_night',
      );
      return pin;
    } catch (e) {
      _showToast('تعذر إنشاء الغرفة السحابية، تأكد من الاتصال بالإنترنت');
      return null;
    }
  }

  Future<bool> _joinCloudRoom(String pin) async {
    final firestore = ref.read(firestoreInstanceProvider);
    if (firestore == null) {
      _showToast('⚠️ أضف ملف google-services.json لتفعيل الربط السحابي بين هاتفين');
      return false;
    }
    final cleanPin = pin.trim();
    if (cleanPin.length < 4) {
      _showToast('أدخل رمز الغرفة المكون من 4 أرقام');
      return false;
    }

    try {
      final docRef = firestore
          .collection(AppConstants.firestoreRoomsCollection)
          .doc(cleanPin);
      final snap = await docRef.get();
      if (!snap.exists) {
        _showToast('لم يتم العثور على الغرفة #$cleanPin، تأكد من الرمز!');
        return false;
      }

      setState(() {
        _roomId = cleanPin;
        _myRole = 'p2';
        _partnerOnline = true;
      });

      await docRef.update({'p2Online': true});
      _subscribeToRoom(cleanPin);
      _burstConfetti();
      _showToast('🎉 تم الربط بنجاح مع غرفة #$cleanPin');
      return true;
    } catch (_) {
      _showToast('حدث خطأ أثناء الانضمام للغرفة');
      return false;
    }
  }

  void _subscribeToRoom(String pin) {
    _roomSub?.cancel();
    _sharedMetaSub?.cancel();
    final firestore = ref.read(firestoreInstanceProvider);
    if (firestore == null) return;

    _roomSub = firestore
        .collection(AppConstants.firestoreRoomsCollection)
        .doc(pin)
        .snapshots()
        .listen((snap) {
          final data = snap.data();
          if (data == null || !mounted) return;

          final wasOnline = _partnerOnline;
          final nowOnline = _myRole == 'p1'
              ? (data['p2Online'] == true)
              : (data['p1Online'] == true);

          if (!wasOnline && nowOnline && _myRole == 'p1') {
            _burstConfetti();
            _showToast('🎉 انضمت $_p2Name للغرفة الآن!');
          }

          setState(() {
            _partnerOnline = nowOnline;

            final meta = data['meta'] as Map<String, dynamic>?;
            if (meta != null) {
              _p1Name = (meta['p1Name'] as String?) ?? _p1Name;
              _p2Name = (meta['p2Name'] as String?) ?? _p2Name;
              _p1Score = (meta['p1Score'] as num?)?.toInt() ?? _p1Score;
              _p2Score = (meta['p2Score'] as num?)?.toInt() ?? _p2Score;
              _harmony = (meta['harmony'] as num?)?.toInt() ?? _harmony;
              if (meta['rewards'] is List) {
                _rewards = (meta['rewards'] as List)
                    .map(
                      (e) => RewardWheelItem.fromJson(
                        Map<String, dynamic>.from(e as Map),
                      ),
                    )
                    .toList();
              }
              if (meta['coupons'] is List) {
                _coupons = (meta['coupons'] as List)
                    .map(
                      (e) => LoveCouponItem.fromJson(
                        Map<String, dynamic>.from(e as Map),
                      ),
                    )
                    .toList();
              }
            }

            final session = data['session'] as Map<String, dynamic>?;
            if (session != null) {
              _activeTab = (session['view'] as String?) ?? _activeTab;

              final tw = session['tawafoq'] as Map<String, dynamic>?;
              if (tw != null) {
                _tawafoqCat = (tw['cat'] as String?) ?? 'الكل';
                _tawafoqQIdx = (tw['qIdx'] as num?)?.toInt() ?? 0;
                _tawafoqTurn = (tw['turn'] as String?) ?? 'p1';
                _tawafoqPhase = (tw['phase'] as String?) ?? 'secret';
                _tawafoqSecretPick = (tw['secretPick'] as num?)?.toInt();
                _tawafoqGuessPick = (tw['guessPick'] as num?)?.toInt();
              }

              final wm = session['whos'] as Map<String, dynamic>?;
              if (wm != null) {
                _whosQIdx = (wm['qIdx'] as num?)?.toInt() ?? 0;
                _whosP1Vote = wm['p1Vote'] as String?;
                _whosP2Vote = wm['p2Vote'] as String?;
                _whosLocalStep = (wm['localStep'] as String?) ?? 'p1';
              }

              final xo = session['xo'] as Map<String, dynamic>?;
              if (xo != null) {
                final rawBoard = xo['board'] as List?;
                if (rawBoard != null && rawBoard.length == 9) {
                  _xoBoard = rawBoard.map((e) => e as String?).toList();
                }
                _xoP1Moves = List<int>.from(
                  (xo['p1Moves'] as List? ?? const []).map((e) => (e as num).toInt()),
                );
                _xoP2Moves = List<int>.from(
                  (xo['p2Moves'] as List? ?? const []).map((e) => (e as num).toInt()),
                );
                _xoTurn = (xo['turn'] as String?) ?? 'p1';
                _xoWinner = xo['winner'] as String?;
                _xoWinLine = xo['winLine'] != null
                    ? List<int>.from(
                        (xo['winLine'] as List).map((e) => (e as num).toInt()),
                      )
                    : null;
              }

              final wheel = session['wheel'] as Map<String, dynamic>?;
              if (wheel != null) {
                final remoteSpinId = (wheel['spinId'] as num?)?.toInt() ?? 0;
                if (remoteSpinId != 0 && remoteSpinId != _lastHandledSpinId) {
                  _lastHandledSpinId = remoteSpinId;
                  final target =
                      (wheel['targetAngle'] as num?)?.toDouble() ?? 0.0;
                  final winIdx = (wheel['winIdx'] as num?)?.toInt() ?? 0;
                  _animateWheelTo(target, winIdx);
                }
              }
            }

            final reaction = data['reaction'] as Map<String, dynamic>?;
            if (reaction != null) {
              final rId = (reaction['id'] as num?)?.toInt() ?? 0;
              final emoji = (reaction['emoji'] as String?) ?? '❤️';
              if (rId != 0 && rId != _lastHandledReactionId) {
                _lastHandledReactionId = rId;
                _spawnLocalEmoji(emoji);
              }
            }

            final speedEv = data['speedEvent'] as Map<String, dynamic>?;
            if (speedEv != null) {
              final sId = (speedEv['id'] as num?)?.toInt() ?? 0;
              if (sId != 0 && sId != _lastHandledSpeedEventId) {
                _lastHandledSpeedEventId = sId;
                _handleRemoteSpeedEvent(speedEv);
              }
            }
          });
          _saveLocalState();
        });
  }

  void _disconnectCloudRoom() {
    _roomSub?.cancel();
    _sharedMetaSub?.cancel();
    _roomSub = null;
    setState(() {
      _roomId = null;
      _myRole = 'single';
      _partnerOnline = false;
    });
    _showToast('تم التحويل لوضع الهاتف الواحد (مرّر الهاتف)');
  }

  // ─── Helpers: Sound, Confetti, Toast, Reactions ────────────────────────────

  void _burstConfetti() {
    HapticFeedback.heavyImpact();
    _confettiController.play();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _triggerReaction(String emoji) {
    HapticFeedback.lightImpact();
    _spawnLocalEmoji(emoji);
    final firestore = ref.read(firestoreInstanceProvider);
    if (_roomId != null && firestore != null) {
      final id = DateTime.now().millisecondsSinceEpoch;
      _lastHandledReactionId = id;
      firestore
          .collection(AppConstants.firestoreRoomsCollection)
          .doc(_roomId)
          .set({
            'reaction': {'id': id, 'emoji': emoji},
          }, SetOptions(merge: true));
    }
  }

  void _spawnLocalEmoji(String emoji) {
    final id = DateTime.now().microsecondsSinceEpoch + math.Random().nextInt(999);
    final left = 0.12 + math.Random().nextDouble() * 0.76;
    setState(() {
      _flyingEmojis.add(_FlyingEmoji(id: id, emoji: emoji, leftFraction: left));
    });
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) {
        setState(() {
          _flyingEmojis.removeWhere((e) => e.id == id);
        });
      }
    });
  }

  // ─── Game Logic 1: Tawafoq (كاشف القلوب) ──────────────────────────────────

  List<TawafoqQuestion> get _filteredTawafoqQuestions {
    if (_tawafoqCat == 'الكل') return kDefaultTawafoqQuestions;
    return kDefaultTawafoqQuestions
        .where((q) => q.category == _tawafoqCat)
        .toList();
  }

  void _selectTawafoqCategory(String cat) {
    HapticFeedback.selectionClick();
    setState(() {
      _tawafoqCat = cat;
      _tawafoqQIdx = 0;
      _tawafoqTurn = 'p1';
      _tawafoqPhase = 'secret';
      _tawafoqSecretPick = null;
      _tawafoqGuessPick = null;
    });
    _pushState();
  }

  void _submitTawafoqSecret(int idx) {
    HapticFeedback.lightImpact();
    setState(() {
      _tawafoqSecretPick = idx;
      _tawafoqPhase = _roomId != null ? 'guess' : 'pass_device';
    });
    _pushState();
  }

  void _submitTawafoqGuess(int idx) {
    final matched = _tawafoqSecretPick == idx;
    final guesserRole = _tawafoqTurn == 'p1' ? 'p2' : 'p1';

    setState(() {
      _tawafoqGuessPick = idx;
      _tawafoqPhase = 'reveal';
      if (matched) {
        if (guesserRole == 'p1') {
          _p1Score += 2;
        } else {
          _p2Score += 2;
        }
        _harmony = math.min(100, _harmony + 12);
      } else {
        _harmony = math.min(100, _harmony + 3);
      }
    });

    if (matched) {
      _burstConfetti();
    } else {
      HapticFeedback.mediumImpact();
    }
    _pushState();
  }

  void _nextTawafoqQuestion() {
    HapticFeedback.selectionClick();
    setState(() {
      _tawafoqQIdx++;
      _tawafoqTurn = _tawafoqTurn == 'p1' ? 'p2' : 'p1';
      _tawafoqPhase = 'secret';
      _tawafoqSecretPick = null;
      _tawafoqGuessPick = null;
    });
    _pushState();
  }

  // ─── Game Logic 2: Who's More Likely (تحدي مين فينا؟) ─────────────────────

  void _castWhosVote(String pickedRole) {
    HapticFeedback.lightImpact();
    final voter = _roomId != null ? _myRole : _whosLocalStep;

    setState(() {
      if (voter == 'p1') {
        _whosP1Vote = pickedRole;
      } else {
        _whosP2Vote = pickedRole;
      }

      if (_roomId == null && _whosLocalStep == 'p1') {
        _whosLocalStep = 'p2';
        return;
      }

      if (_whosP1Vote != null && _whosP2Vote != null) {
        if (_whosP1Vote == _whosP2Vote) {
          _p1Score++;
          _p2Score++;
          _harmony = math.min(100, _harmony + 10);
          _burstConfetti();
        }
      }
    });
    _pushState();
  }

  void _nextWhosMoreQuestion() {
    HapticFeedback.selectionClick();
    setState(() {
      _whosQIdx++;
      _whosP1Vote = null;
      _whosP2Vote = null;
      _whosLocalStep = 'p1';
    });
    _pushState();
  }

  // ─── Game Logic 3: Infinite 3-Heart XO (إكس-أو الذكية بلا تعادل!) ──────────

  void _playXoSlot(int idx) {
    if (_xoWinner != null || _xoBoard[idx] != null) return;
    if (_roomId != null && _myRole != _xoTurn) {
      _showToast('انتظر دور شريكك! 😉');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      final queue = _xoTurn == 'p1' ? _xoP1Moves : _xoP2Moves;
      if (queue.length >= 3) {
        final oldestIdx = queue.removeAt(0);
        _xoBoard[oldestIdx] = null;
      }
      queue.add(idx);
      _xoBoard[idx] = _xoTurn;

      final winLine = _checkXoWinLine(_xoBoard);
      if (winLine != null) {
        _xoWinner = _xoTurn;
        _xoWinLine = winLine;
        if (_xoTurn == 'p1') {
          _p1Score += 2;
        } else {
          _p2Score += 2;
        }
        _harmony = math.min(100, _harmony + 8);
        _burstConfetti();
      } else {
        _xoTurn = _xoTurn == 'p1' ? 'p2' : 'p1';
      }
    });
    _pushState();
  }

  List<int>? _checkXoWinLine(List<String?> b) {
    const lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (final line in lines) {
      final a = line[0], c = line[1], d = line[2];
      if (b[a] != null && b[a] == b[c] && b[a] == b[d]) {
        return line;
      }
    }
    return null;
  }

  void _resetInfiniteXo() {
    HapticFeedback.selectionClick();
    setState(() {
      _xoBoard = List<String?>.filled(9, null);
      _xoP1Moves = [];
      _xoP2Moves = [];
      _xoTurn = 'p1';
      _xoWinner = null;
      _xoWinLine = null;
    });
    _pushState();
  }

  // ─── Game Logic 4: Speed Reflex Arena (مبارزة النبض السريع) ───────────────

  void _triggerSpeedCountdown() {
    if (_speedSignal == 'wait' || _speedSignal == 'green') return;
    HapticFeedback.lightImpact();

    final isRed = math.Random().nextDouble() < 0.30;
    final delayMs = 1200 + math.Random().nextInt(1800);

    final firestore = ref.read(firestoreInstanceProvider);
    if (_roomId != null && firestore != null) {
      final evId = DateTime.now().millisecondsSinceEpoch;
      _lastHandledSpeedEventId = evId;
      firestore
          .collection(AppConstants.firestoreRoomsCollection)
          .doc(_roomId)
          .set({
            'speedEvent': {
              'id': evId,
              'type': 'START',
              'isRed': isRed,
              'delay': delayMs,
            },
          }, SetOptions(merge: true));
    }
    _runLocalSpeedSequence(isRed, delayMs);
  }

  void _handleRemoteSpeedEvent(Map<String, dynamic> ev) {
    final type = ev['type'] as String?;
    if (type == 'START') {
      final isRed = (ev['isRed'] as bool?) ?? false;
      final delay = (ev['delay'] as num?)?.toInt() ?? 1500;
      _runLocalSpeedSequence(isRed, delay);
    } else if (type == 'RESULT') {
      _speedTimer?.cancel();
      setState(() {
        _speedSignal = 'idle';
        _speedBannerText = (ev['msg'] as String?) ?? '';
        _speedBannerColor = Color(
          (ev['colorValue'] as num?)?.toInt() ?? 0xFF10B981,
        );
        _speedBannerDarkText = false;
      });
    }
  }

  void _runLocalSpeedSequence(bool isRed, int delayMs) {
    _speedTimer?.cancel();
    setState(() {
      _speedSignal = 'wait';
      _speedBannerColor = const Color(0xFFF59E0B);
      _speedBannerDarkText = false;
      _speedBannerText = '⚠️ استعد... ركّز في اللون القادم!';
    });

    _speedTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _speedStopwatch
        ..reset()
        ..start();

      if (isRed) {
        HapticFeedback.vibrate();
        setState(() {
          _speedSignal = 'red';
          _speedBannerColor = const Color(0xFFEF4444);
          _speedBannerDarkText = false;
          _speedBannerText = '🔴 فخ أحمر! لا تضغط أبداً! ⛔';
        });
        _speedTimer = Timer(const Duration(milliseconds: 1600), () {
          if (mounted && _speedSignal == 'red') {
            setState(() {
              _speedSignal = 'idle';
              _speedBannerColor = const Color(0xFFFDF2F8);
              _speedBannerDarkText = true;
              _speedBannerText = '👏 نجوتما من الفخ! اضغط لجولة جديدة';
            });
          }
        });
      } else {
        HapticFeedback.selectionClick();
        setState(() {
          _speedSignal = 'green';
          _speedBannerColor = const Color(0xFF10B981);
          _speedBannerDarkText = false;
          _speedBannerText = '🟢 أخضر! اضغط الآن فوراً!! ⚡';
        });
      }
    });
  }

  void _tapSpeedPad(String role) {
    if (_speedSignal == 'idle') return;
    _speedTimer?.cancel();
    _speedStopwatch.stop();

    final pName = role == 'p1' ? _p1Name : _p2Name;
    String msg = '';
    int colorVal = 0xFFEF4444;

    setState(() {
      if (_speedSignal == 'wait' || _speedSignal == 'red') {
        HapticFeedback.heavyImpact();
        if (role == 'p1') {
          _p1Score = math.max(0, _p1Score - 1);
        } else {
          _p2Score = math.max(0, _p2Score - 1);
        }
        msg = '❌ تسرّع $pName! (-1 نقطة) اضغط لجولة جديدة';
        colorVal = 0xFFEF4444;
      } else if (_speedSignal == 'green') {
        final sec = (_speedStopwatch.elapsedMilliseconds / 1000.0)
            .toStringAsFixed(3);
        if (role == 'p1') {
          _p1Score += 2;
        } else {
          _p2Score += 2;
        }
        _harmony = math.min(100, _harmony + 6);
        colorVal = 0xFF10B981;
        msg = '⚡ فاز $pName بزمن $sec ثانية! (+2 نقطة)';
        _burstConfetti();
      }

      _speedSignal = 'idle';
      _speedBannerText = msg;
      _speedBannerColor = Color(colorVal);
      _speedBannerDarkText = false;
    });

    final firestore = ref.read(firestoreInstanceProvider);
    if (_roomId != null && firestore != null) {
      final evId = DateTime.now().millisecondsSinceEpoch;
      _lastHandledSpeedEventId = evId;
      firestore
          .collection(AppConstants.firestoreRoomsCollection)
          .doc(_roomId)
          .set({
            'meta': _serializeMeta(),
            'speedEvent': {
              'id': evId,
              'type': 'RESULT',
              'msg': msg,
              'colorValue': colorVal,
            },
          }, SetOptions(merge: true));
    } else {
      _saveLocalState();
    }
  }

  // ─── Game Logic 5: Synced Rewards Wheel & Love Coupons Wallet ─────────────

  void _spinSyncedWheel() {
    if (_wheelSpinning || _rewards.isEmpty) return;
    HapticFeedback.mediumImpact();

    final count = _rewards.length;
    final arc = (2 * math.pi) / count;
    final winIdx = math.Random().nextInt(count);

    final targetMid = winIdx * arc + arc / 2;
    const pointerOffset = -math.pi / 2;
    const extraSpins = 6 * 2 * math.pi;
    final targetAngle =
        _wheelCurrentAngle +
        extraSpins +
        ((pointerOffset -
                targetMid -
                (_wheelCurrentAngle % (2 * math.pi)) +
                4 * math.pi) %
            (2 * math.pi));

    final spinId = DateTime.now().millisecondsSinceEpoch;
    _lastHandledSpinId = spinId;
    final earner = _myRole == 'p2' ? _p2Name : _p1Name;

    setState(() {
      _coupons.insert(
        0,
        LoveCouponItem(
          id: spinId,
          title: _rewards[winIdx].text,
          earner: earner,
          done: false,
        ),
      );
      _harmony = math.min(100, _harmony + 8);
    });

    _animateWheelTo(targetAngle, winIdx);
    _pushState();
    final oneSignal = ref.read(oneSignalServiceProvider);
    oneSignal.sendNotificationToPartner(
      title: 'قسيمة دلال جديدة في محفظتكما 🎟️🎡',
      message: 'ربح $earner قسيمة: "${_rewards[winIdx].text}" في عجلة الدلال!',
      category: 'coupon',
    );
  }

  void _animateWheelTo(double targetAngle, int winIdx) {
    _wheelStartAngle = _wheelCurrentAngle;
    _wheelTargetAngle = targetAngle;
    _wheelWinIdx = winIdx;
    _wheelSpinning = true;
    _wheelController.forward(from: 0.0);
  }

  // ─── UI Builders ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF13091C), Color(0xFF1E102A), Color(0xFF2A0F26)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF1F2), Color(0xFFFDF2F8), Color(0xFFF3E8FF)],
          );

    final unredeemedCoupons = _coupons.where((c) => !c.done).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // Background Gradient
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                decoration: BoxDecoration(gradient: bgGradient),
              ),
            ),

            // Main Content
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildCloudBar(isDark),
                        const SizedBox(height: 8),
                        _buildTopHeader(isDark, unredeemedCoupons),
                        const SizedBox(height: 8),
                        _buildHudPanel(isDark),
                        const SizedBox(height: 8),
                        _buildModeTabs(isDark),
                        const SizedBox(height: 8),
                        Expanded(child: _buildStageCard(isDark)),
                        const SizedBox(height: 8),
                        _buildReactionDock(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Flying Emojis Overlay
            ..._flyingEmojis.map((item) {
              return Positioned(
                left: MediaQuery.of(context).size.width * item.leftFraction,
                bottom: 70,
                child: IgnorePointer(
                  child: Text(item.emoji, style: const TextStyle(fontSize: 32))
                      .animate()
                      .moveY(
                        begin: 0,
                        end: -220,
                        duration: 2000.ms,
                        curve: Curves.easeOut,
                      )
                      .scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1.4, 1.4),
                        duration: 2000.ms,
                      )
                      .fadeOut(delay: 1100.ms, duration: 900.ms),
                ),
              );
            }),

            // Confetti Overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 30,
                colors: const [
                  Color(0xFFF43F5E),
                  Color(0xFF9333EA),
                  Color(0xFF10B981),
                  Color(0xFFF59E0B),
                  Color(0xFFEC4899),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudBar(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2D193F) : Colors.white;
    final dotColor = _roomId == null
        ? Colors.grey
        : (_partnerOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B));
    final statusText = _roomId == null
        ? 'الوضع: جهاز واحد (مرّر الهاتف)'
        : (_partnerOnline
              ? 'غرفة #$_roomId • شريكك متصل الآن 🟢'
              : 'غرفة #$_roomId • بانتظار الشريك ⏳');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: _roomId != null
                  ? [BoxShadow(color: dotColor, blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              statusText,
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: _showCloudModal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _roomId != null ? '#$_roomId ⚙️' : '🔗 ربط هاتفين',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF43F5E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isDark, int unredeemedCoupons) {
    final cardColor = isDark
        ? const Color(0xFF221430).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _activeTab = 'home');
              _pushState();
            },
            child: Row(
              children: [
                const Text('💞', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ثنائي المحبة 2.0',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF43F5E),
                        height: 1.15,
                      ),
                    ),
                    Text(
                      'مساحة القلوب والتناغم',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _HeaderToolBtn(
                label: '🎟️ $unredeemedCoupons',
                tooltip: 'محفظة قسائم الدلال',
                isDark: isDark,
                onTap: _showCouponsModal,
              ),
              const SizedBox(width: 5),
              _HeaderToolBtn(
                label: isDark ? '☀️' : '🕯️',
                tooltip: 'وضع السهرة الليلي',
                isDark: isDark,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setThemeMode(
                        isDark ? AppThemeMode.light : AppThemeMode.dark,
                      );
                },
              ),
              const SizedBox(width: 5),
              _HeaderToolBtn(
                label: '⚙️',
                tooltip: 'تخصيص الأسماء والمكافآت',
                isDark: isDark,
                onTap: _showSettingsModal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHudPanel(bool isDark) {
    final cardColor = isDark
        ? const Color(0xFF221430).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);

    // Determine whose turn it is for highlight
    bool p1Active = false;
    bool p2Active = false;
    if (_activeTab == 'tawafoq') {
      final guesser = _tawafoqTurn == 'p1' ? 'p2' : 'p1';
      final role = _tawafoqPhase == 'secret' ? _tawafoqTurn : guesser;
      p1Active = role == 'p1';
      p2Active = role == 'p2';
    } else if (_activeTab == 'xo' && _xoWinner == null) {
      p1Active = _xoTurn == 'p1';
      p2Active = _xoTurn == 'p2';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PlayerScoreCard(
                  emoji: '🤴',
                  name: _p1Name,
                  score: _p1Score,
                  accentColor: const Color(0xFFF43F5E),
                  isActiveTurn: p1Active,
                  isMyDevice: _roomId != null && _myRole == 'p1',
                  isDark: isDark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const Text('💖', style: TextStyle(fontSize: 20))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.18, 1.18),
                      duration: 900.ms,
                    ),
              ),
              Expanded(
                child: _PlayerScoreCard(
                  emoji: '👸',
                  name: _p2Name,
                  score: _p2Score,
                  accentColor: const Color(0xFF9333EA),
                  isActiveTurn: p2Active,
                  isMyDevice: _roomId != null && _myRole == 'p2',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'مؤشر التناغم:',
                style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 8,
                    color: isDark
                        ? const Color(0xFF39204F)
                        : const Color(0xFFFDF2F8),
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: (_harmony.clamp(10, 100)) / 100.0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFF43F5E), Color(0xFF9333EA)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_harmony%',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFF43F5E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs(bool isDark) {
    final tabs = const [
      ('home', '🏠', 'الرئيسية'),
      ('tawafoq', '💬', 'التوافق'),
      ('whosmore', '🤔', 'مين فينا؟'),
      ('xo', '⭕', 'إكس-أو'),
      ('speed', '⚡', 'السرعة'),
      ('wheel', '🎡', 'الدلال'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF221430).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: tabs.map((t) {
          final isSelected = _activeTab == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTab = t.$1);
                _pushState();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF2D193F) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.$2, style: const TextStyle(fontSize: 15)),
                    Text(
                      t.$3,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? const Color(0xFFF43F5E)
                            : (isDark ? Colors.white60 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStageCard(bool isDark) {
    final cardColor = isDark
        ? const Color(0xFF221430).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.94);

    Widget content;
    switch (_activeTab) {
      case 'tawafoq':
        content = _buildTawafoqStage(isDark);
        break;
      case 'whosmore':
        content = _buildWhosMoreStage(isDark);
        break;
      case 'xo':
        content = _buildInfiniteXoStage(isDark);
        break;
      case 'speed':
        content = _buildSpeedArenaStage(isDark);
        break;
      case 'wheel':
        content = _buildWheelStage(isDark);
        break;
      case 'home':
      default:
        content = _buildHomeLobbyStage(isDark);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF43F5E).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: content,
    );
  }

  // ─── Stage 1: Home Lobby ───────────────────────────────────────────────────

  Widget _buildHomeLobbyStage(bool isDark) {
    final modes = [
      (
        'tawafoq',
        '💬',
        'كاشف القلوب',
        'أسئلة مصنفة وتخمين سري',
        const Color(0xFFF43F5E),
      ),
      (
        'whosmore',
        '🤔',
        'تحدي مين فينا؟',
        'تصويت متزامن وكشف طريف',
        const Color(0xFF9333EA),
      ),
      (
        'xo',
        '⭕',
        'إكس-أو الذكية',
        'نظام 3 قلوب متحركة بلا تعادل!',
        const Color(0xFF10B981),
      ),
      (
        'wheel',
        '🎡',
        'عجلة وقسائم الدلال',
        'مكافآت تُحفظ في محفظتكما',
        const Color(0xFFF59E0B),
      ),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            const Text('✨💑✨', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 4),
            Text(
              'سهرة حب ومنافسة لا تُنسى!',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'اجمعوا نقاط التناغم معاً، تنافسوا في الألعاب الخمس، واربحوا قسائم الدلال!',
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: modes.map((m) {
                return InkWell(
                  onTap: () {
                    setState(() => _activeTab = m.$1);
                    _pushState();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D193F) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: m.$5.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(m.$2, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                          m.$3,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: m.$5,
                          ),
                        ),
                        Text(
                          m.$4,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        _PrimaryActionButton(
          label: '🚀 ابدأ السهرة الآن',
          onTap: () {
            setState(() => _activeTab = 'tawafoq');
            _pushState();
          },
        ),
      ],
    );
  }

  // ─── Stage 2: Tawafoq (كاشف القلوب) ───────────────────────────────────────

  Widget _buildTawafoqStage(bool isDark) {
    final list = _filteredTawafoqQuestions;
    final item = list[_tawafoqQIdx % list.length];
    final answererName = _tawafoqTurn == 'p1' ? _p1Name : _p2Name;
    final guesserRole = _tawafoqTurn == 'p1' ? 'p2' : 'p1';
    final guesserName = guesserRole == 'p1' ? _p1Name : _p2Name;

    final cats = const ['الكل', 'رومانسية', 'مواقف', 'أحلام'];
    final pillsBar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cats.map((c) {
          final active = _tawafoqCat == c;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              label: Text(
                c,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                ),
              ),
              selected: active,
              selectedColor: const Color(0xFFF43F5E),
              backgroundColor: isDark ? const Color(0xFF2D193F) : Colors.white,
              onSelected: (_) => _selectTawafoqCategory(c),
            ),
          );
        }).toList(),
      ),
    );

    // Phase 1: Secret Answer
    if (_tawafoqPhase == 'secret') {
      if (_roomId != null && _myRole != _tawafoqTurn) {
        return Column(
          children: [
            pillsBar,
            const Spacer(),
            const Text('🤫💭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 10),
            Text(
              '$answererName يختار إجابته السرية الآن...',
              style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'استعد! بمجرد أن يختار، ستظهر لك الخيارات على شاشتك لتخمّن إجابته.',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pillsBar,
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🤫 دور $answererName (إجابة سرية)',
                style: GoogleFonts.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF43F5E),
                ),
              ),
              Text(
                'قسم: ${item.category}',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D193F) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '"${item.question}"',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: item.options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (_, idx) => _OptionChoiceButton(
                text: item.options[idx],
                trailingEmoji: '👈',
                isDark: isDark,
                onTap: () => _submitTawafoqSecret(idx),
              ),
            ),
          ),
        ],
      );
    }

    // Phase 2: Pass Device (Single Phone Only)
    if (_tawafoqPhase == 'pass_device') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🤲📱', style: TextStyle(fontSize: 50)),
          const SizedBox(height: 10),
          Text(
            'مرّر الهاتف إلى $guesserName',
            style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'تم إخفاء الإجابة السرية! حان دور $guesserName ليخمن الاختيار الصحيح.',
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _PrimaryActionButton(
            label: 'أنا $guesserName، جاهز للتخمين 🎯',
            onTap: () {
              setState(() => _tawafoqPhase = 'guess');
            },
          ),
        ],
      );
    }

    // Phase 3: Guess Phase
    if (_tawafoqPhase == 'guess') {
      if (_roomId != null && _myRole != guesserRole) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🧐🎯', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 10),
            Text(
              '$guesserName يحاول تخمين إجابتك الآن!',
              style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'ترقّب النتيجة؛ ستظهر على شاشتيكما معاً فور اختياره!',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🎯 دور $guesserName في التخمين',
                style: GoogleFonts.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9333EA),
                ),
              ),
              Text(
                'ماذا اختار $answererName؟',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D193F) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF9333EA).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '"${item.question}"',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: item.options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (_, idx) => _OptionChoiceButton(
                text: item.options[idx],
                trailingEmoji: '💭',
                isDark: isDark,
                onTap: () => _submitTawafoqGuess(idx),
              ),
            ),
          ),
        ],
      );
    }

    // Phase 4: Reveal
    final matched = _tawafoqSecretPick == _tawafoqGuessPick;
    final secretText =
        (_tawafoqSecretPick != null &&
            _tawafoqSecretPick! < item.options.length)
        ? item.options[_tawafoqSecretPick!]
        : '';
    final guessText =
        (_tawafoqGuessPick != null && _tawafoqGuessPick! < item.options.length)
        ? item.options[_tawafoqGuessPick!]
        : '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(matched ? '💖🎯' : '😄💡', style: const TextStyle(fontSize: 42)),
        const SizedBox(height: 6),
        Text(
          matched
              ? 'تطابق مذهل! $guesserName يفهمك من القلب!'
              : 'فرصة جميلة لاكتشاف تفضيل جديد!',
          style: GoogleFonts.cairo(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: matched ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF10B981), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إجابة $answererName الحقيقية:',
                style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10B981),
                ),
              ),
              Text(
                '✓ $secretText',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF39204F) : const Color(0xFFFDF2F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تخمين $guesserName:',
                style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              Text(
                '${matched ? "✓" : "✗"} $guessText',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PrimaryActionButton(
          label: 'السؤال التالي وتبديل الدور 🔄',
          onTap: _nextTawafoqQuestion,
        ),
      ],
    );
  }

  // ─── Stage 3: Who's More Likely (تحدي مين فينا؟) ──────────────────────────

  Widget _buildWhosMoreStage(bool isDark) {
    final qText =
        kDefaultWhosMoreQuestions[_whosQIdx % kDefaultWhosMoreQuestions.length];
    final bothVoted = _whosP1Vote != null && _whosP2Vote != null;

    if (bothVoted) {
      final agreed = _whosP1Vote == _whosP2Vote;
      final p1Picked = _whosP1Vote == 'p1' ? _p1Name : _p2Name;
      final p2Picked = _whosP2Vote == 'p1' ? _p1Name : _p2Name;

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(agreed ? '🤝💖' : '😂⚡', style: const TextStyle(fontSize: 42)),
          const SizedBox(height: 6),
          Text(
            agreed
                ? 'اتفاق تام في الرأي! (+10% تناغم)'
                : 'اختلاف طريف! كل واحد يراها بطريقة 😂',
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: agreed ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '"$qText"',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D193F) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'تصويت $_p1Name:',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p1Picked,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFF43F5E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D193F) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'تصويت $_p2Name:',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p2Picked,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF9333EA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PrimaryActionButton(
            label: 'السؤال التالي في (مين فينا؟) ➡️',
            onTap: _nextWhosMoreQuestion,
          ),
        ],
      );
    }

    final activeVoter = _roomId != null ? _myRole : _whosLocalStep;
    final voterName = activeVoter == 'p1' ? _p1Name : _p2Name;
    final myVote = activeVoter == 'p1' ? _whosP1Vote : _whosP2Vote;

    if (_roomId != null && myVote != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⏳🤫', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(
            'تم تسجيل تصويتك السري!',
            style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'بانتظار شريكك ليصوّت من هاتفه لنكشف الإجابتين معاً...',
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF9333EA).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            'تصويت سري: دور $voterName',
            style: GoogleFonts.cairo(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF9333EA),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D193F) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            '"$qText"',
            style: GoogleFonts.cairo(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'بصراحة.. مين فينا ينطبق عليه هذا الوصف أكثر؟',
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF43F5E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _castWhosVote('p1'),
                child: Text(
                  '🤴 $_p1Name',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9333EA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _castWhosVote('p2'),
                child: Text(
                  '👸 $_p2Name',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Stage 4: Infinite 3-Heart XO ──────────────────────────────────────────

  Widget _buildInfiniteXoStage(bool isDark) {
    final turnName = _xoTurn == 'p1' ? '$_p1Name (❤️)' : '$_p2Name (💜)';
    final oldestIdxToFade = _xoWinner == null
        ? (_xoTurn == 'p1' && _xoP1Moves.length == 3
              ? _xoP1Moves.first
              : (_xoTurn == 'p2' && _xoP2Moves.length == 3
                    ? _xoP2Moves.first
                    : -1))
        : -1;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _xoWinner != null
                      ? '🏆 الفائز: ${_xoWinner == "p1" ? _p1Name : _p2Name}!'
                      : 'الدور: $turnName',
                  style: GoogleFonts.cairo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFF43F5E),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF39204F)
                        : const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '✨ أقصى حد 3 قلوب لكل لاعب',
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'عند وضع قلبك الرابع، يختفي أقدم قلب لك تلقائياً.. لا يوجد تعادل ممل بعد اليوم!',
              style: GoogleFonts.cairo(
                fontSize: 10.5,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        Center(
          child: SizedBox(
            width: 246,
            height: 246,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (_, idx) {
                final val = _xoBoard[idx];
                final isFading = idx == oldestIdxToFade;
                final isWin = _xoWinLine != null && _xoWinLine!.contains(idx);
                final symbol = val == 'p1' ? '❤️' : (val == 'p2' ? '💜' : '');

                return GestureDetector(
                  onTap: () => _playXoSlot(idx),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: isFading ? 0.45 : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isWin
                            ? const Color(0xFF10B981).withValues(alpha: 0.22)
                            : (isDark ? const Color(0xFF2D193F) : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isWin
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF43F5E).withValues(alpha: 0.25),
                          width: isWin ? 2.4 : 1.8,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(symbol, style: const TextStyle(fontSize: 32)),
                          if (isFading)
                            Positioned(
                              bottom: 3,
                              child: Text(
                                'ستختفي',
                                style: GoogleFonts.cairo(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFF43F5E),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _SecondaryActionButton(
          label: '🔄 جولة إكس-أو جديدة',
          isDark: isDark,
          onTap: _resetInfiniteXo,
        ),
      ],
    );
  }

  // ─── Stage 5: Speed Reflex Arena ───────────────────────────────────────────

  Widget _buildSpeedArenaStage(bool isDark) {
    final isCloud = _roomId != null;
    final bottomRole = isCloud && _myRole == 'p2' ? 'p2' : 'p1';
    final bottomName = bottomRole == 'p2' ? _p2Name : _p1Name;
    final bottomEmoji = bottomRole == 'p2' ? '👸' : '🤴';
    final bottomGradient = bottomRole == 'p2'
        ? const [Color(0xFFA855F7), Color(0xFF7E22CE)]
        : const [Color(0xFFF43F5E), Color(0xFFE11D48)];

    return Column(
      children: [
        Text(
          '⚡ مبارزة النبض السريع',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        Text(
          'اضغط عند ظهور الأخضر 🟢 واحذر فخ الأحمر 🔴',
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        if (!isCloud)
          Expanded(
            child: Transform.rotate(
              angle: math.pi,
              child: GestureDetector(
                onTap: () => _tapSpeedPad('p2'),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF7E22CE)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('👸', style: TextStyle(fontSize: 26)),
                      Text(
                        'منطقة $_p2Name',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _triggerSpeedCountdown,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: _speedBannerDarkText
                  ? (isDark ? const Color(0xFF39204F) : const Color(0xFFFDF2F8))
                  : _speedBannerColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                width: 1.8,
              ),
            ),
            child: Text(
              _speedBannerText,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: _speedBannerDarkText
                    ? (isDark ? Colors.white : const Color(0xFF1F2937))
                    : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _tapSpeedPad(bottomRole),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: bottomGradient),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(bottomEmoji, style: const TextStyle(fontSize: 28)),
                  Text(
                    'اضغط هنا بأقصى سرعة! ($bottomName)',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Stage 6: Rewards Wheel & Love Coupons ─────────────────────────────────

  Widget _buildWheelStage(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            Text(
              '🎡 عجلة الدلال والمكافآت المتزامنة',
              style: GoogleFonts.cairo(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'كل جائزة تربحها تتحول إلى "قسيمة دلال" في محفظتكما 🎟️',
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        Center(
          child: SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(220, 220),
                  painter: _RewardsWheelPainter(
                    rewards: _rewards,
                    angle: _wheelCurrentAngle,
                  ),
                ),
                const Positioned(
                  top: 0,
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 38,
                    color: Color(0xFFF43F5E),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF43F5E),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('🎁', style: TextStyle(fontSize: 20)),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF39204F) : const Color(0xFFFDF2F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            _wheelBannerText,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFF43F5E),
            ),
          ),
        ),
        _PrimaryActionButton(
          label: _wheelSpinning ? '🎡 جاري الدوران...' : '🎡 تدوير العجلة الآن',
          onTap: _spinSyncedWheel,
        ),
      ],
    );
  }

  Widget _buildReactionDock(bool isDark) {
    const emojis = ['❤️', '😍', '💋', '🌹', '😂', '🔥'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF221430).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'نبض فوري:',
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          ...emojis.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: InkWell(
                onTap: () => _triggerReaction(e),
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Modals: Cloud Room, Love Coupons Wallet, Settings ─────────────────────

  void _showCloudModal() {
    String? generatedPin = _roomId;
    final joinController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D193F) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '🔗 الربط السحابي الذكي (الهاتفين)',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      Text(
                        'تزامن فوري عبر Cloud Firestore: حتى لو انقطع الإنترنت لثوانٍ تبقى الغرفة والنقاط محفوظة!',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (generatedPin != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF39204F)
                                : const Color(0xFFFDF2F8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF43F5E),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'رمز الغرفة الحالية:',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              Text(
                                generatedPin!,
                                style: GoogleFonts.cairo(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 8,
                                  color: const Color(0xFFF43F5E),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: generatedPin!),
                                  );
                                  _showToast(
                                    'تم نسخ رمز الغرفة: $generatedPin 📋',
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: Text(
                                  'نسخ رمز الغرفة',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF43F5E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () async {
                                await _connectInstantSharedRoom("p1");
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: Text("⚡ اتصال مباشر ($_p1Name)", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9333EA),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () async {
                                await _connectInstantSharedRoom("p2");
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: Text("⚡ اتصال مباشر ($_p2Name)", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PrimaryActionButton(
                        label: '🤴 أو إنشاء غرفة برمز PIN خاص ($_p1Name)',
                        onTap: () async {
                          final pin = await _createCloudRoom();
                          if (pin != null) {
                            setModalState(() => generatedPin = pin);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'أو الانضمام برمز الغرفة ($_p2Name):',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: joinController,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '4829',
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF39204F)
                                    : const Color(0xFFFDF2F8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9333EA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final ok = await _joinCloudRoom(
                                joinController.text,
                              );
                              if (ok && ctx.mounted) Navigator.pop(ctx);
                            },
                            child: Text(
                              'دخول 🚀',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _SecondaryActionButton(
                        label: '📱 اللعب على هاتف واحد فقط (مرّر الهاتف)',
                        isDark: isDark,
                        onTap: () {
                          _disconnectCloudRoom();
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCouponsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D193F) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🎟️ محفظة قسائم الدلال المكتسبة',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_coupons.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'لا توجد قسائم بعد! أدر عجلة الدلال لربح قسائم مميزة 🎡',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _coupons.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final c = _coupons[idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF39204F)
                                    : const Color(0xFFFDF2F8),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(
                                    0xFFF43F5E,
                                  ).withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '🎁 ${c.title}',
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            decoration: c.done
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        Text(
                                          'لصالح: ${c.earner}',
                                          style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _coupons[idx] = c.copyWith(
                                          done: !c.done,
                                        );
                                      });
                                      setModalState(() {});
                                      _pushState();
                                    },
                                    child: Text(
                                      c.done ? 'تم التنفيذ ✅' : 'تنفيذ الآن ✨',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: c.done
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFF43F5E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsModal() {
    final p1Ctrl = TextEditingController(text: _p1Name);
    final p2Ctrl = TextEditingController(text: _p2Name);
    final rewardCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D193F) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '⚙️ تخصيص الأسماء ومحتوى السهرة',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: p1Ctrl,
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: 'اسم الشريك الأول',
                            labelStyle: GoogleFonts.cairo(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: p2Ctrl,
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: 'اسم الشريك الثاني',
                            labelStyle: GoogleFonts.cairo(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '🎁 إضافة مكافأة لعجلة الدلال (تتزامن للهاتفين):',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF43F5E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rewardCtrl,
                          style: GoogleFonts.cairo(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'مثال: فطور في السرير غداً...',
                            hintStyle: GoogleFonts.cairo(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF43F5E),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          final txt = rewardCtrl.text.trim();
                          if (txt.isEmpty) return;
                          const palette = [
                            0xFFF43F5E,
                            0xFF9333EA,
                            0xFF10B981,
                            0xFF3B82F6,
                            0xFFF59E0B,
                            0xFFEC4899,
                          ];
                          setState(() {
                            _rewards.insert(
                              0,
                              RewardWheelItem(
                                text: txt,
                                colorValue:
                                    palette[math.Random().nextInt(
                                      palette.length,
                                    )],
                              ),
                            );
                          });
                          rewardCtrl.clear();
                          _pushState();
                          _showToast('تمت إضافة المكافأة للعجلة 🎡');
                        },
                        child: const Text('➕'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PrimaryActionButton(
                    label: 'حفظ التعديلات ومزامنتها',
                    onTap: () {
                      setState(() {
                        if (p1Ctrl.text.trim().isNotEmpty) {
                          _p1Name = p1Ctrl.text.trim();
                        }
                        if (p2Ctrl.text.trim().isNotEmpty) {
                          _p2Name = p2Ctrl.text.trim();
                        }
                      });
                      Navigator.pop(ctx);
                      _pushState();
                      _showToast('تم حفظ الأسماء وتحديثها ❤️');
                    },
                  ),
                  const SizedBox(height: 8),
                  _SecondaryActionButton(
                    label: 'تصفير النقاط والبدء بجولة جديدة',
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _p1Score = 0;
                        _p2Score = 0;
                        _harmony = 25;
                      });
                      Navigator.pop(ctx);
                      _pushState();
                      _showToast('تم تصفير النقاط والبدء من جديد');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// SUB-WIDGETS & CUSTOM PAINTER FOR THE REWARDS WHEEL
// ============================================================================

class _HeaderToolBtn extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderToolBtn({
    required this.label,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D193F) : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _PlayerScoreCard extends StatelessWidget {
  final String emoji;
  final String name;
  final int score;
  final Color accentColor;
  final bool isActiveTurn;
  final bool isMyDevice;
  final bool isDark;

  const _PlayerScoreCard({
    required this.emoji,
    required this.name,
    required this.score,
    required this.accentColor,
    required this.isActiveTurn,
    required this.isMyDevice,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D193F) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isActiveTurn
                  ? accentColor
                  : accentColor.withValues(alpha: 0.25),
              width: isActiveTurn ? 2.2 : 1.5,
            ),
            boxShadow: isActiveTurn
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$score',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isMyDevice)
          Positioned(
            top: -8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'جهازي 📱',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OptionChoiceButton extends StatelessWidget {
  final String text;
  final String trailingEmoji;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionChoiceButton({
    required this.text,
    required this.trailingEmoji,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D193F) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF43F5E).withValues(alpha: 0.24),
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(trailingEmoji, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF43F5E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _SecondaryActionButton({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF43F5E),
          backgroundColor: isDark
              ? const Color(0xFF39204F)
              : const Color(0xFFFDF2F8),
          side: BorderSide(
            color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _RewardsWheelPainter extends CustomPainter {
  final List<RewardWheelItem> rewards;
  final double angle;

  _RewardsWheelPainter({required this.rewards, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    if (rewards.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final count = rewards.length;
    final sweep = (2 * math.pi) / count;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2.0;

    for (var i = 0; i < count; i++) {
      final startAngle = i * sweep;
      fillPaint.color = rewards[i].color;

      final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
      canvas.drawArc(rect, startAngle, sweep, true, fillPaint);
      canvas.drawArc(rect, startAngle, sweep, true, borderPaint);

      // Draw text label along slice
      canvas.save();
      canvas.rotate(startAngle + sweep / 2);
      final rawText = rewards[i].text;
      final shortText = rawText.length > 18
          ? '${rawText.substring(0, 16)}..'
          : rawText;

      final tp = TextPainter(
        text: TextSpan(
          text: shortText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: radius - 28);

      tp.paint(canvas, Offset(radius - tp.width - 10, -tp.height / 2));
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RewardsWheelPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.rewards.length != rewards.length;
  }
}
