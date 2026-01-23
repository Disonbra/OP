@file:OptIn(ExperimentalForeignApi::class)

package org.alpha3.launcher.paths

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.memScoped
import platform.Foundation.*

fun listFilesInDirectory(path: String): List<String> {
    val fileManager = NSFileManager.defaultManager
    val contents = fileManager.contentsOfDirectoryAtPath(path, null) ?: return emptyList()
    return contents.map { it.toString() }
}

private fun documentsDir(): String =
    NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory,
        NSUserDomainMask,
        true
    ).first() as String

private fun appSupportDir(): String =
    NSSearchPathForDirectoriesInDomains(
        NSApplicationSupportDirectory,
        NSUserDomainMask,
        true
    ).first() as String

private fun cachesDir(): String =
    NSSearchPathForDirectoriesInDomains(
        NSCachesDirectory,
        NSUserDomainMask,
        true
    ).first() as String

private fun ensureDir(path: String) {
    val fileManager = NSFileManager.defaultManager
    memScoped {
        fileManager.createDirectoryAtPath(
            path,
            withIntermediateDirectories = true,
            attributes = null,
            error = null
        )
    }
}

actual object OpenMWPaths {
    actual val RANDOM_NUM: String = "Alpha-22556"

    private val baseStorage: String by lazy {
        val base = "${appSupportDir()}/Alpha3"
        ensureDir(base)
        base
    }

    actual val USER_FILE_STORAGE: String
        get() = baseStorage

    actual val SECOND_USER_FILE_STORAGE: String
        get() = documentsDir() // or same as USER_FILE_STORAGE if you prefer

    actual val USER_CONFIG: String by lazy {
        val p = "$USER_FILE_STORAGE/config"
        ensureDir(p)
        p
    }

    actual val USER_RESOURCES: String by lazy {
        val p = "$USER_FILE_STORAGE/resources"
        ensureDir(p)
        p
    }

    actual val USER_SAVES: String by lazy {
        val p = "$USER_FILE_STORAGE/saves"
        ensureDir(p)
        p
    }

    actual val USER_DELTA: String by lazy {
        val p = "$USER_FILE_STORAGE/delta"
        ensureDir(p)
        p
    }

    actual val USER_OPENMW_CFG: String
        get() = "$USER_CONFIG/openmw.cfg"

    actual val SETTINGS_FILE: String
        get() = "$USER_CONFIG/settings.cfg"

    actual val LOGCAT_FILE: String
        get() = "$USER_CONFIG/openmw_logcat.txt"

    actual val OPENMW_LOG: String
        get() = "$USER_CONFIG/openmw.log"

    actual val CRASH_FILE: String
        get() = "$USER_CONFIG/crash.log"

    actual val UMO_HELPER: String
        get() = "$USER_CONFIG/UMOhelper.sh"

    actual val GLOBAL_CONFIG: String
        get() = USER_CONFIG

    actual val VERSION_STAMP: String
        get() = "$USER_FILE_STORAGE/stamp"

    actual val DEFAULTS_BIN: String
        get() = "$USER_CONFIG/defaults.bin"

    actual val INTERNAL_CRASH_FILE: String
        get() = "$USER_CONFIG/crash_internal.log"

    actual val OPENMW_CFG: String
        get() = "$USER_CONFIG/openmw.cfg"

    actual val CACHE_DIR: String by lazy {
        val p = "${cachesDir()}/Alpha3/OpenMW/CACHE"
        ensureDir(p)
        p
    }
}


