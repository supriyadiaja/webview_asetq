package com.asetq_apps

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log
import kotlin.random.Random

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d("FCM_SERVICE", "╔════════════════════════════════════════╗")
        Log.d("FCM_SERVICE", "║ ✅✅✅ onMessageReceived CALLED ✅✅✅ ║")
        Log.d("FCM_SERVICE", "╚════════════════════════════════════════╝")
        
        Log.d("FCM_SERVICE", "From: ${remoteMessage.from}")
        Log.d("FCM_SERVICE", "Message ID: ${remoteMessage.messageId}")
        Log.d("FCM_SERVICE", "Sent Time: ${remoteMessage.sentTime}")
        Log.d("FCM_SERVICE", "TTL: ${remoteMessage.ttl}")
        
        // ✅ Log notification object
        if (remoteMessage.notification != null) {
            Log.d("FCM_SERVICE", "📬 HAS NOTIFICATION OBJECT:")
            Log.d("FCM_SERVICE", "   Title: ${remoteMessage.notification?.title}")
            Log.d("FCM_SERVICE", "   Body: ${remoteMessage.notification?.body}")
            Log.d("FCM_SERVICE", "   ClickAction: ${remoteMessage.notification?.clickAction}")
            Log.d("FCM_SERVICE", "   Tag: ${remoteMessage.notification?.tag}")
            Log.d("FCM_SERVICE", "   Color: ${remoteMessage.notification?.color}")
            Log.d("FCM_SERVICE", "   Icon: ${remoteMessage.notification?.icon}")
        } else {
            Log.d("FCM_SERVICE", "⚠️ NO NOTIFICATION OBJECT")
        }
        
        // ✅ Log all data
        if (remoteMessage.data.isNotEmpty()) {
            Log.d("FCM_SERVICE", "📦 DATA PAYLOAD (${remoteMessage.data.size} items):")
            remoteMessage.data.forEach { (key, value) ->
                Log.d("FCM_SERVICE", "   $key = $value")
            }
        } else {
            Log.d("FCM_SERVICE", "⚠️ NO DATA PAYLOAD")
        }
        
        // ✅ Always ensure channel exists
        ensureNotificationChannelExists()
        
        // ✅ Process message
        if (remoteMessage.notification != null) {
            val title = remoteMessage.notification?.title ?: "AssetQ"
            val body = remoteMessage.notification?.body ?: "New notification"
            showNotification(title, body, remoteMessage.data)
        } else if (remoteMessage.data.isNotEmpty()) {
            val title = remoteMessage.data["title"] ?: "AssetQ"
            val body = remoteMessage.data["body"] ?: "New notification"
            showNotification(title, body, remoteMessage.data)
        } else {
            Log.d("FCM_SERVICE", "⚠️ Message has no content to display")
        }
        
        Log.d("FCM_SERVICE", "╔════════════════════════════════════════╗")
        Log.d("FCM_SERVICE", "║ PROCESSING COMPLETE                    ║")
        Log.d("FCM_SERVICE", "╚════════════════════════════════════════╝")
    }

    private fun ensureNotificationChannelExists() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "asetq_channel"
            
            val existing = notificationManager.getNotificationChannel(channelId)
            
            if (existing == null) {
                Log.d("FCM_SERVICE", "🔧 Creating notification channel...")
                
                val channel = NotificationChannel(
                    channelId,
                    "AssetQ Notifications",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Channel for AssetQ notifications"
                    enableVibration(true)
                    enableLights(true)
                    setShowBadge(true)
                    lightColor = 0xFF6200EE.toInt()
                }
                
                notificationManager.createNotificationChannel(channel)
                Log.d("FCM_SERVICE", "✅ Channel created successfully")
            } else {
                Log.d("FCM_SERVICE", "✅ Channel already exists")
            }
        }
    }

    private fun showNotification(title: String, body: String, data: Map<String, String> = emptyMap()) {
        Log.d("FCM_SERVICE", "🎯 showNotification() called")
        Log.d("FCM_SERVICE", "   Title: '$title'")
        Log.d("FCM_SERVICE", "   Body: '$body'")
        
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("notification_source", "FCM")
                data.forEach { (key, value) ->
                    putExtra(key, value)
                }
            }
            
            val notificationId = Random.nextInt(Int.MAX_VALUE)
            Log.d("FCM_SERVICE", "🔧 Using notification ID: $notificationId")
            
            val pendingIntent = PendingIntent.getActivity(
                this, 
                notificationId,
                intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            val notificationBuilder = NotificationCompat.Builder(this, "asetq_channel")
                .setSmallIcon(android.R.drawable.ic_dialog_info) // ✅ SAFE FALLBACK
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 500, 250, 500))
                .setLights(0xFF6200EE.toInt(), 1000, 500)
                .setSound(android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION))

            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            Log.d("FCM_SERVICE", "📢 Calling notificationManager.notify()...")
            notificationManager.notify(notificationId, notificationBuilder.build())
            
            Log.d("FCM_SERVICE", "╔════════════════════════════════════════╗")
            Log.d("FCM_SERVICE", "║ ✅✅✅ NOTIFICATION DISPLAYED ✅✅✅   ║")
            Log.d("FCM_SERVICE", "║ ID: $notificationId                     ║")
            Log.d("FCM_SERVICE", "║ Title: $title               ║")
            Log.d("FCM_SERVICE", "╚════════════════════════════════════════╝")
            
        } catch (e: Exception) {
            Log.e("FCM_SERVICE", "❌ ERROR: ${e.message}")
            Log.e("FCM_SERVICE", "Stacktrace: ${Log.getStackTraceString(e)}")
        }
    }

    override fun onNewToken(token: String) {
        Log.d("FCM_SERVICE", "🔄 New FCM token received: ${token.substring(0, 50)}...")
    }
}