// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewExample(),
    ));

class WebViewExample extends StatefulWidget {
  const WebViewExample({super.key});

  @override
  State<WebViewExample> createState() => _WebViewExampleState();
}

class _WebViewExampleState extends State<WebViewExample> {
  late final WebViewController _controller;
  String _lastProcessedCode = '';
  bool _isProcessingOAuth = false;

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            _handlePageFinished(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('allowing navigation to ${request.url}');
            return NavigationDecision.navigate;
          },
          onHttpError: (HttpResponseError error) {
            debugPrint('Error occurred on page: ${error.response?.statusCode}');
          },
          onUrlChange: (UrlChange change) {
            debugPrint('url change to ${change.url}');
          },
          onHttpAuthRequest: (HttpAuthRequest request) {
            openDialog(request);
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse('https://aset.pncr-tech.com/'));

    if (kIsWeb || !Platform.isMacOS) {
      controller.setBackgroundColor(const Color(0xFFFFFFFF));
    }

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }

  void _handlePageFinished(String url) {
    // ===== 1. HANDLE GOOGLE OAUTH CONSENT PAGE =====
    if (url.contains('accounts.google.com') &&
        (url.contains('signin/oauth/consent') ||
            url.contains('approvaldata_view'))) {
      debugPrint('🔍 Google OAuth consent page detected');
      
      _controller.runJavaScript('''
        (function() {
          console.log('⏳ Waiting for consent page buttons to load...');
          
          let attempts = 0;
          const maxAttempts = 20;
          
          function findAndClickButton() {
            attempts++;
            console.log('🔍 Attempt', attempts, '- Looking for buttons...');
            
            const allButtons = document.querySelectorAll('button, div[role="button"], input[type="submit"], c-wiz button, span[role="button"]');
            console.log('📋 Buttons found:', allButtons.length);
            
            if (allButtons.length === 0 && attempts < maxAttempts) {
              setTimeout(findAndClickButton, 500);
              return;
            }
            
            for (let btn of allButtons) {
              const text = (btn.textContent || btn.innerText || '').toLowerCase().trim();
              const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
              const jsaction = (btn.getAttribute('jsaction') || '').toLowerCase();
              
              const keywords = ['continue', 'allow', 'lanjutkan', 'izinkan', 'next', 'selanjutnya'];
              const hasKeyword = keywords.some(k => text.includes(k) || ariaLabel.includes(k));
              const hasSubmitAction = jsaction.includes('submit') || jsaction.includes('approve');
              
              if (hasKeyword || hasSubmitAction) {
                console.log('✅ Found consent button, clicking...', text.substring(0, 30));
                try {
                  btn.click();
                } catch(e1) {
                  try {
                    btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                  } catch(e2) {
                    console.log('⚠️ Click failed:', e2);
                  }
                }
                return;
              }
            }
            
            if (allButtons.length > 0) {
              for (let btn of allButtons) {
                const rect = btn.getBoundingClientRect();
                if (rect.width > 0 && rect.height > 0) {
                  console.log('✅ Clicking first visible button');
                  btn.click();
                  return;
                }
              }
            }
            
            if (attempts >= maxAttempts) {
              console.log('⚠️ No button found after', maxAttempts, 'attempts.');
            } else {
              setTimeout(findAndClickButton, 500);
            }
          }
          
          setTimeout(findAndClickButton, 2000);
        })();
      ''');
      return;
    }

    // ===== 2. HANDLE OAUTH CALLBACK - PROSES DI DART =====
    if (url.contains('aset.pncr-tech.com') && 
        (url.contains('?code=') || url.contains('&code='))) {
      
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'] ?? '';
      
      // Skip jika code kosong atau sudah diproses atau sedang memproses
      if (code.isEmpty || code == _lastProcessedCode || _isProcessingOAuth) {
        debugPrint('⚠️ Skipping OAuth: code=$code, last=$_lastProcessedCode, processing=$_isProcessingOAuth');
        return;
      }
      
      // Set flags
      _lastProcessedCode = code;
      _isProcessingOAuth = true;
      
      debugPrint('✅ Processing new OAuth code: ${code.substring(0, 20)}...');
      
      // Process di Dart, lalu inject hasil ke JavaScript
      _processOAuthCode(code);
      return;
    }

    // ===== 3. NORMAL PAGE - Inject OAuth handler =====
    _controller.runJavaScript('''
      (function() {
        console.log('🔧 Setting up Google OAuth handler...');
        
        var originalOpen = window.open;
        window.open = function(url, name, specs) {
          if (url && url.includes('accounts.google.com')) {
            console.log('🔀 Redirecting Google OAuth to same window');
            window.location.href = url;
            return null;
          }
          return originalOpen.call(window, url, name, specs);
        };
        
        console.log('✅ Google OAuth handler ready');
      })();
    ''');
  }

  // Process OAuth code di Dart layer
  Future<void> _processOAuthCode(String code) async {
    debugPrint('📤 Exchanging code for token...');
    
    // Inject loading modal
    _controller.runJavaScript('''
      if (typeof loadingModals === 'function') {
        loadingModals();
      }
      console.log('📤 Sending code to backend...');
    ''');
    
    try {
      // Kirim request ke backend
      final response = await _exchangeCodeForToken(code);
      
      debugPrint('📥 Backend response: ${response['status']}');
      
      if (response['status'] == 'success') {
        // Inject success handling ke JavaScript
        _controller.runJavaScript('''
          (function() {
            console.log('✅ Login successful');
            
            // Hide loading
            try {
              if (typeof jQuery !== 'undefined' && jQuery('body').loadingModal) {
                jQuery('body').loadingModal('hide').loadingModal('destroy');
              }
            } catch(e) {}
            
            // Save session
            sessionStorage.setItem('user_id', '${response['user_id']}');
            sessionStorage.setItem('access_token', '${response['access_token']}');
            sessionStorage.setItem('name', '${response['name']}');
            sessionStorage.setItem('login_time', Date.now());
            
            // Clear URL to prevent re-processing
            window.history.replaceState({}, document.title, '/#home');
            
            // Navigate to home
            console.log('🏠 Navigating to home...');
            setTimeout(() => {
              if (typeof navigateTo === 'function') {
                navigateTo('home');
              } else {
                window.location.href = '/#home';
                window.location.reload();
              }
            }, 300);
          })();
        ''');
      } else {
        // Inject error handling
        final errorMsg = response['message'] ?? 'Login failed';
        _controller.runJavaScript('''
          (function() {
            console.error('❌ Login failed: $errorMsg');
            
            try {
              if (typeof jQuery !== 'undefined' && jQuery('body').loadingModal) {
                jQuery('body').loadingModal('hide').loadingModal('destroy');
              }
            } catch(e) {}
            
            if (typeof ons !== 'undefined' && ons.notification) {
              ons.notification.toast('$errorMsg', {
                timeout: 3000,
                class: 'toast-error',
              });
            }
            
            setTimeout(() => {
              window.location.href = '/#auth-login';
            }, 1000);
          })();
        ''');
      }
    } catch (error) {
      debugPrint('❌ OAuth error: $error');
      
      _controller.runJavaScript('''
        (function() {
          console.error('❌ OAuth error: $error');
          
          try {
            if (typeof jQuery !== 'undefined' && jQuery('body').loadingModal) {
              jQuery('body').loadingModal('hide').loadingModal('destroy');
            }
          } catch(e) {}
          
          if (typeof ons !== 'undefined' && ons.notification) {
            ons.notification.toast('Authentication failed', {
              timeout: 3000,
              class: 'toast-error',
            });
          }
          
          setTimeout(() => {
            window.location.href = '/#auth-login';
          }, 1000);
        })();
      ''');
    } finally {
      // Reset processing flag
      _isProcessingOAuth = false;
    }
  }

  // HTTP request untuk exchange code
  Future<Map<String, dynamic>> _exchangeCodeForToken(String code) async {
    try {
      final HttpClient client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('https://aset.pncr-tech.com/api/auth-google.php'),
      );
      
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      
      final body = 'code=$code&redirect_uri=https://aset.pncr-tech.com/';
      request.write(body);
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      debugPrint('Backend response code: ${response.statusCode}');
      debugPrint('Backend response: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}');
      
      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        return {
          'status': 'error',
          'message': 'Backend error: ${response.statusCode}'
        };
      }
    } catch (e) {
      debugPrint('HTTP error: $e');
      return {
        'status': 'error',
        'message': 'Network error: $e'
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }

  Future<void> openDialog(HttpAuthRequest httpRequest) async {
    final TextEditingController usernameTextController =
        TextEditingController();
    final TextEditingController passwordTextController =
        TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${httpRequest.host}: ${httpRequest.realm ?? '-'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  decoration: const InputDecoration(labelText: 'Username'),
                  autofocus: true,
                  controller: usernameTextController,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Password'),
                  controller: passwordTextController,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                httpRequest.onCancel();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                httpRequest.onProceed(
                  WebViewCredential(
                    user: usernameTextController.text,
                    password: passwordTextController.text,
                  ),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Authenticate'),
            ),
          ],
        );
      },
    );
  }
}