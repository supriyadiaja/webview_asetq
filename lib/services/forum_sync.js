/**
 * Forum Sync Service - Handles synchronization between Flutter and Web Forum
 * This script should be injected into the WebView after page load
 */

(function() {
  console.log('✅ Forum Sync Service Loaded');

  // ============================================
  // COMMUNITY STATE SYNC
  // ============================================
  
  /**
   * ✅ Initialize community state from localStorage
   * Called during page initialization
   */
  window.initializeCommunityStateFromStorage = function() {
    try {
      const cachedState = localStorage.getItem('userHasJoinedCommunity');
      if (cachedState) {
        window.userHasJoinedAnyCommunityState = cachedState === 'true';
        console.log('✅ Initialized community state from localStorage:', window.userHasJoinedAnyCommunityState);
        return true;
      }
      return false;
    } catch (error) {
      console.error('❌ Error initializing community state:', error);
      return false;
    }
  };

  /**
   * ✅ Notify Flutter when community state changes
   */
  window.notifyCommunityStateChange = function(hasJoined, communityId = null) {
    try {
      // ✅ Save to localStorage FIRST
      localStorage.setItem('userHasJoinedCommunity', hasJoined ? 'true' : 'false');
      console.log('💾 Saved community state to localStorage:', hasJoined);

      // ✅ Notify Flutter (if channel is available)
      if (typeof FlutterCommunitySync !== 'undefined') {
        FlutterCommunitySync.postMessage(JSON.stringify({
          action: hasJoined ? 'community_joined' : 'community_state_changed',
          community_id: communityId,
          has_joined: hasJoined,
          timestamp: new Date().toISOString(),
          user_id: window.currentUserId
        }));
        console.log('📤 Notified Flutter about community state change');
      } else {
        console.warn('⚠️ FlutterCommunitySync channel not available');
      }
    } catch (error) {
      console.error('❌ Error notifying community state change:', error);
    }
  };

  /**
   * ✅ Override joinCommunity to include Flutter notification
   * This wraps the existing joinCommunity function
   */
  const originalJoinCommunity = window.joinCommunity;
  window.joinCommunity = async function(communityId) {
    console.log('🔵 Enhanced joinCommunity called - communityId:', communityId);

    if (!window.currentUserId) {
      ons.notification.alert('Please login to join communities');
      return;
    }

    try {
      const response = await fetch('api/join-community.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          community_id: communityId
        })
      });

      const result = await response.json();

      if (result.status === 'success') {
        // Cek apakah pending atau langsung active
        if (result.membership_status === 'pending') {
          ons.notification.toast('⏳ Join request sent! Waiting for admin approval.', {
            timeout: 4000,
            animation: 'fall'
          });
        } else {
          ons.notification.toast('✅ ' + result.message, {
            timeout: 3000,
            animation: 'fall'
          });
        }

        // ✅ CRITICAL: Force update state immediately
        delete window.communitiesChecked;
        await checkUserCommunities();
        delete window.communitiesChecked;

        // ✅ Update local state
        window.userHasJoinedAnyCommunity = true;
        
        // ✅ NOTIFY FLUTTER IMMEDIATELY
        window.notifyCommunityStateChange(true, communityId);

        // ✅ Update FAB
        if (typeof updateFABMenu === 'function') {
          updateFABMenu();
        }

        await window.loadPosts(false);

      } else if (result.status === 'info') {
        ons.notification.toast(result.message, {
          timeout: 2000
        });
      } else {
        throw new Error(result.message);
      }

    } catch (error) {
      console.error('❌ Join community error:', error);
      ons.notification.toast('Failed to join community', {
        timeout: 2000
      });
    }
  };

  /**
   * ✅ Periodically sync localStorage state with Flutter
   * Useful for keeping state in sync when user interacts with web features
   */
  window.startCommunityStateSyncTimer = function() {
    // Check every 5 seconds if state has changed
    setInterval(() => {
      try {
        const currentState = localStorage.getItem('userHasJoinedCommunity');
        const hasJoined = currentState === 'true';

        // Only notify if changed from previous state
        if (window.lastSyncedCommunityState !== hasJoined) {
          window.lastSyncedCommunityState = hasJoined;
          console.log('🔄 Community state changed, notifying Flutter...');
          window.notifyCommunityStateChange(hasJoined);
        }
      } catch (error) {
        console.error('❌ Error in sync timer:', error);
      }
    }, 5000);
  };

  /**
   * ✅ Call this when forum page loads to initialize everything
   */
  window.initializeForumSync = function() {
    console.log('🚀 Initializing Forum Sync...');
    
    // Load state from localStorage
    window.initializeCommunityStateFromStorage();
    
    // Start periodic sync
    window.startCommunityStateSyncTimer();
    
    console.log('✅ Forum Sync initialized');
  };

  // Auto-initialize when page is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      // Delay initialization to ensure forum script is loaded
      setTimeout(() => {
        window.initializeForumSync();
      }, 1000);
    });
  } else {
    setTimeout(() => {
      window.initializeForumSync();
    }, 1000);
  }

})();
