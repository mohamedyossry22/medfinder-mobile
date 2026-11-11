package com.example.medfinder

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createChannels()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "medfinder/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // نغمة تنبيه لما يوصل طلب جديد والتطبيق مفتوح
                    "beep" -> {
                        try {
                            RingtoneManager.getRingtone(
                                applicationContext,
                                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            )?.play()
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }
                    "openNotificationSettings" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            )
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// قناة "الطلبات الجديدة": أهمية عالية (صوت + اهتزاز + تظهر فوق الشاشة).
    /// الباك إند بيبعت ChannelId = new_requests مع إشعار الصيدلية.
    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "new_requests",
            "طلبات الأدوية الجديدة",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "تنبيه فوري لما يوصل صيدليتك طلب دواء جديد"
            enableVibration(true)
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
