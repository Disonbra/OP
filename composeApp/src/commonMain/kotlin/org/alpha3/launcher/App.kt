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
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.InternalCoroutinesApi
import org.alpha3.launcher.files.*
import org.alpha3.launcher.globals.PlayBridge
import org.alpha3.launcher.mods.ModValuesList
import org.alpha3.launcher.mods.readModValues
import org.alpha3.launcher.paths.OpenMWPaths
import org.alpha3.launcher.utils.BouncingBackground
import org.alpha3.launcher.utils.ReadAndDisplayIniValues
import io.github.vinceglb.filekit.dialogs.compose.rememberDirectoryPickerLauncher
import kotlinx.coroutines.launch
import org.alpha3.launcher.utils.patchShadersLinking
import org.alpha3.launcher.utils.patchShadersToGLES


@OptIn(DelicateCoroutinesApi::class)
@ExperimentalFoundationApi
@Composable
@Preview
fun App() {
    println("APP COMPOSABLE START")
    LaunchedEffect(Unit) {
        println("LAUNCHED EFFECT START")
        println("=========================================================================")
        println("IOS SIMULATOR APP PATHS:")
        println("Documents: ${OpenMWPaths.SECOND_USER_FILE_STORAGE}")
        println("Config: ${OpenMWPaths.USER_CONFIG}")
        println("To open in Finder run:")
        println("open ${OpenMWPaths.SECOND_USER_FILE_STORAGE}")
        println("Resources Path: ${OpenMWPaths.USER_RESOURCES}")
        println("=========================================================================")
        //patchShadersLinking()
        //patchShadersToGLES()
    }

    MaterialTheme {
        var showContent by remember { mutableStateOf(false) }
        val modValues = remember { readModValues() }
        val scope = rememberCoroutineScope()
        
        var isImporting by remember { mutableStateOf(false) }

        val launcher = rememberDirectoryPickerLauncher { directory ->
            directory?.let { dir ->
                scope.launch {
                    isImporting = true
                    val dest = OpenMWPaths.SECOND_USER_FILE_STORAGE + "/Data Files"
                    val success = copyPlatformFileToDirectory(dir, dest)
                    println("Import result: $success to $dest")
                    isImporting = false
                }
            }
        }

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
                
                Button(onClick = { launcher.launch() }, enabled = !isImporting) {
                    Text(if (isImporting) "Importing..." else "Import Game Folder")
                }

                Button(onClick = { showContent = !showContent }) {
                    Text("Settings")
                }
                AnimatedVisibility(showContent) {
                    val appPath = OpenMWPaths.USER_FILE_STORAGE

                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        ReadAndDisplayIniValues()

                        Button(onClick = { createTestFiles(appPath) }) { Text("Create Test Files") }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            FileBrowser(startPath = appPath)
                        }
                    }
                }

                ModValuesList(modValues)
            }
        }
    }
}
