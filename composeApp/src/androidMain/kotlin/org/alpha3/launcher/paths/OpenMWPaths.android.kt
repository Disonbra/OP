package org.alpha3.launcher.paths

import android.content.Context
import android.os.Environment
import java.io.File

// Call OpenMWPathsAndroid.init(context) once from MyApp.onCreate()
object OpenMWPathsAndroid {
    lateinit var appContext: Context

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    private val filesDir: File
        get() = appContext.filesDir

    private val externalRoot: String
        get() = Environment.getExternalStorageDirectory().toString()

    private val externalFilesDir: String
        get() = appContext.getExternalFilesDir(null)?.absolutePath ?: ""
}

actual object OpenMWPaths {
    actual val RANDOM_NUM: String = "Alpha-22556"

    private val filesDir: File
        get() = OpenMWPathsAndroid.run { appContext.filesDir }

    private val externalRoot: String
        get() = OpenMWPathsAndroid.run { Environment.getExternalStorageDirectory().toString() }

    private val externalFilesDir: String
        get() = OpenMWPathsAndroid.run { appContext.getExternalFilesDir(null)?.absolutePath ?: "" }

    actual val USER_FILE_STORAGE: String =
        "$externalRoot/Alpha3"

    actual val SECOND_USER_FILE_STORAGE: String =
        externalFilesDir

    actual val USER_CONFIG: String =
        "$USER_FILE_STORAGE/config"

    actual val USER_RESOURCES: String =
        "$USER_FILE_STORAGE/resources"

    actual val USER_SAVES: String =
        "$USER_FILE_STORAGE/saves"

    actual val USER_DELTA: String =
        "$USER_FILE_STORAGE/delta"

    actual val USER_OPENMW_CFG: String =
        "$USER_CONFIG/openmw.cfg"

    actual val SETTINGS_FILE: String =
        "$USER_CONFIG/settings.cfg"

    actual val LOGCAT_FILE: String =
        "$USER_CONFIG/openmw_logcat.txt"

    actual val OPENMW_LOG: String =
        "$USER_CONFIG/openmw.log"

    actual val CRASH_FILE: String =
        "$USER_CONFIG/crash.log"

    actual val UMO_HELPER: String =
        "$USER_CONFIG/UMOhelper.sh"

    actual val DEFAULTS_BIN: String =
        File(filesDir, "config/defaults.bin").absolutePath

    actual val INTERNAL_CRASH_FILE: String =
        File(filesDir, "config/crash.log").absolutePath

    actual val OPENMW_CFG: String =
        File(filesDir, "config/openmw.cfg").absolutePath

    actual val GLOBAL_CONFIG: String =
        File(filesDir, "config").absolutePath

    actual val VERSION_STAMP: String =
        File(filesDir, "stamp").absolutePath

    actual val CACHE_DIR: String =
        Environment.getExternalStorageDirectory().toString() + "/Alpha3/OpenMW/CACHE"

    actual fun setupResources() {
        // No-op for now, assuming user provides data or it's handled elsewhere
        File(USER_RESOURCES).mkdirs()
    }
}


