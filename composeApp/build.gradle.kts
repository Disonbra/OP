import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
}

// Provide defaults for Xcode properties to avoid "no value available" errors
project.extra.set("kotlin.native.apple.archs", project.findProperty("kotlin.native.apple.archs") ?: "arm64")
project.extra.set("kotlin.native.apple.target", project.findProperty("kotlin.native.apple.target") ?: "iphoneos")
project.extra.set("kotlin.native.apple.configuration", project.findProperty("kotlin.native.apple.configuration") ?: "Debug")

// Provide defaults for Xcode properties to avoid "no value available" errors
// This is necessary because the Compose plugin tries to read these even when not building from Xcode
project.extra.set("kotlin.native.apple.archs", project.findProperty("kotlin.native.apple.archs") ?: "arm64")
project.extra.set("kotlin.native.apple.target", project.findProperty("kotlin.native.apple.target") ?: "iphoneos")
project.extra.set("kotlin.native.apple.configuration", project.findProperty("kotlin.native.apple.configuration") ?: "Debug")

// Targeted fix for the SyncComposeResourcesForIosTask crash
tasks.matching { it.name.contains("syncComposeResources", ignoreCase = true) }.configureEach {
    try {
        val getXcodeTargetArchs = this.javaClass.getMethod("getXcodeTargetArchs")
        val archs = getXcodeTargetArchs.invoke(this) as? org.gradle.api.provider.ListProperty<String>
        archs?.convention(listOf("arm64"))
    } catch (e: Exception) {
        // Fallback: if we can't set the convention, just disable the task
        enabled = false
    }
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


val iosTargets = listOf(
    "ios_toolchain",
    "icu_host",
    "icu",
    "bzip2",
    "luajit",
    "zlib",
    "libpng",
    "freetype",
    "libxml2",
    "libjpeg-turbo",
    "openal",
    "boost",
    "iconv",
    "liblzma",
    "ffmpeg",
    "sdl2",
    "bullet",
    "mygui",
    "lz4",
    "libogg",
    "vorbis",
    "collada",
    "glslang",
    "spirv-cross",
    "osg",
    "openmw"
)
val iosTargetsString = iosTargets.joinToString(" ")

val buildIosDepsDevice = tasks.register<Exec>("buildIosDepsDevice") {
    group = "build"
    description = "Builds iOS C++ dependencies for ARM64 Device (OS64) using CMake target by target"
    val projectDir = rootProject.projectDir
    val buildDir = file("${projectDir}/ios_build/build_device")
    val sourceDir = file("${projectDir}/buildscripts")
    workingDir = projectDir
    commandLine(
        "sh", "-c",
        "cmake -B \"$buildDir\" -S \"$sourceDir\" -DIOS_PLATFORM=OS64 && for t in $iosTargetsString; do echo \"=== Building target: \$t ===\" && cmake --build \"$buildDir\" --config Release --target \"\$t\" || exit 1; done"
    )
}

val buildIosDepsSim = tasks.register<Exec>("buildIosDepsSim") {
    group = "build"
    description = "Builds iOS C++ dependencies for Simulator (SIMULATORARM64) using CMake target by target"
    val projectDir = rootProject.projectDir
    val buildDir = file("${projectDir}/ios_build/build_sim")
    val sourceDir = file("${projectDir}/buildscripts")
    workingDir = projectDir
    commandLine(
        "sh", "-c",
        "cmake -B \"$buildDir\" -S \"$sourceDir\" -DIOS_PLATFORM=SIMULATORARM64 && for t in $iosTargetsString; do echo \"=== Building target: \$t ===\" && cmake --build \"$buildDir\" --config Release --target \"\$t\" || exit 1; done"
    )
}

tasks.register("buildIosDeps") {
    group = "build"
    description = "Builds iOS C++ dependencies for both Device and Simulator using CMake"
    dependsOn(buildIosDepsDevice, buildIosDepsSim)
}

val cleanIosDeps = tasks.register<Delete>("cleanIosDeps") {
    group = "build"
    description = "Cleans CMake build directories for iOS dependencies"
    delete(
        file("${rootProject.projectDir}/ios_build/build_device"),
        file("${rootProject.projectDir}/ios_build/build_sim"),
        file("${rootProject.projectDir}/build_cmake_os64"),
        file("${rootProject.projectDir}/build_cmake_sim")
    )
}

tasks.named("clean") {
    dependsOn(cleanIosDeps)
}

tasks.matching { task -> task.name.contains("IosArm64") && !task.name.contains("Simulator") }.configureEach {
    if (name.startsWith("compileKotlin") || name.startsWith("link") || name.startsWith("embedAndSign")) {
        dependsOn(buildIosDepsDevice)
    }
}

tasks.matching { task -> task.name.contains("IosSimulatorArm64") }.configureEach {
    if (name.startsWith("compileKotlin") || name.startsWith("link") || name.startsWith("embedAndSign")) {
        dependsOn(buildIosDepsSim)
    }
}

tasks.register("printIosDeviceInfo") {
    group = "help"
    description = "Prints information about connected iOS Simulators and physical devices"
    doLast {
        val bundleId = "org.alpha3.launcher.Alpha3"
        
        println("\n--- iOS Simulator ---")
        val simCmd = "xcrun simctl list devices | grep '(Booted)' | head -1 | grep -oE '[0-9A-F-]{36}'"
        val simId = try {
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", simCmd))
            process.inputStream.bufferedReader().readText().trim()
        } catch (e: Exception) { "" }

        if (simId.isNotEmpty()) {
            val pathCmd = "xcrun simctl get_app_container $simId $bundleId data"
            val path = try {
                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", pathCmd))
                process.inputStream.bufferedReader().readText().trim()
            } catch (e: Exception) { "" }
            
            if (path.isNotEmpty()) {
                println("Booted Simulator ID: $simId")
                println("App Documents Path: $path/Documents")
                println("App Support Path:   $path/Library/Application Support/Alpha3")
                println("Resources Path:     $path/Library/Application Support/Alpha3/resources")
                println("\nTo open Resources in Finder run:")
                println("open \"$path/Library/Application Support/Alpha3/resources\"")
            } else {
                println("Booted Simulator: $simId (App not installed)")
            }
        } else {
            println("No booted iOS Simulator found.")
        }

        println("\n--- Physical iOS Devices ---")
        val deviceCmd = "xcrun devicectl list devices --hide-headers --columns identifier,model,name"
        val devices = try {
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", deviceCmd))
            process.inputStream.bufferedReader().readText().trim()
        } catch (e: Exception) { "" }

        if (devices.isNotEmpty() && !devices.contains("No devices found")) {
            println(devices)
            println("\nTo install on device, use:")
            println("buildscripts/install_on_device.sh")
        } else {
            println("No physical iOS devices detected via USB/Network.")
        }
        println("")
    }
}

