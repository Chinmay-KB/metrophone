package com.chinmaykb.metrophone

import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import com.chinmaykb.metrophone.notifications.MetrophoneNotificationListenerService
import com.chinmaykb.metrophone.notifications.NotificationRepository
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.Collator
import java.util.Locale
import java.util.concurrent.Executors

class LauncherBridge(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val packageManager = activity.packageManager
    private val methods = MethodChannel(messenger, METHOD_CHANNEL)
    private val events = EventChannel(messenger, EVENT_CHANNEL)
    private val worker = Executors.newSingleThreadExecutor()

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> background(result, "catalog_failed") {
                installedApps()
            }
            "getAppIcon" -> getAppIcon(call, result)
            "launchApp" -> result.success(launchApp(call))
            "getCapabilities" -> result.success(capabilities())
            "requestDefaultLauncher" -> result.success(requestDefaultLauncher())
            "openNotificationAccessSettings" ->
                result.success(openNotificationAccessSettings())
            "getActiveNotifications" ->
                result.success(NotificationRepository.snapshot())
            else -> result.notImplemented()
        }
    }

    private fun installedApps(): List<Map<String, Any?>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        }

        val seen = mutableSetOf<ComponentName>()
        val collator = Collator.getInstance(Locale.getDefault())
        return resolved.mapNotNull { info ->
            val activityInfo = info.activityInfo ?: return@mapNotNull null
            if (activityInfo.packageName == activity.packageName) return@mapNotNull null
            val component = ComponentName(activityInfo.packageName, activityInfo.name)
            if (!seen.add(component)) return@mapNotNull null
            val applicationInfo = activityInfo.applicationInfo
            mapOf(
                "packageName" to activityInfo.packageName,
                "activityName" to activityInfo.name,
                "label" to info.loadLabel(packageManager).toString(),
                "isSystemApp" to ((applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                "versionName" to versionName(activityInfo.packageName),
            )
        }.sortedWith { left, right ->
            collator.compare(left["label"] as String, right["label"] as String)
        }
    }

    private fun versionName(packageName: String): String? = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(0),
            ).versionName
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0).versionName
        }
    }.getOrNull()

    private fun getAppIcon(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")
        if (packageName.isNullOrBlank()) {
            result.error("invalid_package", "packageName is required", null)
            return
        }
        val size = (call.argument<Int>("size") ?: 144).coerceIn(48, 512)
        val monochrome = call.argument<Boolean>("monochrome") ?: false
        background(result, "icon_failed") {
            val icon = IconRenderer.render(
                drawable = packageManager.getApplicationIcon(packageName),
                size = size,
                monochrome = monochrome,
            )
            mapOf(
                "bytes" to icon.pngBytes,
                "isNativeMonochrome" to icon.isNativeMonochrome,
            )
        }
    }

    private fun launchApp(call: MethodCall): Boolean {
        val packageName = call.argument<String>("packageName") ?: return false
        val activityName = call.argument<String>("activityName") ?: return false
        return runCatching {
            activity.startActivity(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_LAUNCHER)
                    .setComponent(ComponentName(packageName, activityName))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED),
            )
            true
        }.getOrDefault(false)
    }

    private fun capabilities(): Map<String, Any> = mapOf(
        "sdkInt" to Build.VERSION.SDK_INT,
        "isDefaultLauncher" to isDefaultLauncher(),
        "canRequestHomeRole" to canRequestHomeRole(),
        "hasNotificationAccess" to hasNotificationAccess(),
        "supportsNativeMonochromeIcons" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU),
    )

    private fun canRequestHomeRole(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        val manager = activity.getSystemService(RoleManager::class.java)
        return manager.isRoleAvailable(RoleManager.ROLE_HOME)
    }

    private fun isDefaultLauncher(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val manager = activity.getSystemService(RoleManager::class.java)
            return manager.isRoleAvailable(RoleManager.ROLE_HOME) &&
                manager.isRoleHeld(RoleManager.ROLE_HOME)
        }
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        @Suppress("DEPRECATION")
        return packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo?.packageName == activity.packageName
    }

    private fun requestDefaultLauncher(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val manager = activity.getSystemService(RoleManager::class.java)
            if (!manager.isRoleAvailable(RoleManager.ROLE_HOME) ||
                manager.isRoleHeld(RoleManager.ROLE_HOME)
            ) return false
            manager.createRequestRoleIntent(RoleManager.ROLE_HOME)
        } else {
            Intent(Settings.ACTION_HOME_SETTINGS)
        }
        return startIfResolvable(intent)
    }

    private fun hasNotificationAccess(): Boolean {
        val component = notificationListenerComponent()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val manager = activity.getSystemService(NotificationManager::class.java)
            return manager.isNotificationListenerAccessGranted(component)
        }
        val enabled = Settings.Secure.getString(
            activity.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(':').any { it == component.flattenToString() }
    }

    private fun openNotificationAccessSettings(): Boolean {
        val detailIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                notificationListenerComponent().flattenToString(),
            )
        } else {
            null
        }
        if (detailIntent != null && startIfResolvable(detailIntent)) return true
        return startIfResolvable(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    private fun notificationListenerComponent() = ComponentName(
        activity,
        MetrophoneNotificationListenerService::class.java,
    )

    private fun startIfResolvable(intent: Intent): Boolean {
        if (intent.resolveActivity(packageManager) == null) return false
        activity.startActivity(intent)
        return true
    }

    private fun background(
        result: MethodChannel.Result,
        errorCode: String,
        operation: () -> Any?,
    ) {
        worker.execute {
            val outcome = runCatching(operation)
            activity.runOnUiThread {
                outcome.fold(
                    onSuccess = result::success,
                    onFailure = { result.error(errorCode, it.message, null) },
                )
            }
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        NotificationRepository.attach(sink)
    }

    override fun onCancel(arguments: Any?) {
        NotificationRepository.detach()
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        NotificationRepository.detach()
        worker.shutdownNow()
    }

    companion object {
        private const val METHOD_CHANNEL = "metrophone/launcher"
        private const val EVENT_CHANNEL = "metrophone/notifications"
    }
}
