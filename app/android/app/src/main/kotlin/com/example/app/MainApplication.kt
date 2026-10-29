package com.example.app

import android.app.Application
import dev.touyou.app_intents.AppIntentsPlugin
import com.example.app.generated.AppFunctionsBridge

/**
 * Starts the Flutter engine with the process instead of with [MainActivity].
 *
 * An AppFunctions call starts the process and binds the generated service
 * without launching any activity, so the bridge has to be wired here.
 * [MainActivity] reuses this engine.
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AppIntentsPlugin.startEngine(this) { AppFunctionsBridge.initialize(it) }
    }
}
