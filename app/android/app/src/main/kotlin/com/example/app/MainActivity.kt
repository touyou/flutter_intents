package com.example.app

import dev.touyou.app_intents.AppIntentsPlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // The engine, and the AppFunctionsBridge wired to it, are created in
    // MainApplication so AppFunctions work before any activity starts.
    override fun getCachedEngineId(): String = AppIntentsPlugin.DEFAULT_ENGINE_ID
}
