pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

// Use centralized dependency resolution with mirrors
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
        // Ensure Flutter engine artifacts (flutter_embedding_*) are resolvable
        val flutterSdkPath = java.util.Properties().let { props ->
            file("local.properties").inputStream().use { props.load(it) }
            props.getProperty("flutter.sdk")
        }
        if (flutterSdkPath != null) {
            maven(url = uri("$flutterSdkPath/bin/cache/artifacts/engine/android"))
        }
    }
}

include(":app")
