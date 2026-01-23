@file:OptIn(ExperimentalForeignApi::class)

package org.alpha3.launcher.files

import kotlinx.cinterop.ExperimentalForeignApi
import platform.Foundation.*

actual fun listFilesInDirectory(path: String): List<String> {
    val fm = NSFileManager.defaultManager
    val contents = fm.contentsOfDirectoryAtPath(path, null) ?: return emptyList()
    return contents.map { it.toString() }
}

