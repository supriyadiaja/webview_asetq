import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  String? _fcmToken;
  String? _userId;
  Function(RemoteMessage)? _onMessageTapCallback;
  
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  String? get token => _fcmToken;
  String? get userId => _userId;

  void setUserId(String userId) {
    _userId = userId;
    debugPrint('💾 FCMService userId set: $userId');
  }

  Future<void> initialize() async {
    try {
      debugPrint('🚀 Initializing FCM Service...');

      // ✅ Initialize local notifications
      await _initializeLocalNotifications();

      // ✅ Request notification permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ Notification permission provisional');
      } else {
        debugPrint('❌ Notification permission denied');
        return;
      }

      // ✅ Get FCM token
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        debugPrint('✅ FCM Token obtained');
        debugPrint('   Token: ${_fcmToken!.substring(0, min(50, _fcmToken!.length))}...');
        debugPrint('   Token length: ${_fcmToken!.length}');
      } else {
        debugPrint('❌ Failed to get FCM token');
      }

      // ✅ Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed');
        debugPrint('   Old token: ${_fcmToken?.substring(0, min(30, _fcmToken?.length ?? 0)) ?? "null"}...');
        debugPrint('   New token: ${newToken.substring(0, min(30, newToken.length))}...');
        debugPrint('   Current userId: $_userId');
        
        _fcmToken = newToken;
        
        if (_userId != null && _userId!.isNotEmpty) {
          _sendTokenToBackend(newToken, userId: _userId);
        } else {
          debugPrint('⚠️ Token refreshed but no userId available. Will send when user logs in.');
        }
      });

      // ✅ CRITICAL: HANYA INI yang handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // ✅ Handle notification tap (background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // ✅ Check if app opened from notification (terminated state)
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📬 App opened from notification (terminated state)');
        _handleNotificationTap(initialMessage);
      }

      debugPrint('✅ FCM Service initialized successfully');
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            final message = RemoteMessage(
              data: Map<String, String>.from(data),
            );
            _handleNotificationTap(message);
          } catch (e) {
            debugPrint('❌ Error parsing notification payload: $e');
          }
        }
      },
    );

    // ✅ Create notification channel
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'asetq_channel',
        'AssetQ Notifications',
        description: 'Notifikasi untuk aplikasi AssetQ',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    debugPrint('✅ Local notifications initialized');
  }

  // ✅ FIXED: Ini SATU-SATUNYA tempat yang show foreground notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 ========== FOREGROUND MESSAGE ==========');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');
    debugPrint('   Showing notification NOW...');
    debugPrint('=========================================');

    // ✅ Show local notification (HANYA SEKALI)
    await _showLocalNotification(message);
  }

  // ✅ Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      debugPrint('📱 _showLocalNotification START');
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'asetq_channel',
        'AssetQ Notifications',
        channelDescription: 'Notifikasi untuk aplikasi AssetQ',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = message.hashCode;
      debugPrint('📱 Notification ID: $notificationId');
      
      await _localNotifications.show(
        notificationId,
        message.notification?.title ?? 'AssetQ',
        message.notification?.body ?? 'New notification',
        notificationDetails,
        payload: jsonEncode(message.data),
      );
      
      debugPrint('✅ Local notification displayed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error showing notification: $e');
      debugPrint('   Stack trace: $stackTrace');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped');
    debugPrint('   Data: ${message.data}');

    if (_onMessageTapCallback != null) {
      _onMessageTapCallback!(message);
    }
  }

  void setOnMessageTapCallback(Function(RemoteMessage) callback) {
    _onMessageTapCallback = callback;
  }

  Future<bool> sendTokenToBackend(String userId) async {
    _userId = userId;
    debugPrint('📱 sendTokenToBackend called with userId: $userId');
    
    if (_fcmToken == null || _fcmToken!.isEmpty) {
      debugPrint('⚠️ No FCM token to send yet. Will send when token is available.');
      return false;
    }

    return await _sendTokenToBackend(_fcmToken!, userId: userId);
  }

  Future<bool> _sendTokenToBackend(String token, {String? userId}) async {
    try {
      final uid = userId ?? _userId ?? await _getUserIdFromStorage();
      
      if (uid == null || uid.isEmpty) {
        debugPrint('⚠️ No user_id available, skipping token send');
        debugPrint('   Explicit userId: $userId');
        debugPrint('   Stored _userId: $_userId');
        return false;
      }

      debugPrint('📤 Sending FCM token to backend...');
      debugPrint('   User ID: $uid');
      debugPrint('   Token: ${token.substring(0, min(50, token.length))}...');
      debugPrint('   Token length: ${token.length}');

      final url = 'https://aset.pncr-tech.com/api/fcm/save-fcm-token.php';
      final body = {
        'user_id': uid,
        'fcm_token': token,
        'device_type': Platform.isAndroid ? 'android' : 'ios',
      };

      debugPrint('📤 URL: $url');
      debugPrint('📦 Request body: $body');

      final response = await http.post(
        Uri.parse(url),
        body: body,
      ).timeout(const Duration(seconds: 10));

      debugPrint('📥 Status Code: ${response.statusCode}');
      debugPrint('📥 Raw Response Body: ${response.body}');

      if (!response.body.trim().startsWith('{')) {
        debugPrint('❌ Invalid JSON response - not JSON format');
        debugPrint('   Response preview: ${response.body.substring(0, min(200, response.body.length))}');
        return false;
      }

      final result = jsonDecode(response.body);
      debugPrint('📥 Parsed Response: $result');

      if (result['status'] == 'success') {
        debugPrint('✅ FCM token sent successfully!');
        debugPrint('   Action: ${result['action']}');
        debugPrint('   Message: ${result['message']}');
        return true;
      } else {
        debugPrint('❌ Failed to send FCM token');
        debugPrint('   Status: ${result['status']}');
        debugPrint('   Message: ${result['message']}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception sending FCM token: $e');
      debugPrint('   Stack trace: $stackTrace');
      return false;
    }
  }

  Future<String?> _getUserIdFromStorage() async {
    debugPrint('🔍 _getUserIdFromStorage called, returning: $_userId');
    return _userId;
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Failed to subscribe to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Failed to unsubscribe from topic: $e');
    }
  }

  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      _fcmToken = null;
      _userId = null;
      debugPrint('✅ FCM token deleted and userId cleared');
    } catch (e) {
      debugPrint('❌ Failed to delete FCM token: $e');
    }
  }
}