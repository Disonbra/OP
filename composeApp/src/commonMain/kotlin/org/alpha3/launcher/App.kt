@file:OptIn(InternalCoroutinesApi::class)

package org.alpha3.launcher

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.safeContentPadding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.InternalCoroutinesApi
import org.alpha3.launcher.files.FileBrowser
import org.alpha3.launcher.files.createTestFiles
import org.alpha3.launcher.globals.PlayBridge
import org.alpha3.launcher.mods.ModValuesList
import org.alpha3.launcher.mods.readModValues
import org.alpha3.launcher.paths.OpenMWPaths
import org.alpha3.launcher.utils.BouncingBackground
import org.alpha3.launcher.utils.ReadAndDisplayIniValues

@OptIn(DelicateCoroutinesApi::class)
@ExperimentalFoundationApi
@Composable
@Preview
fun App() {
    LaunchedEffect(Unit) {
        println("=========================================================================")
        println("IOS SIMULATOR APP PATHS:")
        println("Documents: ${OpenMWPaths.SECOND_USER_FILE_STORAGE}")
        println("Config: ${OpenMWPaths.USER_CONFIG}")
        println("To open in Finder run:")
        println("open ${OpenMWPaths.SECOND_USER_FILE_STORAGE}")
        println("=========================================================================")
    }

    MaterialTheme {
        var showContent by remember { mutableStateOf(false) }
        val modValues = readModValues()
        Box(
            modifier = Modifier
                .fillMaxSize()
        ) {
            BouncingBackground()
            Column(
                modifier = Modifier
                    //.background(MaterialTheme.colorScheme.primaryContainer)
                    .safeContentPadding()
                    .fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {

                // Present when the platform host wired up an engine-start
                // action (iOS passes one into MainViewController).
                PlayBridge.onPlay?.let { play ->
                    Button(onClick = play) {
                        Text("Play")
                    }
                }
                Button(onClick = { showContent = !showContent }) {
                    Text("Settings")
                }
                AnimatedVisibility(showContent) {
                    val appPath = OpenMWPaths.USER_FILE_STORAGE
                    //val files = remember(showContent) { listFilesInDirectory(appPath) }

                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        ReadAndDisplayIniValues()

                        Button(onClick = { createTestFiles(appPath) }) { Text("Create Test Files") }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            //Text("Path: $appPath", fontSize = 12.sp, color = Color.White)
                            FileBrowser(startPath = appPath)
                        }
                    }
                }

                ModValuesList(modValues)
            }
        }
    }
}
