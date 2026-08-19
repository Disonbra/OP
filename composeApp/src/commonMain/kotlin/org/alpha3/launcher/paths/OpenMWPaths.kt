package org.alpha3.launcher.paths

// use these everywhere in commonMain
import org.alpha3.launcher.paths.OpenMWPaths
val cfgPath = OpenMWPaths.USER_OPENMW_CFG


expect object OpenMWPaths {
    val RANDOM_NUM: String

    val USER_FILE_STORAGE: String
    val SECOND_USER_FILE_STORAGE: String
    val DEFAULTS_BIN: String
    val OPENMW_CFG: String
    val SETTINGS_FILE: String
    val UMO_HELPER: String
    val LOGCAT_FILE: String
    val OPENMW_LOG: String
    val GLOBAL_CONFIG: String
    val USER_CONFIG: String
    val USER_RESOURCES: String
    val USER_SAVES: String
    val USER_DELTA: String
    val USER_OPENMW_CFG: String
    val VERSION_STAMP: String
    val CRASH_FILE: String
    val INTERNAL_CRASH_FILE: String
    val CACHE_DIR: String
    val LIBRARY_ROOT: String

    fun setupResources()
}
