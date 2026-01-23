package org.alpha3.launcher.files

import kotlinx.cinterop.BooleanVar
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.ObjCObjectVar
import kotlinx.cinterop.alloc
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.nativeHeap
import kotlinx.cinterop.ptr
import platform.Foundation.*
import kotlinx.cinterop.*

@OptIn(ExperimentalForeignApi::class)
actual fun deleteFile(path: String): Boolean {
    val fm = NSFileManager.defaultManager
    val errorPtr = nativeHeap.alloc<ObjCObjectVar<NSError?>>()
    val success = fm.removeItemAtPath(path, errorPtr.ptr)
    return success
}

@OptIn(ExperimentalForeignApi::class)
actual fun isDirectory(path: String): Boolean {
    val fileManager = NSFileManager.defaultManager

    // Create URL from path
    val url = NSURL.fileURLWithPath(path)

    // Get file attributes
    val error: NSError? = null
    val attributes = fileManager.attributesOfItemAtPath(path, null)

    // Check if it's a directory
    return attributes?.get(NSFileType)?.equals(NSFileTypeDirectory) ?: false
}
