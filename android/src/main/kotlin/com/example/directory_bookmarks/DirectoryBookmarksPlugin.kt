package com.example.directory_bookmarks

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import androidx.annotation.NonNull
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.*

class DirectoryBookmarksPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private lateinit var preferences: SharedPreferences

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.directory_bookmarks/bookmark")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        preferences = context.getSharedPreferences("directory_bookmarks", Context.MODE_PRIVATE)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            // New multi-bookmark API methods - all return UNSUPPORTED_PLATFORM
            "createBookmark" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "listBookmarks" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "getBookmark" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "bookmarkExists" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "deleteBookmark" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "updateBookmarkMetadata" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "saveFile" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "readFile" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "listFiles" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "deleteFile" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "fileExists" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "hasWritePermission" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            "requestWritePermission" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Android platform is not fully supported yet. Multi-bookmark functionality is planned for future releases.",
                    null
                )
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
