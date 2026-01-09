import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewExample(),
    ),
  );
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

  static const platform = MethodChannel('com.asetq.apps/file_chooser');
  static const String androidClientId =
      '884256332175-ainljh42sjc4uad0l1i6qmmahpadrlns.apps.googleusercontent.com';
  static const String appUrl = 'https://aset.pncr-tech.com/';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  @override
  void initState() {
    super.initState();
    // ✅ Setup animasi untuk logo (fade pulse)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _initWebView();
    _startLoadingTimeout();
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
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

    // ✅ ENABLE CACHING untuk Android & iOS
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnShowFileSelector(_androidFilePicker);
      androidController.enableZoom(false);
      
      // ✅ AKTIFKAN CACHE MODE (PENTING!)
      // Ini akan menyimpan cache di device
    } else if (_controller.platform is WebKitWebViewController) {
      final iosController = _controller.platform as WebKitWebViewController;
      // iOS WebView otomatis cache dengan WKWebsiteDataStore
    }

    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          debugPrint('🔄 Page started: $url');
          // ✅ Hanya show loading jika pertama kali atau reload manual
          if (_isPageLoading) {
            setState(() => _isPageLoading = true);
          }
        },
        onPageFinished: (url) {
          debugPrint('✅ Page finished: $url');
          _loadingTimeout?.cancel();
          setState(() => _isPageLoading = false);
        },
        onWebResourceError: (error) {
          debugPrint('❌ Error: ${error.description}');
          _loadingTimeout?.cancel();
          setState(() => _isPageLoading = false);
        },
        onProgress: (progress) {
          debugPrint('📊 Loading: $progress%');
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
        debugPrint('📩 Message: ${message.message}');
        if (message.message == 'trigger_google_login') {
          _handleGoogleSignIn();
        }
      },
    );

    // ✅ Load URL setelah setup selesai
    _controller.loadRequest(Uri.parse(appUrl));
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    debugPrint('🎯 File picker called');
    
    try {
      final completer = Completer<List<String>>();
      
      const eventChannel = EventChannel('com.asetq.apps/file_result');
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
    _showSuccess('Login berhasil!');
  }

  Future<void> _injectSessionToWeb(Map<String, dynamic> data) async {
    final userId = data['user_id'].toString();
    final accessToken = data['access_token'].toString();
    final name = (data['name'] as String).replaceAll("'", "\\'");

    await _controller.runJavaScript('''
      (function() {
        localStorage.setItem('user_id', '$userId');
        localStorage.setItem('access_token', '$accessToken');
        localStorage.setItem('name', '$name');
        localStorage.setItem('login_time', Date.now().toString());
        
        console.log('✅ Session saved');
        
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
            // ✅ WebView
            WebViewWidget(controller: _controller),
            
            // ✅ Loading Splash - HANYA LOGO dengan animasi fade
            if (_isPageLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_animationController),
                    child: Image.asset(
                      'assets/ic_launcher.png',
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
            
            // ✅ Login Overlay (saat Google Sign In)
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