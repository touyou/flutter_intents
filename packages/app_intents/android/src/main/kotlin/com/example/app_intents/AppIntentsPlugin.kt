package com.example.app_intents

import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Android implementation of the AppIntents Flutter plugin.
 *
 * Sets up a MethodChannel named "app_intents" and exposes a shared instance
 * for generated AppFunctions code to access the channel.
 */
class AppIntentsPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel

    companion object {
        /**
         * Shared instance for generated AppFunctions code to access.
         * Available after [onAttachedToEngine] is called.
         */
        var shared: AppIntentsPlugin? = null
            private set
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "app_intents")
        channel.setMethodCallHandler(this)
        shared = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        shared = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Returns the MethodChannel for use by generated AppFunctions code.
     *
     * The generated [AppFunctionsBridge] calls this to initialize itself
     * with the MethodChannel, enabling communication with the Dart side.
     */
    fun getChannel(): MethodChannel = channel
}
