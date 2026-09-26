package org.alpha3.launcher.utils

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.TextButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.alpha3.launcher.files.readTextFile
import org.alpha3.launcher.files.readTextFile2
import org.alpha3.launcher.files.writeTextFile
import org.alpha3.launcher.paths.OpenMWPaths

private fun readIniValues(): Map<String, List<Triple<String, Any, String?>>> {
    val settings = mutableMapOf<String, MutableList<Triple<String, Any, String?>>>()
    val sections = mutableMapOf<String, MutableMap<String, String>>()
    val comments = mutableMapOf<String, String>()
    var currentSection: String? = null
    var pendingComment: String? = null

    val text = readTextFile(OpenMWPaths.SETTINGS_FILE) ?: return emptyMap()

    text.lineSequence().forEach { line ->
        val trimmedLine = line.trim()
        when {
            trimmedLine.startsWith("[") && trimmedLine.endsWith("]") -> {
                currentSection = trimmedLine.substring(1, trimmedLine.length - 1).trim()
                sections[currentSection] = mutableMapOf()
                pendingComment = null
            }
            trimmedLine.startsWith("#") -> {
                pendingComment = trimmedLine.substring(1).trim()
            }
            "=" in trimmedLine -> {
                val parts = trimmedLine.split("=", limit = 2)
                val key = parts[0].trim()
                val value = parts[1].trim()
                if (currentSection != null) {
                    sections[currentSection]!![key] = value
                    if (pendingComment != null) {
                        comments["$currentSection:$key"] = pendingComment
                    }
                }
                pendingComment = null
            }
            else -> { pendingComment = null }
        }
    }
    
    sections.forEach { (section, properties) ->
        val sectionSettings = properties.map { (key, value) ->
            val parsedValue: Any = when {
                value.equals("true", ignoreCase = true) || value.equals("false", ignoreCase = true) -> value.toBoolean()
                value.toIntOrNull() != null -> value.toInt()
                value.toFloatOrNull() != null -> value.toFloat()
                else -> value
            }
            Triple(key, parsedValue, comments["$section:$key"])
        }
        settings[section] = sectionSettings.toMutableList()
    }
    return settings
}

fun writeIniValue(section: String, key: String, value: Any) {
    val path = OpenMWPaths.SETTINGS_FILE
    val settingsText = readTextFile2(path)
    if (settingsText.isEmpty() || settingsText.contains("length = ")) return 
    
    val lines = settingsText.split(Regex("\\r?\\n")).toMutableList()
    var sectionFound = false
    var keyFound = false
    var nextSectionIndex = lines.size

    for (i in lines.indices) {
        val line = lines[i].trim()
        if (line.startsWith("[") && line.endsWith("]")) {
            if (sectionFound) {
                nextSectionIndex = i
                break
            }
            if (line.substring(1, line.length - 1).trim() == section) {
                sectionFound = true
            }
        } else if (sectionFound) {
            val parts = line.split("=", limit = 2)
            if (parts.isNotEmpty() && parts[0].trim() == key.trim()) {
                lines[i] = "${key.trim()} = ${value.toString().trim()}"
                keyFound = true
                break
            }
        }
    }

    if (!sectionFound) {
        lines.add("[${section.trim()}]")
        lines.add("${key.trim()} = ${value.toString().trim()}")
    } else if (!keyFound) {
        lines.add(nextSectionIndex, "${key.trim()} = ${value.toString().trim()}")
    }

    writeTextFile(path, lines.joinToString("\n"))
}

@Composable
fun ReadAndDisplayIniValues() {
    var isExpanded by remember { mutableStateOf(false) }
    val settings = remember { mutableStateOf(readIniValues()) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF1C1C1E)) // iOS dark background
            .border(0.5.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { isExpanded = !isExpanded }
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Engine Settings", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = Color.White)
            Text(if (isExpanded) "Hide" else "Show", color = Color(0xFF0A84FF), fontSize = 16.sp)
        }
        
        if (isExpanded) {
            HorizontalDivider(color = Color.White.copy(alpha = 0.1f), thickness = 0.5.dp)
            IniSettingsList(settings)
            
            // Reset Button inside the card
            org.alpha3.launcher.globals.PlayBridge.onResetSettings?.let { reset ->
                TextButton(
                    onClick = { 
                        reset()
                        settings.value = readIniValues()
                    },
                    modifier = Modifier.fillMaxWidth().padding(8.dp)
                ) {
                    Text("Reset All to Default", color = Color.Red.copy(alpha = 0.8f), fontSize = 14.sp)
                }
            }
        }
    }
}

@Composable
fun IniSettingsList(settings: MutableState<Map<String, List<Triple<String, Any, String?>>>>) {
    val scrollState = androidx.compose.foundation.rememberScrollState()
    
    // Bounding the height and adding verticalScroll makes the sections scrollable
    // even inside the non-scrollable main launcher column.
    Column(
        modifier = Modifier
            .padding(bottom = 8.dp)
            .heightIn(max = 450.dp)
            .verticalScroll(scrollState)
    ) {
        settings.value.entries.forEach { (section, sectionSettings) ->
            var sectionExpanded by remember { mutableStateOf(false) }
            
            Column(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { sectionExpanded = !sectionExpanded }
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(section, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = Color.White)
                    Text(if (sectionExpanded) "▲" else "▼", color = Color.Gray, fontSize = 14.sp)
                }
                
                AnimatedVisibility(visible = sectionExpanded) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color.White.copy(alpha = 0.05f))
                    ) {
                        sectionSettings.forEachIndexed { index, (key, value, comment) ->
                            SettingRow(section, key, value, comment) {
                                settings.value = readIniValues()
                            }
                            if (index < sectionSettings.size - 1) {
                                HorizontalDivider(color = Color.White.copy(alpha = 0.1f), thickness = 0.5.dp, modifier = Modifier.padding(horizontal = 12.dp))
                            }
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
fun SettingRow(section: String, key: String, value: Any, comment: String?, onSave: () -> Unit) {
    val focusManager = LocalFocusManager.current
    Column(modifier = Modifier.fillMaxWidth().padding(12.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
            Column(modifier = Modifier.weight(1f)) {
                Text(key, fontSize = 15.sp, color = Color.White)
                if (comment != null) {
                    Text(comment, fontSize = 12.sp, color = Color.Gray, lineHeight = 14.sp)
                }
            }
            Spacer(Modifier.width(16.dp))
            when (value) {
                is Boolean -> {
                    var checked by remember(value) { mutableStateOf(value) }
                    Switch(
                        checked = checked,
                        onCheckedChange = {
                            checked = it
                            writeIniValue(section, key, it)
                            onSave()
                        },
                        colors = SwitchDefaults.colors(checkedThumbColor = Color.White, checkedTrackColor = Color(0xFF34C759))
                    )
                }
                is Int, is Float -> {
                    var textValue by remember(value) { mutableStateOf(value.toString()) }
                    androidx.compose.foundation.text.BasicTextField(
                        value = textValue,
                        onValueChange = { textValue = it },
                        modifier = Modifier.width(80.dp).background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(6.dp)).padding(8.dp),
                        textStyle = MaterialTheme.typography.bodyMedium.copy(color = Color(0xFF0A84FF), textAlign = androidx.compose.ui.text.style.TextAlign.End),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done, keyboardType = if (value is Int) KeyboardType.Number else KeyboardType.Decimal),
                        keyboardActions = KeyboardActions(onDone = {
                            if (value is Int) writeIniValue(section, key, textValue.toIntOrNull() ?: 0)
                            else writeIniValue(section, key, textValue.toFloatOrNull() ?: 0.0f)
                            onSave()
                            focusManager.clearFocus()
                        }),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(Color(0xFF0A84FF))
                    )
                }
                else -> Text(value.toString(), color = Color.Gray, fontSize = 14.sp)
            }
        }
    }
}
