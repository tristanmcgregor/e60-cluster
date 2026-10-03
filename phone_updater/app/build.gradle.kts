import java.util.Properties

plugins {
    id("com.android.application")
    kotlin("android")
}

// Build-time defaults, shared with the head unit app. The file stays out of git;
// the UI can override every value.
val updaterProps = Properties().apply {
    val f = rootProject.file("../updater/updater.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun quoted(key: String): String {
    val v = updaterProps.getProperty(key, "").trim()
    return "\"" + v.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
}

android {
    namespace = "au.jly.e60updater"
    compileSdk = 36

    defaultConfig {
        applicationId = "au.jly.e60updater"
        minSdk = 26
        // 34 keeps the classic (non edge-to-edge) window layout on Android 15.
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        buildConfigField("String", "UPDATE_KEY", quoted("update.key"))
        buildConfigField("String", "GITHUB_REPO", quoted("github.repo"))
        buildConfigField("String", "GITHUB_TOKEN", quoted("github.token"))
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}
