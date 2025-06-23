plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // This line applies the Firebase plugin
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // This namespace is required for modern Android builds
    namespace = "com.sabag.englishapp.english_learning_app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.sabag.englishapp.english_learning_app"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
