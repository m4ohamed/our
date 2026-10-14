// lib/core/services/onesignal_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// خدمة إشعارات OneSignal والمزامنة الفورية لحالة الاتصال (Online Presence) بين الزوجين
class OneSignalService {
  final SharedPreferences _prefs;
  final FirebaseFirestore? _firestore;

  OneSignalService(this._prefs, this._firestore);

  // ─── هوية الشريك على هذا الهاتف (محمد = p1 | سارة = p2) ─────────────────

  String get myRole =>
      _prefs.getString(AppConstants.keyMyPartnerRole) ?? 'p1';

  String get partnerRole => myRole == 'p1' ? 'p2' : 'p1';

  String get myName => myRole == 'p1'
      ? AppConstants.partner1Name
      : AppConstants.partner2Name;

  String get partnerName => myRole == 'p1'
      ? AppConstants.partner2Name
      : AppConstants.partner1Name;

  Future<void> setMyRole(String role) async {
    await _prefs.setString(AppConstants.keyMyPartnerRole, role);
    await updateOnlinePresence(isOnline: true);
  }

  // ─── إعدادات OneSignal (App ID + REST API Key) ──────────────────────────

  String get appId {
    final saved = _prefs.getString(AppConstants.keyOneSignalAppId)?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    return AppConstants.defaultOneSignalAppId;
  }

  String get restApiKey {
    final saved = _prefs.getString(AppConstants.keyOneSignalRestApiKey)?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    return AppConstants.defaultOneSignalRestApiKey;
  }

  bool get isAppIdConfigured => appId.isNotEmpty;
  bool get isFullyConfigured => appId.isNotEmpty && restApiKey.isNotEmpty;

  Future<void> saveConfig({
    required String appId,
    required String restApiKey,
  }) async {
    await _prefs.setString(AppConstants.keyOneSignalAppId, appId.trim());
    await _prefs.setString(
      AppConstants.keyOneSignalRestApiKey,
      restApiKey.trim(),
    );
    await initAndRegisterDevice();
  }

  // ─── تهيئة OneSignal وتسجيل معرّف الجهاز وحالة الاتصال في Firestore ───────

  Future<void> initAndRegisterDevice() async {
    // تحديث حالة الاتصال أونلاين في Firestore دائماً
    await updateOnlinePresence(isOnline: true);

    if (kIsWeb || !isAppIdConfigured) return;

    try {
      OneSignal.initialize(appId);
      await OneSignal.Notifications.requestPermission(true);

      // تسجيل Tag باسم الشريك لسهولة الاستهداف
      OneSignal.User.addTags({'partner_role': myRole, 'partner_name': myName});

      final subId = OneSignal.User.pushSubscription.id;
      if (subId != null && subId.isNotEmpty) {
        await _saveSubscriptionIdToFirestore(subId);
      }

      OneSignal.User.pushSubscription.addObserver((state) {
        final newId = state.current.id;
        if (newId != null && newId.isNotEmpty) {
          _saveSubscriptionIdToFirestore(newId);
        }
      });
    } catch (_) {}
  }

  Future<void> _saveSubscriptionIdToFirestore(String subId) async {
    if (_firestore == null) return;
    try {
      final fieldName =
          myRole == 'p1' ? 'p1OneSignalId' : 'p2OneSignalId';
      await _firestore
          .collection(AppConstants.firestoreCoupleDoc)
          .doc('main_couple')
          .set({
            fieldName: subId,
            '${myRole}Online': true,
            '${myRole}LastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// تحديث حالة الاتصال (Online / Last Seen) في Cloud Firestore
  Future<void> updateOnlinePresence({required bool isOnline}) async {
    if (_firestore == null) return;
    try {
      await _firestore
          .collection(AppConstants.firestoreCoupleDoc)
          .doc('main_couple')
          .set({
            '${myRole}Online': isOnline,
            '${myRole}LastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ─── إرسال إشعار فوري للشريك عبر OneSignal REST API + بث Firestore ────────

  Future<bool> sendNotificationToPartner({
    required String title,
    required String message,
    String category = 'general',
  }) async {
    bool sentViaFirestore = false;
    bool sentViaOneSignal = false;

    // 1. بث الإشعار فوراً عبر Cloud Firestore ليظهر لحظياً داخل التطبيق للشريك
    if (_firestore != null) {
      try {
        await _firestore
            .collection(AppConstants.firestoreNotificationsCollection)
            .add({
              'senderRole': myRole,
              'senderName': myName,
              'targetRole': partnerRole,
              'title': title,
              'message': message,
              'category': category,
              'createdAt': FieldValue.serverTimestamp(),
              'createdAtMs': DateTime.now().millisecondsSinceEpoch,
            });
        sentViaFirestore = true;
      } catch (_) {}
    }

    // 2. إرسال Push Notification عبر OneSignal REST API ليصل لهاتف الشريك حتى لو كان التطبيق مغلقاً
    if (isFullyConfigured) {
      try {
        String? partnerSubId;
        if (_firestore != null) {
          final snap = await _firestore
              .collection(AppConstants.firestoreCoupleDoc)
              .doc('main_couple')
              .get();
          final data = snap.data();
          if (data != null) {
            final targetField =
                partnerRole == 'p1' ? 'p1OneSignalId' : 'p2OneSignalId';
            partnerSubId = data[targetField] as String?;
          }
        }

        final payload = <String, dynamic>{
          'app_id': appId,
          'headings': {'ar': title, 'en': title},
          'contents': {'ar': message, 'en': message},
          'priority': 10,
          'data': {
            'category': category,
            'senderRole': myRole,
            'senderName': myName,
          },
        };

        if (partnerSubId != null && partnerSubId.isNotEmpty) {
          payload['include_subscription_ids'] = [partnerSubId];
        } else {
          payload['included_segments'] = ['Total Subscriptions'];
        }

        final response = await http.post(
          Uri.parse('https://api.onesignal.com/notifications'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Key $restApiKey',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          sentViaOneSignal = true;
        } else {
          // محاولة بديلة بصيغة Basic Auth للتوافق مع مفاتيح OneSignal القديمة
          final fallbackRes = await http.post(
            Uri.parse('https://onesignal.com/api/v1/notifications'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Basic $restApiKey',
            },
            body: jsonEncode(payload),
          );
          sentViaOneSignal =
              fallbackRes.statusCode == 200 || fallbackRes.statusCode == 201;
        }
      } catch (_) {}
    }

    return sentViaOneSignal || sentViaFirestore;
  }
}
