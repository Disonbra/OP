package org.alpha3.launcher

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.ui.window.ComposeUIViewController

@OptIn(ExperimentalFoundationApi::class)
fun MainViewController() = ComposeUIViewController { App() }