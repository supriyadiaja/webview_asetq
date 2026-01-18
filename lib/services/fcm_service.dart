import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? _userId;
  Function(RemoteMessage)? _onMessageTapCallback;

  // ✅ Track if listeners are already initialized to prevent duplicates
  static bool _listenersInitialized = false;

  String? get token => _fcmToken;

  Future<void> initialize() async {
    try {
      // ✅ Request notification permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');
      } else {
        debugPrint('⚠️ Notification permission denied');
      }

      // ✅ Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        debugPrint('✅ FCM Token obtained');
        debugPrint('   Token: $_fcmToken');
        debugPrint('   Token length: ${_fcmToken!.length}');
      } else {
        debugPrint('⚠️ Failed to get FCM token');
      }

      // ✅ Setup message handlers ONLY ONCE
      if (!_listenersInitialized) {
        _setupMessageHandlers();
        _listenersInitialized = true;
        debugPrint('✅ FCM listeners initialized');
      } else {
        debugPrint('⚠️ FCM listeners already initialized, skipping');
      }

      debugPrint('✅ FCM Service initialized successfully');
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
    }
  }

  void _setupMessageHandlers() {
    // ✅ Foreground messages - Show local notification ONLY
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground message received');
      debugPrint('   Title: ${message.notification?.title}');
      debugPrint('   Body: ${message.notification?.body}');
      debugPrint('   Data: ${message.data}');

      // ✅ Show local notification for foreground messages
      _showLocalNotification(message);
    });

    // ✅ Background message opened (app was in background/terminated)
    // DO NOT show notification here - it's already shown by FCM
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 Background message opened (app was in background)');
      debugPrint('   Data: ${message.data}');

      // ✅ Only handle navigation, NO notification display
      if (_onMessageTapCallback != null) {
        _onMessageTapCallback!(message);
      }
    });

    // ✅ Token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM Token refreshed: $newToken');
      _fcmToken = newToken;

      // ✅ Send new token to backend if user is logged in
      if (_userId != null) {
        sendTokenToBackend(_userId!);
      }
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'asetq_channel',
        'AssetQ Notifications',
        channelDescription: 'Notifikasi untuk aplikasi AssetQ',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = message.notification?.title ?? 'AssetQ';
      final body = message.notification?.body ?? 'You have a new notification';

      // ✅ Use message hashcode as unique ID to prevent duplicates
      final notificationId = message.data.hashCode;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: jsonEncode(message.data),
      );

      debugPrint('✅ Local notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  void setOnMessageTapCallback(Function(RemoteMessage) callback) {
    _onMessageTapCallback = callback;
    debugPrint('✅ Message tap callback registered');
  }

  void setUserId(String userId) {
    _userId = userId;
    debugPrint('✅ User ID set: $userId');
  }

  Future<void> sendTokenToBackend(String userId) async {
    if (_fcmToken == null) {
      debugPrint('⚠️ No FCM token available');
      return;
    }

    try {
      debugPrint('📤 Sending FCM token to backend...');
      debugPrint('   User ID: $userId');
      debugPrint('   Token: ${_fcmToken!.substring(0, 20)}...');

      final response = await http
          .post(
            Uri.parse('https://aset.pncr-tech.com/api/fcm-update.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'user_id': userId, 'fcm_token': _fcmToken!},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          debugPrint('✅ FCM token sent to backend successfully');
        } else {
          debugPrint('⚠️ Backend returned error: ${data['message']}');
        }
      } else {
        debugPrint('⚠️ HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM token: $e');
    }
  }

  Future<void> checkInitialMessage() async {
    try {
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📬 App opened from terminated state via notification');
        debugPrint('   Data: ${initialMessage.data}');

        if (_onMessageTapCallback != null) {
          // ✅ Delay to ensure WebView is ready
          Future.delayed(const Duration(milliseconds: 1000), () {
            _onMessageTapCallback!(initialMessage);
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking initial message: $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  // ✅ Clean up (call this on logout)
  Future<void> cleanup() async {
    try {
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      _userId = null;
      debugPrint('✅ FCM cleaned up');
    } catch (e) {
      debugPrint('❌ Error cleaning up FCM: $e');
    }
  }
}
