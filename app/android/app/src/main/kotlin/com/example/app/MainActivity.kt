package com.example.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // The engine, and the AppFunctionsBridge wired to it, are created in
    // MainApplication so AppFunctions work before any activity starts.
    override fun getCachedEngineId(): String = MainApplication.ENGINE_ID
}
