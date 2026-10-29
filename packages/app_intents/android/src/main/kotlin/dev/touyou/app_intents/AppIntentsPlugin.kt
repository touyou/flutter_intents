package dev.touyou.app_intents

import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
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

        /** The [FlutterEngineCache] key [startEngine] uses by default. */
        const val DEFAULT_ENGINE_ID = "app_intents"

        /**
         * Starts a Flutter engine running the default Dart entrypoint, caches it
         * under [engineId] and hands its "app_intents" channel to [onChannelReady].
         *
         * Call it from `Application.onCreate`: an AppFunctions call starts the
         * process and binds the generated service without launching any activity,
         * so an engine created by the activity does not exist yet. Have the
         * activity reuse the engine by returning [engineId] from
         * `FlutterActivity.getCachedEngineId()`.
         *
         * The plugin cannot name the generated `AppFunctionsBridge`, hence the
         * callback: `startEngine(this) { AppFunctionsBridge.initialize(it) }`.
         * If an engine is already cached under [engineId], it is reused.
         */
        @JvmStatic
        @JvmOverloads
        fun startEngine(
            context: Context,
            engineId: String = DEFAULT_ENGINE_ID,
            onChannelReady: (MethodChannel) -> Unit,
        ): FlutterEngine {
            val cache = FlutterEngineCache.getInstance()
            val engine = cache.get(engineId) ?: FlutterEngine(context.applicationContext).also {
                it.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
                cache.put(engineId, it)
            }
            // FlutterEngine registers plugins in its constructor unless the app
            // opted out of automatic registration.
            val plugin = engine.plugins.get(AppIntentsPlugin::class.java) as? AppIntentsPlugin
                ?: error("AppIntentsPlugin is not registered with the engine")
            onChannelReady(plugin.getChannel())
            return engine
        }
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
            // iOS-only cache/storage APIs. Implemented as no-ops on Android so
            // cross-platform callers don't have to guard every call with
            // Platform.isIOS or swallow MissingPluginException — which is
            // particularly dangerous in release builds where
            // PlatformDispatcher.onError can silently consume the exception.
            "getCachedValue",
            "setCachedValue",
            "clearCachedValue",
            "configureStorage",
            "processPendingActions",
            // App Shortcuts are iOS-only; AppFunctions has no parameter refresh.
            "updateAppShortcutParameters" -> result.success(null)
            // The generated AppFunctionsBridge opens an execution scope for every
            // call, so a handler may ask for a value it would get prompted for on
            // iOS. AppFunctions cannot prompt: answer null (the Dart side treats it
            // as "the caller left it out") instead of failing the whole call.
            "requestIntentValue" -> result.success(null)
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
