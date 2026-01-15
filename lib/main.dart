import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'services/fcm_service.dart';
import 'services/notification_handler.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ Background handler - HANYA untuk logging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  debugPrint('🔔 ========== BACKGROUND MESSAGE ==========');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   Body: ${message.notification?.body}');
  debugPrint('   Data: ${message.data}');
  debugPrint('   FCM akan otomatis menampilkan notifikasi');
  debugPrint('==========================================');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('🚀 ========== APP STARTING ==========');
  
  await Firebase.initializeApp();
  debugPrint('✅ Firebase initialized');
  
  await _initializeLocalNotifications();
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  debugPrint('✅ Background handler registered');
  
  debugPrint('====================================\n');
  
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewExample(),
    ),
  );
}

Future<void> _initializeLocalNotifications() async {
  debugPrint('🔔 Initializing local notifications...');
  
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('🔔 Notification tapped!');
      debugPrint('   Payload: ${response.payload}');
    },
  );
  
  if (Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'asetq_channel',
      'AssetQ Notifications',
      description: 'Notifikasi untuk aplikasi AssetQ',
      importance: Importance.high,
    );
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    final granted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    debugPrint('📱 Notification permission granted: $granted');
  }
  
  debugPrint('✅ Local notifications initialized with channel');
}

class WebViewExample extends StatefulWidget {
  const WebViewExample({super.key});

  @override
  State<WebViewExample> createState() => _WebViewExampleState();
}

class _WebViewExampleState extends State<WebViewExample> with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late AnimationController _animationController;
  bool _isLoggingIn = false;
  bool _isPageLoading = true;
  Timer? _loadingTimeout;
  
  final FCMService _fcmService = FCMService();
  late NotificationHandler _notificationHandler;

  static const platform = MethodChannel('com.asetq_apps/file_chooser');
  static const String androidClientId =
      '884256332175-ainljh42sjc4uad0l1i6qmmahpadrlns.apps.googleusercontent.com';
  static const String appUrl = 'https://aset.pncr-tech.com/';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  bool _isForumSyncInjected = false;
  bool _isFCMTokenSent = false;
  String? _lastCheckedUserId;
  Timer? _fcmCheckDebounce;
  Timer? _navigationDebounce;
  String _lastNavigatedUrl = '';

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _initWebView();
    _startLoadingTimeout();
    _initializeFCM();
    // ❌ REMOVED: _setupNotificationHandlers() - INI YANG BIKIN DOUBLE!
    // FCMService sudah handle semua notification events
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _fcmCheckDebounce?.cancel();
    _navigationDebounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startLoadingTimeout() {
    _loadingTimeout = Timer(const Duration(seconds: 10), () {
      if (_isPageLoading) {
        debugPrint('⏱️ Loading timeout - force hide splash');
        setState(() => _isPageLoading = false);
      }
    });
  }

  Future<void> _initializeFCM() async {
    try {
      debugPrint('🚀 Initializing FCM...');
      
      await Future.delayed(const Duration(seconds: 2));
      
      // ✅ FCMService akan setup SEMUA notification listeners (foreground, background, terminated)
      await _fcmService.initialize();
      
      _notificationHandler = NotificationHandler(_controller);
      
      // ✅ Setup callback untuk notification tap dari FCMService
      _fcmService.setOnMessageTapCallback((message) {
        _notificationHandler.handleNotificationTap(message);
      });
      
      // ✅ Setup handler untuk onMessageOpenedApp (app dari background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 App opened from BACKGROUND tap');
        _notificationHandler.handleNotificationTap(message);
      });
      
      // ✅ Setup handler untuk getInitialMessage (app dari terminated)
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('🔔 App opened from TERMINATED tap');
          _notificationHandler.handleNotificationTap(message);
        }
      });
      
      debugPrint('✅ FCM initialized successfully');
      
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
    }
  }

  Future<void> _checkAndSendFCMToken() async {
    _fcmCheckDebounce?.cancel();
    
    _fcmCheckDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await Future.delayed(const Duration(milliseconds: 800));
        
        final userId = await _controller.runJavaScriptReturningResult(
          "localStorage.getItem('user_id')"
        );
        
        final userIdStr = userId.toString().replaceAll('"', '');
        
        if (userIdStr.isNotEmpty && userIdStr != 'null') {
          if (_lastCheckedUserId == userIdStr && _isFCMTokenSent) {
            debugPrint('⚡ Skipping FCM check - already sent for user: $userIdStr');
            return;
          }
          
          debugPrint('✅ User logged in: $userIdStr');

          _fcmService.setUserId(userIdStr);
          
          final accessToken = await _controller.runJavaScriptReturningResult(
            "localStorage.getItem('access_token')"
          );
          
          final communityState = await _controller.runJavaScriptReturningResult(
            "localStorage.getItem('userHasJoinedCommunity')"
          );
          
          final tokenStr = accessToken.toString().replaceAll('"', '');
          final communityStateStr = communityState.toString().replaceAll('"', '');
          
          await _controller.runJavaScript('''
            (function() {
              window.currentUserId = $userIdStr;
              window.accessToken = '$tokenStr';
              window.isUserLoggedIn = true;
              
              const cachedCommunityState = localStorage.getItem('userHasJoinedCommunity');
              if (cachedCommunityState) {
                window.userHasJoinedAnyCommunity = cachedCommunityState === 'true';
                console.log('✅ Loaded community state from localStorage:', window.userHasJoinedAnyCommunity);
              }
              
              console.log('✅ Session injected - user ID:', window.currentUserId);
            })();
          ''');
          
          debugPrint('🔵 Community state from localStorage: $communityStateStr');
          
          await _fcmService.sendTokenToBackend(userIdStr);
          
          _lastCheckedUserId = userIdStr;
          _isFCMTokenSent = true;
          
        } else {
          debugPrint('⚠️ User not logged in yet');
          
          _lastCheckedUserId = null;
          _isFCMTokenSent = false;
          
          await _controller.runJavaScript('''
            (function() {
              window.currentUserId = null;
              window.accessToken = null;
              window.isUserLoggedIn = false;
              localStorage.removeItem('userHasJoinedCommunity');
            })();
          ''');
        }
      } catch (e) {
        debugPrint('⚠️ Could not check user login status: $e');
      }
    });
  }

  void _initWebView() {
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const {},
          )
        : const PlatformWebViewControllerCreationParams();

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36')
      ..setBackgroundColor(Colors.white);

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnShowFileSelector(_androidFilePicker);
      androidController.enableZoom(false);
      
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          return GeolocationPermissionsResponse(
            allow: true,
            retain: true,
          );
        },
      );
    }

    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          if (_lastNavigatedUrl != url) {
            debugPrint('🔄 Page started: $url');
            _lastNavigatedUrl = url;
          }
          
          if (_isPageLoading) {
            setState(() => _isPageLoading = true);
          }
        },
        onPageFinished: (url) {
          if (_lastNavigatedUrl != url) {
            debugPrint('✅ Page finished: $url');
          }
          
          _loadingTimeout?.cancel();
          setState(() => _isPageLoading = false);
          
          if (!_isFCMTokenSent) {
            _checkAndSendFCMToken();
          }
          
          if (!_isForumSyncInjected) {
            _injectForumSyncScript();
            _isForumSyncInjected = true;
          }
        },
        onWebResourceError: (error) {
          debugPrint('❌ Error: ${error.description}');
          _loadingTimeout?.cancel();
          setState(() => _isPageLoading = false);
        },
        onProgress: (progress) {
          if (progress >= 90 && _isPageLoading) {
            _loadingTimeout?.cancel();
            setState(() => _isPageLoading = false);
          }
        },
      ),
    );

    _controller.addJavaScriptChannel(
      'FlutterGoogleAuth',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('📩 Google Auth Message: ${message.message}');
        if (message.message == 'trigger_google_login') {
          _handleGoogleSignIn();
        }
      },
    );

    _controller.addJavaScriptChannel(
      'FlutterFCM',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('📩 FCM Message: ${message.message}');
        
        try {
          final data = jsonDecode(message.message);
          final action = data['action'];
          
          if (action == 'get_token') {
            final token = _fcmService.token;
            _sendFCMTokenToWeb(token);
          } else if (action == 'send_token') {
            final userId = data['user_id'];
            if (userId != null) {
              _fcmService.sendTokenToBackend(userId.toString());
            }
          }
        } catch (e) {
          debugPrint('❌ Error handling FCM message: $e');
        }
      },
    );

    _controller.addJavaScriptChannel(
      'FlutterCommunitySync',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('📩 Community Sync Message: ${message.message}');
        
        try {
          final data = jsonDecode(message.message);
          final action = data['action'];
          
          if (action == 'community_joined') {
            debugPrint('✅ Community joined detected in Flutter');
            debugPrint('   Community ID: ${data['community_id']}');
            
            _refreshCommunityStateInWebDebounced();
          } else if (action == 'update_community_state') {
            debugPrint('🔄 Updating community state in Flutter');
            debugPrint('   Has joined: ${data['has_joined']}');
          }
        } catch (e) {
          debugPrint('❌ Error handling community sync message: $e');
        }
      },
    );

    _controller.loadRequest(Uri.parse(appUrl));
  }

  void _refreshCommunityStateInWebDebounced() {
    _navigationDebounce?.cancel();
    _navigationDebounce = Timer(const Duration(milliseconds: 300), () {
      _refreshCommunityStateInWeb();
    });
  }

  Future<void> _refreshCommunityStateInWeb() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          if (typeof checkUserCommunities === 'function') {
            console.log('🔄 Calling checkUserCommunities from Flutter...');
            checkUserCommunities();
          }
        })();
      ''');
    } catch (e) {
      debugPrint('❌ Error refreshing community state: $e');
    }
  }

  Future<void> _injectForumSyncScript() async {
    try {
      debugPrint('💉 Injecting forum sync script (ONE TIME)...');
      
      const forumSyncScript = '''
        (function() {
          if (window.forumSyncInitialized) {
            console.log('⚠️ Forum sync already initialized, skipping');
            return;
          }
          
          console.log('✅ Forum Sync Service Loading...');

          window.initializeCommunityStateFromStorage = function() {
            try {
              const cachedState = localStorage.getItem('userHasJoinedCommunity');
              if (cachedState) {
                window.userHasJoinedAnyCommunityState = cachedState === 'true';
                console.log('✅ Initialized community state:', window.userHasJoinedAnyCommunityState);
                return true;
              }
              return false;
            } catch (error) {
              console.error('❌ Error initializing community state:', error);
              return false;
            }
          };

          window.notifyCommunityStateChange = function(hasJoined, communityId = null) {
            try {
              localStorage.setItem('userHasJoinedCommunity', hasJoined ? 'true' : 'false');
              console.log('💾 Saved community state:', hasJoined);

              if (typeof FlutterCommunitySync !== 'undefined') {
                FlutterCommunitySync.postMessage(JSON.stringify({
                  action: hasJoined ? 'community_joined' : 'community_state_changed',
                  community_id: communityId,
                  has_joined: hasJoined,
                  timestamp: new Date().toISOString(),
                  user_id: window.currentUserId
                }));
                console.log('📤 Notified Flutter about community state change');
              }
            } catch (error) {
              console.error('❌ Error notifying community state change:', error);
            }
          };

          const originalCheckCommunities = window.checkUserCommunities;
          if (typeof originalCheckCommunities === 'function') {
            window.checkUserCommunities = async function() {
              console.log('🔵 Enhanced checkUserCommunities called');
              await originalCheckCommunities.apply(this, arguments);
              
              const hasJoined = localStorage.getItem('userHasJoinedCommunity') === 'true';
              console.log('🔵 Result - hasJoined:', hasJoined);
              window.notifyCommunityStateChange(hasJoined);
            };
          }

          const cachedState = localStorage.getItem('userHasJoinedCommunity');
          if (cachedState !== null) {
            window.userHasJoinedAnyCommunity = cachedState === 'true';
            console.log('✅ Set window.userHasJoinedAnyCommunity =', window.userHasJoinedAnyCommunity);
            
            if (typeof updateFABMenu === 'function') {
              setTimeout(() => {
                updateFABMenu();
                console.log('✅ FAB menu updated');
              }, 100);
            }
          } else {
            window.userHasJoinedAnyCommunity = false;
          }

          window.forumSyncInitialized = true;
          console.log('✅ Forum Sync Service initialized');
        })();
      ''';

      await _controller.runJavaScript(forumSyncScript);
      debugPrint('✅ Forum sync script injected successfully');
      
    } catch (e) {
      debugPrint('❌ Error injecting forum sync script: $e');
    }
  }

  Future<void> _sendFCMTokenToWeb(String? token) async {
    if (token == null) return;
    
    try {
      await _controller.runJavaScript('''
        (function() {
          window.fcmToken = '$token';
          console.log('✅ FCM token received from Flutter');
          if (typeof window.onFCMTokenReceived === 'function') {
            window.onFCMTokenReceived('$token');
          }
        })();
      ''');
    } catch (e) {
      debugPrint('❌ Error sending token to web: $e');
    }
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    debugPrint('🎯 File picker called');
    
    try {
      final completer = Completer<List<String>>();
      
      const eventChannel = EventChannel('com.asetq_apps/file_result');
      StreamSubscription? subscription;
      
      subscription = eventChannel.receiveBroadcastStream().listen((result) {
        debugPrint('📥 Received result: $result');
        if (result is String && result.isNotEmpty) {
          completer.complete([result]);
        } else {
          completer.complete([]);
        }
        subscription?.cancel();
      });
      
      await platform.invokeMethod('openFileChooser');
      
      final result = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          subscription?.cancel();
          return [];
        },
      );
      
      debugPrint('✅ File picker result: $result');
      return result;
      
    } catch (e) {
      debugPrint('❌ File picker error: $e');
      return [];
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoggingIn) return;
    setState(() => _isLoggingIn = true);

    debugPrint('🚀 Starting Google Sign In...');

    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('❌ User cancelled');
        setState(() => _isLoggingIn = false);
        return;
      }

      debugPrint('✅ Signed in: ${account.email}');

      final auth = await account.authentication;
      final userInfo = {
        'email': account.email,
        'name': account.displayName ?? '',
        'sub': account.id,
        'picture': account.photoUrl ?? '',
      };

      await _loginToBackend(userInfo);
    } catch (e) {
      debugPrint('❌ Error: $e');
      _showError('Login gagal: $e');
    } finally {
      setState(() => _isLoggingIn = false);
    }
  }

  Future<void> _loginToBackend(Map<String, dynamic> user) async {
    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('https://aset.pncr-tech.com/api/auth-google.php'),
    );

    request.headers.set('Content-Type', 'application/x-www-form-urlencoded');

    final body = 'email=${Uri.encodeComponent(user['email'])}'
        '&name=${Uri.encodeComponent(user['name'])}'
        '&sub=${Uri.encodeComponent(user['sub'])}'
        '&picture=${Uri.encodeComponent(user['picture'])}';

    request.write(body);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody);

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Backend error');
    }

    await _injectSessionToWeb(data);
    
    final userId = data['user_id'].toString();
    
    _fcmService.setUserId(userId);
    _lastCheckedUserId = userId;
    _isFCMTokenSent = false;
    
    await _fcmService.sendTokenToBackend(userId);
    _isFCMTokenSent = true;
    
    _showSuccess('Login Successful!');
  }

  Future<void> _injectSessionToWeb(Map<String, dynamic> data) async {
    final userId = data['user_id'].toString();
    final accessToken = data['access_token'].toString();
    final name = (data['name'] as String).replaceAll("'", "\\'");

    await _controller.runJavaScript('''
      (function() {
        sessionStorage.clear();
        
        localStorage.setItem('user_id', '$userId');
        localStorage.setItem('access_token', '$accessToken');
        localStorage.setItem('name', '$name');
        localStorage.setItem('login_time', Date.now().toString());
        
        console.log('✅ Session saved to localStorage');
        console.log('   user_id:', localStorage.getItem('user_id'));
        
        sessionStorage.setItem('user_id', '$userId');
        sessionStorage.setItem('access_token', '$accessToken');
        sessionStorage.setItem('name', '$name');
        
        if (typeof navigateTo === 'function') {
          navigateTo('home');
        } else {
          window.location.hash = 'home';
        }
      })();
    ''');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            
            if (_isPageLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_animationController),
                    child: Image.asset(
                      'assets/icons/ic_launcher.png',
                      width: 120,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.app_registration,
                          size: 120,
                          color: Colors.blue,
                        );
                      },
                    ),
                  ),
                ),
              ),
            
            if (_isLoggingIn)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}