package org.alpha3.launcher.files

import io.github.vinceglb.filekit.PlatformFile
import kotlinx.cinterop.*
import platform.Foundation.*

@OptIn(ExperimentalForeignApi::class)
actual fun listFilesInDirectory(path: String): List<String> {
    val fm = NSFileManager.defaultManager
    val contents = fm.contentsOfDirectoryAtPath(path, null) ?: return emptyList()
    return contents.map { "$path/${it.toString()}" }
}

@OptIn(ExperimentalForeignApi::class)
actual fun isFile(path: String): Boolean {
    val fm = NSFileManager.defaultManager
    return memScoped {
        val isDir = alloc<BooleanVar>()
        val exists = fm.fileExistsAtPath(path, isDir.ptr)
        exists && !isDir.value
    }
}

@OptIn(ExperimentalForeignApi::class)
actual fun isDirectory(path: String): Boolean {
    val fm = NSFileManager.defaultManager
    return memScoped {
        val isDir = alloc<BooleanVar>()
        val exists = fm.fileExistsAtPath(path, isDir.ptr)
        exists && isDir.value
    }
}

@OptIn(ExperimentalForeignApi::class)
actual fun copyDirectory(source: String, destination: String): Boolean {
    val fm = NSFileManager.defaultManager
    
    // NSFileManager.copyItemAtPath fails if destination exists.
    // We want to merge or overwrite.
    
    if (isDirectory(source)) {
        if (!fm.fileExistsAtPath(destination)) {
            val errorPtr = nativeHeap.alloc<ObjCObjectVar<NSError?>>()
            if (!fm.createDirectoryAtPath(destination, true, null, errorPtr.ptr)) {
                return false
            }
        }
        
        val contents = fm.contentsOfDirectoryAtPath(source, null) ?: return true
        for (item in contents) {
            val name = item.toString()
            if (!copyDirectory("$source/$name", "$destination/$name")) {
                return false
            }
        }
        return true
    } else {
        if (fm.fileExistsAtPath(destination)) {
            fm.removeItemAtPath(destination, null)
        }
        val errorPtr = nativeHeap.alloc<ObjCObjectVar<NSError?>>()
        return fm.copyItemAtPath(source, destination, errorPtr.ptr)
    }
}

@OptIn(ExperimentalForeignApi::class)
actual fun copyPlatformFileToDirectory(source: PlatformFile, destination: String): Boolean {
    val url = source.nsUrl
    val start = url.startAccessingSecurityScopedResource()
    val success = copyDirectory(url.path!!, destination)
    if (start) url.stopAccessingSecurityScopedResource()
    return success
}

