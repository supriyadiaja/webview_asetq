import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NotificationHandler {
  final WebViewController webViewController;

  NotificationHandler(this.webViewController);

  /// Handle notification tap and route to appropriate page
  Future<void> handleNotificationTap(RemoteMessage message) async {
    debugPrint('🎯 Handling notification tap...');
    debugPrint('Data: ${message.data}');

    final data = message.data;
    final type = data['type'] ?? '';
    final conversationId = data['conversation_id'] ?? '';
    final postId = data['post_id'] ?? '';
    final communityId = data['community_id'] ?? '';

    try {
      // Wait a bit for WebView to be ready
      await Future.delayed(const Duration(milliseconds: 500));

      String navigationTarget = '';

      switch (type) {
        case 'message':
          // Navigate to chat detail
          if (conversationId.isNotEmpty) {
            navigationTarget = 'notification-chat-detail';
            await _setSessionData('current_conversation_id', conversationId);
          }
          break;

        case 'post_comment':
        case 'comment_reply':
          // Navigate to post comments
          if (postId.isNotEmpty) {
            navigationTarget = 'forum-comments';
            await _setSessionData('currentPostId', postId);
          }
          break;

        case 'post_like':
          // Navigate to post detail (comments page)
          if (postId.isNotEmpty) {
            navigationTarget = 'forum-comments';
            await _setSessionData('currentPostId', postId);
          }
          break;

        case 'comment_like':
          // Navigate to post comments
          if (postId.isNotEmpty) {
            navigationTarget = 'forum-comments';
            await _setSessionData('currentPostId', postId);
          }
          break;

        case 'community_join_request':
        case 'community_join_approved':
        case 'community_join_rejected':
          // Navigate to community detail or my communities
          if (communityId.isNotEmpty) {
            navigationTarget = 'forum-community-detail';
            await _setSessionData('currentCommunityId', communityId);
          } else {
            navigationTarget = 'forum-my-communities';
          }
          break;

        case 'community_member_updated':
        case 'community_member_kicked':
          // Navigate to community detail
          if (communityId.isNotEmpty) {
            navigationTarget = 'forum-community-detail';
            await _setSessionData('currentCommunityId', communityId);
          }
          break;

        case 'security_pin':
          // Navigate to settings
          navigationTarget = 'settings';
          break;

        default:
          // Navigate to general notification page
          navigationTarget = 'notification';
          break;
      }

      if (navigationTarget.isNotEmpty) {
        debugPrint('🚀 Navigating to: $navigationTarget');
        await _navigateToPage(navigationTarget);
      } else {
        debugPrint('⚠️ No navigation target found');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  }

  /// Set session storage data
  Future<void> _setSessionData(String key, String value) async {
    try {
      await webViewController.runJavaScript('''
        (function() {
          sessionStorage.setItem('$key', '$value');
          console.log('✅ Set $key = $value');
        })();
      ''');
    } catch (e) {
      debugPrint('❌ Error setting session data: $e');
    }
  }

  /// Navigate to page using navigateTo function
  Future<void> _navigateToPage(String page) async {
    try {
      await webViewController.runJavaScript('''
        (function() {
          if (typeof navigateTo === 'function') {
            navigateTo('$page');
            console.log('✅ Navigated to $page');
          } else {
            console.error('❌ navigateTo function not found');
            window.location.hash = '$page';
          }
        })();
      ''');
    } catch (e) {
      debugPrint('❌ Error navigating to page: $e');
    }
  }

  /// Parse notification type from data
  static String getNotificationType(Map<String, dynamic> data) {
    return data['type']?.toString() ??
        data['notificationType']?.toString() ??
        'general';
  }

  /// Get notification page route based on type
  static String getPageRoute(String type) {
    switch (type) {
      case 'message':
        return 'notification-chat-detail';
      case 'post_comment':
      case 'comment_reply':
      case 'post_like':
      case 'comment_like':
        return 'forum-comments';
      case 'community_join_request':
      case 'community_join_approved':
      case 'community_join_rejected':
      case 'community_member_updated':
      case 'community_member_kicked':
        return 'forum-my-communities';
      case 'security_pin':
        return 'settings';
      default:
        return 'notification';
    }
  }
}
