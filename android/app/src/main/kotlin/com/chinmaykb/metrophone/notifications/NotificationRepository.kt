package com.chinmaykb.metrophone.notifications

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentHashMap

object NotificationRepository {
    private val notifications = ConcurrentHashMap<String, Map<String, Any?>>()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attach(eventSink: EventChannel.EventSink) {
        sink = eventSink
        emit(mapOf("type" to "reset"))
    }

    fun detach() {
        sink = null
    }

    fun replace(values: List<Map<String, Any?>>) {
        notifications.clear()
        values.forEach { value ->
            (value["key"] as? String)?.let { notifications[it] = value }
        }
        emit(mapOf("type" to "reset"))
    }

    fun posted(value: Map<String, Any?>) {
        val key = value["key"] as? String ?: return
        notifications[key] = value
        emit(mapOf("type" to "posted", "notification" to value))
    }

    fun removed(key: String) {
        notifications.remove(key)
        emit(mapOf("type" to "removed", "key" to key))
    }

    fun clear() {
        notifications.clear()
        emit(mapOf("type" to "reset"))
    }

    fun snapshot(): List<Map<String, Any?>> =
        notifications.values.sortedByDescending { it["postedAt"] as? Long ?: 0L }

    private fun emit(event: Map<String, Any?>) {
        mainHandler.post { sink?.success(event) }
    }
}
