// phone-agent: a text-only tool-calling agent on LiteRT-LM that drives real phone actions
// (alarm, timer, calendar) from a local .litertlm. First model: Spark-X2.5-1.7B.
plugins {
    id("com.android.application")
}

val litertlmVersion: String = providers.gradleProperty("litertlmVersion").get()
val coroutinesVersion: String = providers.gradleProperty("coroutinesVersion").get()

android {
    namespace = "io.github.johnrocky.phoneagent"
    compileSdk = 36
    defaultConfig {
        applicationId = "io.github.johnrocky.phoneagent"
        minSdk = 31
        targetSdk = 36
        versionCode = 1
        versionName = "0.1"
        ndk { abiFilters += setOf("arm64-v8a") }
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("com.google.ai.edge.litertlm:litertlm-android:$litertlmVersion")
    // >= 1.11.0: the runtime's Conversation calls SendChannel.close$default (LiteRT-LM #3334).
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:$coroutinesVersion")
    implementation("androidx.activity:activity:1.10.1")
    implementation("com.google.code.gson:gson:2.11.0")
}
