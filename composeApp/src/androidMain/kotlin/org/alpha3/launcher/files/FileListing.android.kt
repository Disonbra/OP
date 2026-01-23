package org.alpha3.launcher.files

import java.io.File

actual fun listFilesInDirectory(path: String): List<String> {
    val dir = File(path)
    return dir.list()?.toList() ?: emptyList()
}
