import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
}

kotlin {
    androidTarget {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    listOf(
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "ComposeApp"
            isStatic = true
        }
    }

    sourceSets {
        androidMain.dependencies {
            implementation(compose.preview)
            implementation(libs.androidx.activity.compose)
        }
        iosMain.dependencies {
            implementation(libs.ktor.client.darwin)
        }
        commonMain.dependencies {
            implementation(libs.core)
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.ui)
            implementation(compose.components.resources)
            implementation(compose.preview)
            implementation(libs.reorderable)
            implementation(libs.relinker)
            implementation(compose.material3)
            implementation(libs.androidx.documentfile)
            implementation(libs.androidx.lifecycle.viewmodelCompose)
            implementation(libs.androidx.lifecycle.runtimeCompose)
            implementation(libs.ktor.client.core)
            implementation(libs.ktor.client.content.negotiation)
            implementation(libs.ktor.serialization.kotlinx.json)
            implementation(libs.filekit.core)
            implementation(libs.filekit.dialogs)
            implementation(libs.filekit.dialogs.compose)
            implementation(libs.filekit.coil)
            implementation(libs.coil.compose)
            implementation(libs.coil.network.ktor)
            implementation(libs.okio)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }
    }
}

android {
    namespace = "org.alpha3.launcher"
    compileSdk = libs.versions.android.compileSdk.get().toInt()

    defaultConfig {
        applicationId = "org.alpha3.launcher"
        minSdk = libs.versions.android.minSdk.get().toInt()
        targetSdk = libs.versions.android.targetSdk.get().toInt()
        versionCode = 1
        versionName = "1.0"
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    debugImplementation(compose.uiTooling)
}

tasks.register("printIosSimulatorPath") {
    group = "help"
    description = "Prints the path to the app's data container on the iOS Simulator"
    doLast {
        val bundleId = "org.alpha3.launcher.Alpha3"
        val cmd = "xcrun simctl list devices | grep '(Booted)' | head -1 | grep -oE '[0-9A-F-]{36}'"
        val deviceId = try {
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", cmd))
            process.inputStream.bufferedReader().readText().trim()
        } catch (e: Exception) { "" }

        if (deviceId.isNotEmpty()) {
            val pathCmd = "xcrun simctl get_app_container $deviceId $bundleId data"
            val path = try {
                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", pathCmd))
                process.inputStream.bufferedReader().readText().trim()
            } catch (e: Exception) { "" }
            
            if (path.isNotEmpty()) {
                println("\n=========================================================================")
                println("IOS SIMULATOR APP DATA PATH:")
                println("Documents: $path/Documents")
                println("Config: $path/Library/Preferences/openmw")
                println("To open in Finder run:")
                println("open $path/Documents")
                println("=========================================================================\n")
            } else {
                println("App container not found for $bundleId on device $deviceId. Is the app installed?")
            }
        } else {
            println("No booted iOS Simulator found.")
        }
    }
}

