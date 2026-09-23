import java.io.File
import javax.inject.Inject
import org.gradle.process.ExecOperations
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

// --- CMake iOS Libraries Integration ---
abstract class CmakeBuildTask @Inject constructor(
    private val execOperations: ExecOperations
) : DefaultTask() {

    @get:InputFile
    abstract val cmakeListsFile: RegularFileProperty

    @get:Internal
    abstract val rootDirectory: DirectoryProperty

    @TaskAction
    fun build() {
        val root = rootDirectory.get().asFile
        val candidates = listOf("/opt/homebrew/bin/cmake", "/usr/local/bin/cmake", "cmake")
        val cmakeBin = candidates.firstOrNull { File(it).exists() && File(it).canExecute() } ?: "cmake"

        execOperations.exec {
            workingDir = root
            commandLine(cmakeBin, "-B", "$root/build", "-S", "$root", "-DIOS_PLATFORMS=SIMULATORARM64")
        }

        execOperations.exec {
            workingDir = root
            commandLine(cmakeBin, "--build", "$root/build")
        }

        execOperations.exec {
            workingDir = root
            commandLine(cmakeBin, "--build", "$root/build", "--target", "stage_libs")
        }
    }
}

val buildCmakeLibs = tasks.register("buildCmakeLibs", CmakeBuildTask::class.java) {
    group = "build"
    description = "Configures, builds, and stages CMake dependencies for OpenMW iOS"
    cmakeListsFile.set(rootProject.file("CMakeLists.txt"))
    rootDirectory.set(rootProject.rootDir)
}

tasks.matching { task ->
    task.name.startsWith("link") && task.name.contains("Framework") ||
    task.name.startsWith("embedAndSignAppleFramework")
}.configureEach {
    dependsOn(buildCmakeLibs)
}
