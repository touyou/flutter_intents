package com.example.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.app_intents.AppIntentsPlugin
import com.example.app.generated.AppFunctionsBridge

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Initialize AppFunctionsBridge with the plugin's MethodChannel
        val plugin = AppIntentsPlugin.shared
        if (plugin != null) {
            AppFunctionsBridge.initialize(plugin.getChannel())
        }
    }
}
