
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Career Buddy LMS production release signing.
// The upload keystore and key.properties must remain private.
// Never fall back to debug signing for release builds.

val keystorePropertiesFile = rootProject.file("key.properties")

require(keystorePropertiesFile.exists()) {
    "Missing android/key.properties. Release signing is required."
}

val keystoreProperties = Properties().apply {
    keystorePropertiesFile.inputStream().use { load(it) }
}

android {
    namespace = "com.career.buddy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.career.buddy"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?.takeIf { it.isNotBlank() }
                ?: error("Missing keyAlias in android/key.properties")

            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?.takeIf { it.isNotBlank() }
                ?: error("Missing keyPassword in android/key.properties")

            storeFile = keystoreProperties.getProperty("storeFile")
                ?.takeIf { it.isNotBlank() }
                ?.let { file(it) }
                ?: error("Missing storeFile in android/key.properties")

            storePassword = keystoreProperties.getProperty("storePassword")
                ?.takeIf { it.isNotBlank() }
                ?: error("Missing storePassword in android/key.properties")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
