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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Background message handler called');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   DO NOT show notification here - FCM handles it');
  // ✅ DO NOT show notification here - it will cause double notification
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _initializeLocalNotifications();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewExample(),
    ),
  );
}

Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
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
      debugPrint('🔔 Notification tapped from local notifications');
      debugPrint('   Payload: ${response.payload}');
      // ✅ This is called when user taps notification
      // Navigation is handled by FCM listener, not here
    },
  );

  if (Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'asetq_channel',
      'AssetQ Notifications',
      description: 'Notifikasi untuk aplikasi AssetQ',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }
}

class WebViewExample extends StatefulWidget {
  const WebViewExample({super.key});

  @override
  State<WebViewExample> createState() => _WebViewExampleState();
}

class _WebViewExampleState extends State<WebViewExample>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late AnimationController _animationController;
  bool _isLoggingIn = false;
  bool _isPageLoading = true;
  Timer? _loadingTimeout;

  final FCMService _fcmService = FCMService();
  late NotificationHandler _notificationHandler;

  static const platform = MethodChannel('com.asetq_apps/file_chooser');
  static const String appUrl = 'https://aset.pncr-tech.com/';

  late GoogleSignIn _googleSignIn;

  bool _isForumSyncInjected = false;
  bool _isFCMTokenSent = false;
  String? _lastCheckedUserId;
  Timer? _fcmCheckDebounce;
  Timer? _navigationDebounce;
  String _lastNavigatedUrl = '';

  // ✅ Track if FCM listeners are already set
  bool _fcmListenersInitialized = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initializeGoogleSignIn();
    _initWebView();
    _startLoadingTimeout();
    _initializeFCM();
  }

  void _initializeGoogleSignIn() {
    _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    debugPrint('✅ GoogleSignIn initialized');
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
      if (mounted && _isPageLoading) {
        setState(() => _isPageLoading = false);
      }
    });
  }

  Future<void> _initializeFCM() async {
    try {
      await _fcmService.initialize();
      _notificationHandler = NotificationHandler(_controller);

      // ✅ ONLY set callback ONCE - no duplicate listeners
      if (!_fcmListenersInitialized) {
        _fcmService.setOnMessageTapCallback((message) {
          debugPrint('📱 Notification tapped in main');
          _notificationHandler.handleNotificationTap(message);
        });
        _fcmListenersInitialized = true;
      }

      // ✅ Check for initial message (app opened from terminated state)
      // This should be called ONLY ONCE
      await _fcmService.checkInitialMessage();

      debugPrint('✅ FCM initialized in main');
    } catch (e) {
      debugPrint('⚠️ FCM Init Error: $e');
    }
  }

  Future<void> _checkAndSendFCMToken() async {
    _fcmCheckDebounce?.cancel();

    _fcmCheckDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final userId = await _controller.runJavaScriptReturningResult(
          "localStorage.getItem('user_id')",
        );

        final userIdStr = userId.toString().replaceAll('"', '');

        if (userIdStr.isNotEmpty && userIdStr != 'null') {
          if (_lastCheckedUserId == userIdStr && _isFCMTokenSent) {
            return;
          }

          _fcmService.setUserId(userIdStr);

          final accessToken = await _controller.runJavaScriptReturningResult(
            "localStorage.getItem('access_token')",
          );

          final tokenStr = accessToken.toString().replaceAll('"', '');

          await _controller.runJavaScript('''
            (function() {
              window.currentUserId = $userIdStr;
              window.accessToken = '$tokenStr';
              window.isUserLoggedIn = true;
              
              const cachedCommunityState = localStorage.getItem('userHasJoinedCommunity');
              if (cachedCommunityState) {
                window.userHasJoinedAnyCommunity = cachedCommunityState === 'true';
              }
            })();
          ''');

          await _fcmService.sendTokenToBackend(userIdStr);

          _lastCheckedUserId = userIdStr;
          _isFCMTokenSent = true;
        } else {
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
        debugPrint('⚠️ FCM Token Check Error: $e');
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
      AndroidWebViewController.enableDebugging(false);
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnShowFileSelector(_androidFilePicker);
      androidController.enableZoom(false);

      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          return GeolocationPermissionsResponse(allow: true, retain: true);
        },
      );
    }

    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          if (_lastNavigatedUrl != url) {
            _lastNavigatedUrl = url;
            // ✅ Reset injection flag when navigating to new page
            _isForumSyncInjected = false;
          }

          if (!_isPageLoading && mounted) {
            setState(() => _isPageLoading = true);
          }
        },
        onPageFinished: (url) {
          _loadingTimeout?.cancel();
          if (mounted) {
            setState(() => _isPageLoading = false);
          }

          if (!_isFCMTokenSent) {
            _checkAndSendFCMToken();
          }

          // ✅ Always inject scripts on page finish (not just once)
          _injectForumSyncScript();
          _isForumSyncInjected = true;
        },
        onWebResourceError: (error) {
          _loadingTimeout?.cancel();
          if (mounted) {
            setState(() => _isPageLoading = false);
          }
        },
        onProgress: (progress) {
          if (progress >= 90 && _isPageLoading && mounted) {
            _loadingTimeout?.cancel();
            setState(() => _isPageLoading = false);
          }
        },
      ),
    );

    _controller.addJavaScriptChannel(
      'FlutterGoogleAuth',
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message == 'trigger_google_login') {
          _handleGoogleSignIn();
        }
      },
    );

    _controller.addJavaScriptChannel(
      'FlutterFCM',
      onMessageReceived: (JavaScriptMessage message) {
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
          debugPrint('⚠️ FlutterFCM error: $e');
        }
      },
    );

    _controller.addJavaScriptChannel(
      'FlutterCommunitySync',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          final action = data['action'];

          if (action == 'community_joined') {
            _refreshCommunityStateInWebDebounced();
          }
        } catch (e) {
          debugPrint('⚠️ FlutterCommunitySync error: $e');
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
            checkUserCommunities();
          }
        })();
      ''');
    } catch (e) {
      debugPrint('⚠️ Refresh community state error: $e');
    }
  }

  Future<void> _injectForumSyncScript() async {
    try {
      const forumSyncScript = '''
        (function() {
          if (window.forumSyncInitialized) return;

          window.initializeCommunityStateFromStorage = function() {
            try {
              const cachedState = localStorage.getItem('userHasJoinedCommunity');
              if (cachedState) {
                window.userHasJoinedAnyCommunityState = cachedState === 'true';
                return true;
              }
              return false;
            } catch (error) {
              return false;
            }
          };

          window.notifyCommunityStateChange = function(hasJoined, communityId = null) {
            try {
              localStorage.setItem('userHasJoinedCommunity', hasJoined ? 'true' : 'false');

              if (typeof FlutterCommunitySync !== 'undefined') {
                FlutterCommunitySync.postMessage(JSON.stringify({
                  action: hasJoined ? 'community_joined' : 'community_state_changed',
                  community_id: communityId,
                  has_joined: hasJoined,
                  timestamp: new Date().toISOString(),
                  user_id: window.currentUserId
                }));
              }
            } catch (error) {}
          };

          const originalCheckCommunities = window.checkUserCommunities;
          if (typeof originalCheckCommunities === 'function') {
            window.checkUserCommunities = async function() {
              await originalCheckCommunities.apply(this, arguments);
              const hasJoined = localStorage.getItem('userHasJoinedCommunity') === 'true';
              window.notifyCommunityStateChange(hasJoined);
            };
          }

          const cachedState = localStorage.getItem('userHasJoinedCommunity');
          if (cachedState !== null) {
            window.userHasJoinedAnyCommunity = cachedState === 'true';
            
            if (typeof updateFABMenu === 'function') {
              setTimeout(() => {
                updateFABMenu();
              }, 100);
            }
          } else {
            window.userHasJoinedAnyCommunity = false;
          }

          window.forumSyncInitialized = true;
        })();
      ''';

      await _controller.runJavaScript(forumSyncScript);

      // ✅ Inject Pull-to-Refresh separately after page is ready
      await _injectPullToRefresh();
    } catch (e) {
      debugPrint('⚠️ Inject forum sync error: $e');
    }
  }

  Future<void> _injectPullToRefresh() async {
    try {
      // ✅ Remove global initialization flag - reinject every time
      final pullToRefreshScript = r'''
        (function() {
          // ✅ Remove old listeners and indicator if exists
          if (window.pullToRefreshCleanup) {
            window.pullToRefreshCleanup();
          }
          
          var startY = 0;
          var currentY = 0;
          var isPulling = false;
          var refreshIndicator = null;
          
          var touchStartHandler = null;
          var touchMoveHandler = null;
          var touchEndHandler = null;
          
          function createRefreshIndicator() {
            // Remove old indicator if exists
            var oldIndicator = document.getElementById('pull-refresh-indicator');
            if (oldIndicator) {
              oldIndicator.remove();
            }
            
            refreshIndicator = document.createElement('div');
            refreshIndicator.id = 'pull-refresh-indicator';
            refreshIndicator.style.position = 'fixed';
            refreshIndicator.style.top = '-60px';
            refreshIndicator.style.left = '50%';
            refreshIndicator.style.transform = 'translateX(-50%)';
            refreshIndicator.style.width = '40px';
            refreshIndicator.style.height = '40px';
            refreshIndicator.style.background = 'white';
            refreshIndicator.style.borderRadius = '50%';
            refreshIndicator.style.boxShadow = '0 2px 8px rgba(0,0,0,0.2)';
            refreshIndicator.style.display = 'flex';
            refreshIndicator.style.alignItems = 'center';
            refreshIndicator.style.justifyContent = 'center';
            refreshIndicator.style.transition = 'top 0.3s ease';
            refreshIndicator.style.zIndex = '9999';
            refreshIndicator.style.fontSize = '24px';
            refreshIndicator.style.color = '#2196F3';
            refreshIndicator.innerHTML = '&#8635;';
            document.body.appendChild(refreshIndicator);
          }
          
          function showRefreshIndicator(progress) {
            if (!refreshIndicator) createRefreshIndicator();
            var top = Math.min(progress - 60, 20);
            refreshIndicator.style.top = top + 'px';
            
            var rotation = (progress / 80) * 360;
            refreshIndicator.style.transform = 'translateX(-50%) rotate(' + rotation + 'deg)';
          }
          
          function hideRefreshIndicator() {
            if (refreshIndicator) {
              refreshIndicator.style.top = '-60px';
              refreshIndicator.style.transform = 'translateX(-50%) rotate(0deg)';
            }
          }
          
          function triggerRefresh() {
            if (refreshIndicator) {
              refreshIndicator.innerHTML = '&#8634;';
              
              var styleEl = document.getElementById('refresh-animation');
              if (!styleEl) {
                styleEl = document.createElement('style');
                styleEl.id = 'refresh-animation';
                styleEl.textContent = '@keyframes spin { from { transform: translateX(-50%) rotate(0deg); } to { transform: translateX(-50%) rotate(360deg); } }';
                document.head.appendChild(styleEl);
              }
              
              refreshIndicator.style.animation = 'spin 1s linear infinite';
            }
            
            setTimeout(function() {
              window.location.reload();
            }, 300);
          }
          
          touchStartHandler = function(e) {
            if (window.pageYOffset === 0 || document.documentElement.scrollTop === 0) {
              startY = e.touches[0].pageY;
              isPulling = true;
            }
          };
          
          touchMoveHandler = function(e) {
            if (!isPulling) return;
            
            currentY = e.touches[0].pageY;
            var diff = currentY - startY;
            
            if (diff > 0 && (window.pageYOffset === 0 || document.documentElement.scrollTop === 0)) {
              showRefreshIndicator(diff);
              
              if (diff > 10) {
                e.preventDefault();
              }
            }
          };
          
          touchEndHandler = function(e) {
            if (!isPulling) return;
            
            var diff = currentY - startY;
            
            if (diff > 80) {
              triggerRefresh();
            } else {
              hideRefreshIndicator();
            }
            
            isPulling = false;
            startY = 0;
            currentY = 0;
          };
          
          // Add event listeners
          document.addEventListener('touchstart', touchStartHandler, { passive: true });
          document.addEventListener('touchmove', touchMoveHandler, { passive: false });
          document.addEventListener('touchend', touchEndHandler, { passive: true });
          
          // ✅ Cleanup function for re-injection
          window.pullToRefreshCleanup = function() {
            document.removeEventListener('touchstart', touchStartHandler);
            document.removeEventListener('touchmove', touchMoveHandler);
            document.removeEventListener('touchend', touchEndHandler);
            
            if (refreshIndicator && refreshIndicator.parentNode) {
              refreshIndicator.parentNode.removeChild(refreshIndicator);
            }
            refreshIndicator = null;
          };
          
          console.log('✅ Pull-to-refresh initialized');
        })();
      ''';

      await _controller.runJavaScript(pullToRefreshScript);
      debugPrint('✅ Pull-to-refresh injected');
    } catch (e) {
      debugPrint('⚠️ Inject pull-to-refresh error: $e');
    }
  }

  Future<void> _sendFCMTokenToWeb(String? token) async {
    if (token == null) return;

    try {
      await _controller.runJavaScript('''
        (function() {
          window.fcmToken = '$token';
          if (typeof window.onFCMTokenReceived === 'function') {
            window.onFCMTokenReceived('$token');
          }
        })();
      ''');
    } catch (e) {
      debugPrint('⚠️ Send FCM token to web error: $e');
    }
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      final completer = Completer<List<String>>();

      const eventChannel = EventChannel('com.asetq_apps/file_result');
      StreamSubscription? subscription;

      subscription = eventChannel.receiveBroadcastStream().listen((result) {
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

      return result;
    } catch (e) {
      debugPrint('⚠️ File picker error: $e');
      return [];
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoggingIn) return;
    if (mounted) {
      setState(() => _isLoggingIn = true);
    }

    try {
      await _googleSignIn.signOut();

      debugPrint('🔵 Starting Google Sign-In...');

      final account = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Google Sign-In timeout');
        },
      );

      if (account == null) {
        debugPrint('⚠️ User cancelled Google Sign-In');
        if (mounted) {
          setState(() => _isLoggingIn = false);
        }
        return;
      }

      debugPrint('✅ Google Sign-In successful: ${account.email}');

      await account.authentication;
      final userInfo = {
        'email': account.email,
        'name': account.displayName ?? '',
        'sub': account.id,
        'picture': account.photoUrl ?? '',
      };

      debugPrint('🔑 Auth info obtained, sending to backend...');
      await _loginToBackend(userInfo);
    } on TimeoutException catch (e) {
      _showError('Login timeout: $e');
      debugPrint('❌ Timeout Error: $e');
    } catch (e) {
      _showError('Login gagal: $e');
      debugPrint('❌ Error during sign-in: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  Future<void> _loginToBackend(Map<String, dynamic> user) async {
    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('https://aset.pncr-tech.com/api/auth-google.php'),
    );

    request.headers.set('Content-Type', 'application/x-www-form-urlencoded');

    final body =
        'email=${Uri.encodeComponent(user['email'])}'
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Future<void> _handleRefresh() async {
    debugPrint('🔄 Pull to refresh triggered...');
    try {
      await _controller.reload();
      await Future.delayed(const Duration(milliseconds: 1000));
      debugPrint('✅ Page reloaded successfully');
    } catch (e) {
      debugPrint('❌ Reload error: $e');
      _showError('Refresh failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ✅ WebView - Full screen, no wrappers blocking scroll
            WebViewWidget(controller: _controller),

            // ✅ Page Loading Splash - Only visible when loading
            if (_isPageLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: FadeTransition(
                    opacity: Tween<double>(
                      begin: 0.3,
                      end: 1.0,
                    ).animate(_animationController),
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

            // ✅ Login Loading Overlay - Only when logging in
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
                        'Logging in...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
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
