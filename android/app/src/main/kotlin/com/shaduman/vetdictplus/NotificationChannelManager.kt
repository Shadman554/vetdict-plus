package com.shaduman.vetdictplus

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

class NotificationChannelManager {
    companion object {
        private const val CHANNEL_ID = "onesignal_default"
        private const val CHANNEL_NAME = "Default"
        private const val CHANNEL_DESCRIPTION = "Default notification channel"

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                
                // Delete existing channels to recreate with new settings
                try {
                    notificationManager.deleteNotificationChannel(CHANNEL_ID)
                    notificationManager.deleteNotificationChannel("fcm_fallback_notification_channel")
                    // Don't delete system reserved channels
                } catch (e: Exception) {
                    android.util.Log.d("NotificationChannel", "Error deleting channels: $e")
                }

                // Create high priority channel for heads-up notifications
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = CHANNEL_DESCRIPTION
                    
                    // Force heads-up display
                    importance = NotificationManager.IMPORTANCE_HIGH
                    
                    // Enable lights and vibration
                    enableLights(true)
                    enableVibration(true)
                    
                    // Set vibration pattern
                    vibrationPattern = longArrayOf(0, 250, 250, 250)
                    
                    // Set sound with high priority
                    val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    val audioAttributes = AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
                        .build()
                    
                    setSound(soundUri, audioAttributes)
                    
                    // Force visibility and badges
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                    setShowBadge(true)
                    setBypassDnd(true)
                }

                notificationManager.createNotificationChannel(channel)
                
                // Create OneSignal's default channel with MAXIMUM importance for OnePlus devices
                val oneSignalChannel = NotificationChannel(
                    "fcm_fallback_notification_channel",
                    "OneSignal Notifications", 
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "OneSignal default notification channel"
                    importance = NotificationManager.IMPORTANCE_HIGH
                    enableLights(true)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500) // Stronger vibration for OnePlus
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                    setShowBadge(true)
                    setBypassDnd(true)
                    
                    // OnePlus specific settings
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        setAllowBubbles(true)
                    }
                }
                
                // Create custom high priority channel for compatibility
                val customChannel = NotificationChannel(
                    "vetstan_high_priority",
                    "VetStan High Priority",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "High priority notifications for VetStan app"
                    importance = NotificationManager.IMPORTANCE_HIGH
                    enableLights(true)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                    setShowBadge(true)
                    setBypassDnd(true)
                }
                
                notificationManager.createNotificationChannel(oneSignalChannel)
                notificationManager.createNotificationChannel(customChannel)
                
                android.util.Log.d("NotificationChannel", "Created notification channels with HIGH importance for OnePlus heads-up display")
            }
        }
    }
}
