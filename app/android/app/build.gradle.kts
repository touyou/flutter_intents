import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.devtools.ksp")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.app"
        minSdk = 36
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

ksp {
    arg("appfunctions:aggregateAppFunctions", "true")
}

dependencies {
    implementation("androidx.appfunctions:appfunctions:1.0.0-alpha11")
    // appfunctions-service was not included in the alpha10 or alpha11 artifact releases
    // (it 404s on Google Maven for alpha10; alpha11 release notes omit it entirely).
    // Keep pinned to alpha09. Re-check each release cycle; if appfunctions-service is
    // permanently dropped, remove this dependency.
    implementation("androidx.appfunctions:appfunctions-service:1.0.0-alpha09")
    ksp("androidx.appfunctions:appfunctions-compiler:1.0.0-alpha11")
}

flutter {
    source = "../.."
}
