package org.alpha3.launcher.utils

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.platform.LocalFocusManager
import org.alpha3.launcher.files.readTextFile
import org.alpha3.launcher.files.readTextFile2
import org.alpha3.launcher.files.writeTextFile
import org.alpha3.launcher.globals.customColor
import org.alpha3.launcher.globals.darkGray
import org.alpha3.launcher.globals.gradientColors
import org.alpha3.launcher.globals.lightGray
import org.alpha3.launcher.paths.OpenMWPaths
import kotlin.collections.component1
import kotlin.collections.component2
import kotlin.collections.get
import kotlin.text.iterator
import kotlin.collections.*

class IniConverter(private val data: String) {
    fun convert(): String {
        return data
            .lines()
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith(";") }
            .fold(Pair("", "")) { acc, line ->
                if (line.startsWith("[") && line.endsWith("]")) {
                    acc.copy(first = line.substring(1, line.length - 1).replace(" ", "_"))
                } else if (line.contains("=")) {
                    val converted = convertLine(line)
                    if (converted.isNotEmpty()) {
                        acc.copy(second = acc.second + "fallback=${acc.first}_$converted\n")
                    } else acc
                } else acc
            }.second
    }

    private fun convertLine(line: String): String {
        val (key, value) = line.split("=", limit = 2)
        if (key.isBlank() || value.isBlank()) return ""
        return "${key.replace(" ", "_")},$value"
    }
}

private fun readIniValues(): Map<String, List<Triple<String, Any, String?>>> {
    val settings = mutableMapOf<String, MutableList<Triple<String, Any, String?>>>()
    val comments = mutableMapOf<String, String?>()
    val sections = mutableMapOf<String, MutableMap<String, String>>()
    var currentSection: String? = null
    var lastKey: String? = null

    // Define your blacklist here
    val blacklist = setOf("key1", "key2", "key3")
    val text = readTextFile(OpenMWPaths.SETTINGS_FILE)

    text?.lineSequence()?.forEach { line ->
        val trimmedLine = line.trim()
        when {
            trimmedLine.startsWith("[") && trimmedLine.endsWith("]") -> {
                currentSection = trimmedLine.substring(1, trimmedLine.length - 1).trim()
                sections[currentSection!!] = mutableMapOf()
            }
            trimmedLine.startsWith("#") -> {
                val comment = trimmedLine.substring(1).trim()
                if (lastKey != null && lastKey !in blacklist) {
                    comments[lastKey!!] = comment
                }
            }
            "=" in trimmedLine -> {
                val (key, value) = trimmedLine.split("=", limit = 2).map { it.trim() }
                if (currentSection != null && key !in blacklist) {
                    sections[currentSection]!![key] = value
                    lastKey = key
                } else {
                    lastKey = null // Reset lastKey if the key is blacklisted
                }
            }
        }
    }
    sections.forEach { (section, properties) ->
        val sectionSettings = properties.mapNotNull { (key, value) ->
            if (key in blacklist) return@mapNotNull null
            val parsedValue: Any = when {
                value.equals("true", ignoreCase = true) || value.equals("false", ignoreCase = true) -> value.toBoolean()
                value.toIntOrNull() != null -> value.toInt()
                value.toFloatOrNull() != null -> value.toFloat()
                else -> value
            }
            Triple(key, parsedValue, comments[key])
        }
        settings[section] = sectionSettings.toMutableList()
    }
    return settings
}

fun String.safeReadLines(): List<String> =
    this.split('\n', '\r')
        .filter { it.isNotEmpty() }


fun writeIniValue(section: String, key: String, value: Any, comment: String?) {
    val path = OpenMWPaths.SETTINGS_FILE
    val settingsText = readTextFile2(path)
    val lines = settingsText.safeReadLines().toMutableList()

    var sectionFound = false
    var keyFound = false
    var sectionEndIndex = lines.size

    for (i in lines.indices) {
        val line = lines[i].trim()

        // Section header
        if (line.startsWith("[") && line.endsWith("]")) {
            if (sectionFound) {
                sectionEndIndex = i
                break
            }
            if (line.substring(1, line.length - 1).trim() == section) {
                sectionFound = true
            }
        }
        // Key inside section
        else if (sectionFound && line.startsWith(key)) {
            lines[i] = "${key.trim()} = ${value.toString().trim()}"
            keyFound = true

            if (comment != null) {
                val commentIndex = i + 1
                if (commentIndex < lines.size && lines[commentIndex].trim() != comment.trim()) {
                    lines.add(commentIndex, comment.trim())
                    lines.add(commentIndex + 1, "")
                }
            }
            break
        }
    }

    // Section not found → append new section
    if (!sectionFound) {
        lines.add("[${section.trim()}]")
        lines.add("${key.trim()} = ${value.toString().trim()}")
        if (comment != null) {
            lines.add(comment.trim())
            lines.add("")
        }
    }
    // Section found but key missing → insert before next section
    else if (!keyFound) {
        lines.add(sectionEndIndex, "${key.trim()} = ${value.toString().trim()}")
        if (comment != null) {
            lines.add(sectionEndIndex + 1, comment.trim())
            lines.add(sectionEndIndex + 2, "")
        }
    }

    // 🔥 Correct multiplatform write
    writeTextFile(path, lines.joinToString("\n"))
}


@Composable
fun ReadAndDisplayIniValues() {
    var isColumnExpanded by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, Color.Black)
            .background(color = customColor)
            .clickable { isColumnExpanded = !isColumnExpanded }, // Toggle column expansion
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(brush = Brush.horizontalGradient(colors = gradientColors))
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "OpenMW Settings",
                fontWeight = FontWeight.Bold,
                fontSize = 24.sp,
                color = Color.White
            )
            Text(
                text = if (isColumnExpanded) "▲" else "▼",
                fontSize = 20.sp,
                color = Color.White,
                modifier = Modifier.padding(
                    horizontal = 16.dp,
                    vertical = 10.dp
                )
            )
        }
        if (isColumnExpanded) {
            IniSettings()
        }
    }
}

@Composable
fun IniSettings() {
    val settings = remember { mutableStateOf(readIniValues()) }
    val focusManager = LocalFocusManager.current
    LazyColumn {
        items(settings.value.entries.toList()) { (section, sectionSettings) ->
            var isExpanded by remember { mutableStateOf(false) }
            Column(
                modifier = Modifier
                    .background(color = customColor)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, Color.Black)
                        .clickable { isExpanded = !isExpanded }, // Toggle expansion
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = section,
                        fontWeight = FontWeight.Bold,
                        fontSize = 20.sp,
                        color = Color.White,
                        modifier = Modifier.padding(
                            horizontal = 16.dp,
                            vertical = 2.dp
                        )
                    )
                    Text(
                        text = if (isExpanded) "▲" else "▼",
                        fontSize = 20.sp,
                        color = Color.White,
                        modifier = Modifier.padding(
                            horizontal = 16.dp,
                            vertical = 10.dp
                        )
                    )
                }
                if (isExpanded) {
                    sectionSettings.forEachIndexed { index, (propertyKey, value, comment) ->
                        val extractedPropertyKey =
                            propertyKey.substringAfterLast('.')
                        val backgroundColor = if (index % 2 == 0) darkGray else lightGray
                        settings.value = readIniValues()

                        when (value) {
                            is Boolean -> {
                                var switchState by remember { mutableStateOf(value) }
                                Column(
                                    modifier = Modifier
                                        .background(color = backgroundColor)
                                        .fillMaxWidth()
                                        .border(2.dp, Color.Black)
                                        .padding(bottom = 16.dp) // Add space between each iteration
                                ) {
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .border(1.dp, Color.Black),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(
                                            text = extractedPropertyKey,
                                            fontWeight = FontWeight.Bold,
                                            color = if (value.toString() == "false") Color.Red else Color.Green,
                                            fontSize = 16.sp,
                                            modifier = Modifier.padding(start = 10.dp, top = 4.dp)
                                        )
                                        Spacer(modifier = Modifier.weight(1f))
                                        Switch(
                                            checked = switchState,
                                            onCheckedChange = {
                                                switchState = it

                                                writeIniValue(section, extractedPropertyKey, it, null)

                                                settings.value = readIniValues() // Reload settings
                                            },
                                            colors = SwitchDefaults.colors(
                                                checkedThumbColor = MaterialTheme.colorScheme.primary,
                                                checkedTrackColor = MaterialTheme.colorScheme.primaryContainer,
                                                uncheckedThumbColor = MaterialTheme.colorScheme.secondary,
                                                uncheckedTrackColor = MaterialTheme.colorScheme.secondaryContainer,
                                            )
                                        )
                                    }
                                    if (comment != null) {
                                        Text(
                                            text = comment,
                                            fontWeight = FontWeight.Bold,
                                            color = Color.White,
                                            fontSize = 14.sp,
                                            modifier = Modifier.padding(start = 10.dp, top = 4.dp)
                                        )
                                    }
                                }
                            }

                            is Float -> {
                                var floatValue by remember { mutableStateOf(value.toString()) }
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .border(1.dp, Color.Black),
                                    verticalArrangement = Arrangement.Center
                                ) {
                                    Text(
                                        text = extractedPropertyKey,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.Green,
                                        fontSize = 16.sp,
                                        modifier = Modifier.padding(
                                            start = 10.dp,
                                            top = 4.dp
                                        )
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                    TextField(
                                        value = floatValue,
                                        onValueChange = {
                                            floatValue = it
                                            val floatVal =
                                                it.toFloatOrNull() ?: 0.0f
                                            writeIniValue(
                                                section,
                                                extractedPropertyKey,
                                                floatVal,
                                                null
                                            )

                                            settings.value = readIniValues() // Reload settings

                                        },
                                        label = { Text("Enter value") },
                                        modifier = Modifier.fillMaxWidth(),
                                        keyboardOptions = KeyboardOptions.Default.copy(imeAction = ImeAction.Done),
                                        keyboardActions = KeyboardActions(
                                            onDone = {
                                                focusManager.clearFocus()
                                            }
                                        )
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                    if (comment != null) {
                                        Text(
                                            text = comment,
                                            fontWeight = FontWeight.Bold,
                                            color = Color.White,
                                            fontSize = 14.sp,
                                            modifier = Modifier.padding(start = 10.dp, top = 4.dp)
                                        )
                                    }
                                }
                            }

                            is Int -> {
                                var intValue by remember { mutableStateOf(value.toString()) }
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .border(1.dp, Color.Black),
                                    verticalArrangement = Arrangement.Center
                                ) {
                                    Text(
                                        text = extractedPropertyKey,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.Green,
                                        fontSize = 16.sp,
                                        modifier = Modifier.padding(
                                            start = 10.dp,
                                            top = 4.dp
                                        )
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                    TextField(
                                        value = intValue,
                                        onValueChange = {
                                            intValue = it
                                            val intVal = it.toIntOrNull() ?: 0
                                            writeIniValue(
                                                section,
                                                extractedPropertyKey,
                                                intVal,
                                                null
                                            )

                                            settings.value = readIniValues() // Reload settings
                                        },
                                        label = { Text("Enter value") },
                                        modifier = Modifier.fillMaxWidth(),
                                        keyboardOptions = KeyboardOptions.Default.copy(imeAction = ImeAction.Done),
                                        keyboardActions = KeyboardActions(
                                            onDone = {
                                                focusManager.clearFocus()
                                            }
                                        )
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                    if (comment != null) {
                                        Text(
                                            text = comment,
                                            fontWeight = FontWeight.Bold,
                                            color = Color.White,
                                            fontSize = 14.sp,
                                            modifier = Modifier.padding(start = 10.dp, top = 4.dp)
                                        )
                                    }
                                }
                            }

                            else -> {
                                Text(
                                    text = "$extractedPropertyKey = $value",
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White,
                                    fontSize = 16.sp,
                                    modifier = Modifier.padding(
                                        start = 10.dp,
                                        top = 4.dp
                                    )
                                )
                                if (comment != null) {
                                    Text(
                                        text = comment,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White,
                                        fontSize = 16.sp,
                                        modifier = Modifier.padding(
                                            start = 24.dp,
                                            top = 4.dp
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}