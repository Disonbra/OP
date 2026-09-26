package org.alpha3.launcher

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.ui.window.ComposeUIViewController
import org.alpha3.launcher.globals.PlayBridge

@OptIn(ExperimentalFoundationApi::class)
fun MainViewController(
    onPlay: (() -> Unit)? = null,
    onResetSettings: (() -> Unit)? = null
) = ComposeUIViewController {
    PlayBridge.onPlay = onPlay
    PlayBridge.onResetSettings = onResetSettings
    App()
}
