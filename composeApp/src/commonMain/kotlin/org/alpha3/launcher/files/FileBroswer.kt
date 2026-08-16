package org.alpha3.launcher.files

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

expect fun deleteFile(path: String): Boolean

@Composable
fun FileBrowser(startPath: String) {
    var currentPath by remember { mutableStateOf(startPath) }

    // Use derivedStateOf to ensure files update when currentPath changes
    val files by remember(currentPath) {
        derivedStateOf { listFilesInDirectory(currentPath) }
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        // Back button (if not root)
        if (currentPath != startPath) {
            Text(
                text = ".. (up)",
                fontSize = 14.sp,
                color = Color.Cyan,
                modifier = Modifier
                    .clickable {
                        // Calculate parent path safely
                        val parent = if (currentPath.contains("/")) {
                            currentPath.substringBeforeLast("/", "")
                        } else {
                            ""
                        }
                        if (parent.isNotEmpty() || currentPath != startPath) {
                            currentPath = parent.ifEmpty { startPath }
                        }
                    }
                    .padding(bottom = 8.dp)
            )
        }

        // File list
        LazyColumn {
            items(files) { fullPath ->
                val name = fullPath.substringAfterLast("/")
                val directory = isDirectory(fullPath)
                var expanded by remember { mutableStateOf(false) }

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            if (directory) {
                                // Navigate into folder
                                currentPath = fullPath
                            } else {
                                // Toggle file actions for files
                                expanded = !expanded
                            }
                        }
                        .padding(vertical = 6.dp)
                ) {
                    Text(
                        text = if (directory) "📁 $name" else "📄 $name",
                        fontSize = 14.sp,
                        color = Color.White
                    )

                    if (!directory && expanded) {
                        Text(
                            text = "Delete",
                            fontSize = 12.sp,
                            color = Color.Red,
                            modifier = Modifier
                                .padding(start = 12.dp, top = 4.dp)
                                .clickable {
                                    deleteFile(fullPath)
                                }
                        )
                    }
                }
            }
        }
    }
}