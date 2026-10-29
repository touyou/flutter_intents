package com.example.app

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import dev.touyou.app_intents.AppIntentsPlugin
import com.example.app.generated.AppFunctionsBridge

/**
 * Starts the Flutter engine with the process instead of with [MainActivity].
 *
 * An AppFunctions call starts the process and binds the generated service
 * without launching any activity. If the engine were created by the activity,
 * the bridge would have no MethodChannel and the call would fail with
 * "AppFunctionsBridge not initialized". [MainActivity] reuses this engine.
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)

        AppIntentsPlugin.shared?.let { AppFunctionsBridge.initialize(it.getChannel()) }
    }

    companion object {
        const val ENGINE_ID = "main"
    }
}
