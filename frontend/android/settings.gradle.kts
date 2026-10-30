pluginManagement {
    val flutterSdkPath =
        run {
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
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")

// Transitive plugins such as image_cropper 9.1.0 still declare compileSdk 33.
// Their AndroidX dependencies require 34+, and AGP 9 locks compileSdk before
// an afterEvaluate override can change it. Raise it in the plugin script
// before Gradle evaluates the project.
gradle.beforeProject {
    if (this == rootProject) {
        return@beforeProject
    }
    val script = buildFile
    if (!script.isFile) {
        return@beforeProject
    }
    val original = script.readText()
    val updated = Regex("""compileSdk(?:Version)?(\s*=\s*|\s+)(\d+)""").replace(original) { match ->
        val sdk = match.groupValues[2].toInt()
        if (sdk < 36) match.value.replace(match.groupValues[2], "36") else match.value
    }
    if (updated != original) {
        script.writeText(updated)
    }
}
