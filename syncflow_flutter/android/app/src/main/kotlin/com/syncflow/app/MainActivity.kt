package com.syncflow.app

import android.app.AlarmManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.AlarmClock
import android.provider.Settings
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CATEGORY_APP_CLOCK = "android.intent.category.APP_CLOCK"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "syncflow/system"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAlarmComposer" -> {
                    val title = call.argument<String>("title").orEmpty()
                    val hour = call.argument<Int>("hour") ?: 0
                    val minute = call.argument<Int>("minute") ?: 0
                    result.success(openAlarmComposer(title, hour, minute))
                }
                "openNotificationSettings" -> {
                    result.success(openNotificationSettings())
                }
                "openExactAlarmSettings" -> {
                    result.success(openExactAlarmSettings())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openAlarmComposer(title: String, hour: Int, minute: Int): Boolean {
        val setAlarmIntent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_MESSAGE, title)
            putExtra(AlarmClock.EXTRA_HOUR, hour)
            putExtra(AlarmClock.EXTRA_MINUTES, minute)
            putExtra(AlarmClock.EXTRA_SKIP_UI, false)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        if (launchResolvedIntent(setAlarmIntent)) {
            return true
        }

        val clockAppIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(CATEGORY_APP_CLOCK)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        if (launchResolvedIntent(clockAppIntent)) {
            return true
        }

        val knownClockPackages = listOf(
            "com.google.android.deskclock",
            "com.android.deskclock",
            "com.miui.clock",
            "com.coloros.alarmclock",
            "com.oneplus.deskclock",
            "com.sec.android.app.clockpackage",
            "com.huawei.deskclock"
        )

        for (pkg in knownClockPackages) {
            val launchIntent = packageManager.getLaunchIntentForPackage(pkg)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            if (launchIntent != null && launchIntentSafely(launchIntent)) {
                return true
            }
        }

        val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return launchIntentSafely(fallbackIntent)
    }

    private fun openNotificationSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        }
        return launchIntentSafely(intent)
    }

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (alarmManager.canScheduleExactAlarms()) {
                return true
            }

            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            }
            if (launchIntentSafely(intent)) {
                return true
            }
        }

        val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        return launchIntentSafely(fallbackIntent)
    }

    private fun launchResolvedIntent(intent: Intent): Boolean {
        val matches = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }

        for (match in matches) {
            val activityInfo = match.activityInfo ?: continue
            val targetedIntent = Intent(intent).apply {
                setClassName(activityInfo.packageName, activityInfo.name)
            }
            if (launchIntentSafely(targetedIntent)) {
                return true
            }
        }
        return false
    }

    private fun launchIntentSafely(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
