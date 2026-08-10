package org.alpha3.launcher.globals

/**
 * Hook the platform host uses to hand the launcher an engine-start action.
 *
 * On iOS the Swift side passes a lambda into MainViewController that runs
 * the native launch sequence (write user cfg, init gl4es, dlopen
 * libopenmw.dylib, call main) — the equivalent of Android's
 * System.loadLibrary glue. Null when the platform has not wired one up.
 */
object PlayBridge {
    var onPlay: (() -> Unit)? = null
}
