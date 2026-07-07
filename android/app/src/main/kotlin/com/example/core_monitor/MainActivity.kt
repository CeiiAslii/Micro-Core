package com.example.core_monitor

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "core_monitor/downloads"
    private val notificationChannelId = "core_monitor_alerts"
    private val notificationPermissionRequest = 901

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 1
                    val title = call.argument<String>("title") ?: "Core Monitor"
                    val body = call.argument<String>("body") ?: ""
                    showNotification(id, title, body)
                    result.success(true)
                }
                "saveTextFile" -> {
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")
                    if (fileName.isNullOrBlank() || content == null) {
                        result.error("invalid_arguments", "Nama atau isi file tidak valid.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(saveToDownloads(fileName, content))
                    } catch (error: SecurityException) {
                        result.error("storage_permission_denied", "Izin penyimpanan ditolak.", error.message)
                    } catch (error: Exception) {
                        result.error("save_failed", "Gagal menyimpan file ke Download.", error.message)
                    }
                }
                "saveBytesFile" -> {
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (fileName.isNullOrBlank() || bytes == null) {
                        result.error("invalid_arguments", "Nama atau isi file tidak valid.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(saveToDownloads(fileName, bytes))
                    } catch (error: SecurityException) {
                        result.error("storage_permission_denied", "Izin penyimpanan ditolak.", error.message)
                    } catch (error: Exception) {
                        result.error("save_failed", "Gagal menyimpan file ke Download.", error.message)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "Peringatan Router",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Peringatan router offline, resource tinggi, dan interface down."
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun requestNotificationPermission() {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationPermissionRequest,
            )
        }
    }

    private fun showNotification(id: Int, title: String, body: String) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val notification = NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(this).notify(id, notification)
    }

    private fun saveToDownloads(requestedName: String, content: String): String =
        saveToDownloads(requestedName, content.toByteArray(Charsets.UTF_8))

    private fun saveToDownloads(requestedName: String, content: ByteArray): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(requestedName, content)
        } else {
            saveLegacy(requestedName, content)
        }

    private fun saveWithMediaStore(requestedName: String, content: ByteArray): String {
        val resolver = applicationContext.contentResolver
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/Core Monitor"
        val fileName = uniqueMediaStoreName(requestedName, relativePath)
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeTypeFor(requestedName))
            put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Tidak bisa membuat file Download.")

        try {
            resolver.openOutputStream(uri, "w")?.use {
                it.write(content)
                it.flush()
            } ?: throw IllegalStateException("Tidak bisa membuka file Download.")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
        return "Download/Core Monitor/$fileName"
    }

    private fun uniqueMediaStoreName(requestedName: String, relativePath: String): String {
        val dot = requestedName.lastIndexOf('.')
        val base = if (dot > 0) requestedName.substring(0, dot) else requestedName
        val extension = if (dot > 0) requestedName.substring(dot) else ""
        var candidate = requestedName
        var index = 1
        while (true) {
            val cursor = applicationContext.contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Downloads._ID),
                "${MediaStore.Downloads.DISPLAY_NAME}=? AND ${MediaStore.Downloads.RELATIVE_PATH}=?",
                arrayOf(candidate, "$relativePath/"),
                null,
            )
            val exists = cursor?.use { it.moveToFirst() } ?: false
            if (!exists) return candidate
            candidate = "$base($index)$extension"
            index++
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(requestedName: String, content: ByteArray): String {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "Core Monitor",
        )
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Folder Download tidak dapat dibuat.")
        }
        val dot = requestedName.lastIndexOf('.')
        val base = if (dot > 0) requestedName.substring(0, dot) else requestedName
        val extension = if (dot > 0) requestedName.substring(dot) else ""
        var file = File(directory, requestedName)
        var index = 1
        while (file.exists()) {
            file = File(directory, "$base($index)$extension")
            index++
        }
        file.writeBytes(content)
        return "Download/Core Monitor/${file.name}"
    }

    private fun mimeTypeFor(fileName: String): String =
        when (fileName.substringAfterLast('.', "").lowercase()) {
            "rsc" -> "application/x-routeros-script"
            "txt", "log" -> "text/plain"
            "json" -> "application/json"
            "xml" -> "application/xml"
            "zip" -> "application/zip"
            "pdf" -> "application/pdf"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            else -> "application/octet-stream"
        }
}
