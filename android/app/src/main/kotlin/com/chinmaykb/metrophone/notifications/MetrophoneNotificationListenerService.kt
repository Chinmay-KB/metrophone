package com.chinmaykb.metrophone.notifications

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class MetrophoneNotificationListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        val current = runCatching { activeNotifications.toList() }.getOrDefault(emptyList())
        NotificationRepository.replace(current.map(::toSnapshot))
    }

    override fun onNotificationPosted(notification: StatusBarNotification) {
        if (notification.packageName == packageName) return
        NotificationRepository.posted(toSnapshot(notification))
    }

    override fun onNotificationRemoved(notification: StatusBarNotification) {
        NotificationRepository.removed(notification.key)
    }

    override fun onListenerDisconnected() {
        NotificationRepository.clear()
        super.onListenerDisconnected()
    }

    private fun toSnapshot(status: StatusBarNotification): Map<String, Any?> {
        val notification = status.notification
        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = (
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_SUB_TEXT)
            )?.toString()
        return mapOf(
            "key" to status.key,
            "packageName" to status.packageName,
            "postedAt" to status.postTime,
            "isOngoing" to ((notification.flags and Notification.FLAG_ONGOING_EVENT) != 0),
            "title" to title,
            "text" to text,
            "category" to notification.category,
        )
    }
}
