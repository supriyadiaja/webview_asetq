import 'dart:async';  // ✅ TAMBAHKAN INI (untuk Completer & StreamSubscription)
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

class _WebViewExampleState extends State<WebViewExample> {
  late final WebViewController _controller;
  bool _isLoggingIn = false;

  static const platform = MethodChannel('com.asetq.apps/file_chooser');
  static const String androidClientId =
      '884256332175-ainljh42sjc4uad0l1i6qmmahpadrlns.apps.googleusercontent.com';
  static const String appUrl = 'https://aset.pncr-tech.com/';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  @override
  void initState() {
    super.initState();
    _initWebView();
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
      ..setBackgroundColor(Colors.white)
      ..loadRequest(Uri.parse(appUrl));

    _controller.addJavaScriptChannel(
      'FlutterGoogleAuth',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('📩 Message: ${message.message}');
        if (message.message == 'trigger_google_login') {
          _handleGoogleSignIn();
        }
      },
    );

    // ✅ Enable file upload untuk Android
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      
      // ✅ Set File Chooser Handler
      androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  // ✅ File Picker Handler
  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    debugPrint('🎯 File picker called');
    
    try {
      final completer = Completer<List<String>>();
      
      // Setup listener untuk hasil dari native
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
      
      // Trigger native file picker
      await platform.invokeMethod('openFileChooser');
      
      // Tunggu hasil (timeout 60 detik)
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
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoggingIn)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}