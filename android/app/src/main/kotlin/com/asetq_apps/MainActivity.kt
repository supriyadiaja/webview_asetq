package com.asetq_apps

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Bundle
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "🚀 MainActivity created")
        
        // ✅ Initialize Firebase explicitly
        try {
            FirebaseApp.initializeApp(this)
            Log.d("MainActivity", "✅ Firebase initialized in MainActivity")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Firebase init error: ${e.message}")
        }
        
        // ✅ Get FCM token
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                val token = task.result
                Log.d("MainActivity", "✅ FCM Token: ${token.substring(0, 50)}...")
                Log.d("FCM_TOKEN", "Token: $token")
                println("FCM TOKEN: $token")
            } else {
                Log.e("MainActivity", "❌ Failed to get FCM token: ${task.exception?.message}")
            }
        }
        
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "asetq_channel"
            val channelName = "AssetQ Notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = "Channel for AssetQ notifications"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                lightColor = 0xFF6200EE.toInt()
                setSound(android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION),
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                        .build()
                )
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
            
            Log.d("MainActivity", "✅ Notification channel created: $channelId")
        }
    }
}