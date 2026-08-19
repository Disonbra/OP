package org.alpha3.launcher.utils

import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath
import okio.SYSTEM
import org.alpha3.launcher.paths.OpenMWPaths


// KMP Helper to allow using java.io.File-like syntax in commonMain
private class File(val path: String) {
    private val okioPath = path.toPath()
    private val fs = FileSystem.SYSTEM

    fun isFile(): Boolean = try { fs.metadata(okioPath).isRegularFile } catch(e: Exception) { false }
    fun readText(): String = fs.read(okioPath) { readUtf8() }
    fun writeText(text: String) = fs.write(okioPath) { writeUtf8(text) }
    
    val name: String get() = okioPath.name
    val extension: String get() = okioPath.name.substringAfterLast(".", "")

    fun walkTopDown(): Sequence<File> {
        if (!fs.exists(okioPath)) return emptySequence()
        return fs.listRecursively(okioPath).map { File(it.toString()) }
    }
    
    override fun toString(): String = path
}


fun patchShadersLinking() {
    val vertex = File(OpenMWPaths.USER_RESOURCES + "/shaders/lib/core/vertex.h.glsl")
    var content = File(OpenMWPaths.USER_RESOURCES + "/shaders/lib/core/vertex.glsl").readText()
    if (!vertex.readText().contains("#pragma CONVERTED")) {
        content = content.replace("#version 120" ,"vec4 modelToView(vec4 pos);")
        content = content.replace("uniform vec2 screenRes;" ,"//uniform vec2 screenRes;")
        content = content.replace("lib/core/vertex.h.glsl" + '"', "lib/core/lighting_vertex_impl.glsl" + '"' + "\n#include " + '"' + "lib/material/struct.glsl" + '"')
        vertex.writeText(content + "\n#pragma CONVERTED\n")
    }

    val fragment = File(OpenMWPaths.USER_RESOURCES + "/shaders/lib/core/fragment.h.glsl")
    if (!fragment.readText().contains("#pragma CONVERTED")) {
        content = File(OpenMWPaths.USER_RESOURCES + "/shaders/lib/core/fragment.glsl").readText()
        content = content.replace("#version 120" ,"")
        content = content.replace("lib/core/fragment.h.glsl" + '"', "lib/core/lighting_fragment_impl.glsl" + '"' + "\n#include " + '"' + "lib/material/struct.glsl" + '"')
        fragment.writeText(content + "\n#pragma CONVERTED\n")
    }

    val objectsFrag = File(OpenMWPaths.USER_RESOURCES + "/shaders/compatibility/objects.frag")
    content = objectsFrag.readText()
    if (!content.contains("#pragma CONVERTED")) {
        content = content.replace("uniform vec2 screenRes;" ,"//uniform vec2 screenRes;")
        content = content.replace("uniform float near;" ,"//uniform float near;")
        objectsFrag.writeText(content + "\n#pragma CONVERTED\n")
    }

    val objectsVert = File(OpenMWPaths.USER_RESOURCES + "/shaders/compatibility/objects.vert")
    content = objectsVert.readText()
    if (!content.contains("#pragma CONVERTED")) {
        content = content.replace("uniform vec2 screenRes;" ,"//uniform vec2 screenRes;")
        objectsVert.writeText(content + "\n#pragma CONVERTED\n")
    }

    val terrainFrag = File(OpenMWPaths.USER_RESOURCES + "/shaders/compatibility/terrain.frag")
    content = terrainFrag.readText()
    if (!content.contains("#pragma CONVERTED")) {
        content = content.replace("uniform vec2 screenRes;" ,"//uniform vec2 screenRes;")
        content = content.replace("uniform float near;" ,"//uniform float near;")
        terrainFrag.writeText(content + "\n#pragma CONVERTED\n")
    }

    val groundcoverFrag = File(OpenMWPaths.USER_RESOURCES + "/shaders/compatibility/groundcover.frag")
    content = groundcoverFrag.readText()
    if (!content.contains("#pragma CONVERTED")) {
        content = content.replace("uniform vec2 screenRes;" ,"//uniform vec2 screenRes;")
        groundcoverFrag.writeText(content + "\n#pragma CONVERTED\n")
    }

    val groundcoverVert = File(OpenMWPaths.USER_RESOURCES + "/shaders/compatibility/groundcover.vert")
    content = groundcoverVert.readText()
    if (!content.contains("#pragma CONVERTED")) {
        content = content.replace("#include " + '"' + "lib/light/clamp.glsl" + '"' + "\n#include", "#include")
        groundcoverVert.writeText(content + "\n#pragma CONVERTED\n")
    }

    val waterFrag = File(OpenMWPaths.USER_RESOURCES + "/shaders/compatibility/water.frag")
    content = waterFrag.readText()
    if (!content.contains("#pragma CONVERTED")) {
        content = content.replace("uniform vec2 screenRes;" ,"//uniform vec2 screenRes;")
        content = content.replace("uniform float near;" ,"//uniform float near;")
        content = content.replace("uniform DirectionalLight sun;" ,"//uniform DirectionalLight sun;")
        waterFrag.writeText(content + "\n#pragma CONVERTED\n")
    }

    val lightutil = File(OpenMWPaths.USER_RESOURCES + "/shaders/lib/light/util.glsl")
    content = lightutil.readText()
    if (!content.contains("#pragma CONVERTED")) {
        content = content.replace("* int(gridSize.z)) /", "* gridSize.z) /")
        lightutil.writeText(content + "\n#pragma CONVERTED\n")
    }

    val fog = File(OpenMWPaths.USER_RESOURCES + "/shaders/compatibility/fog.glsl")
    content = fog.readText()
    if (!content.contains("#pragma CONVERTED")) {
        content = content.replace("#include", "//")
        fog.writeText(content + "\n#pragma CONVERTED\n")
    }
}

private fun addLineToHeader(content: String, new_line: String): String {
    return content.replace("//HEADER_END\n", new_line + "\n//HEADER_END\n")
}

fun patchShadersToGLES() {
    File(OpenMWPaths.USER_RESOURCES + "/shaders").walkTopDown().forEach {
        if (it.isFile()) {
            var content = File(it.toString()).readText()
            if (!content.contains("#pragma GLES")) {
                // Replace version string and add default precisions
                content = content.replace("#version 120", "#version 320 es\nprecision highp float;\nprecision highp int;\n\n//HEADER_END\n")

                // Comment out all extensions
                content = content.replace("#extension", "//extension")

                // Replace all gl_* build-ins with osg_* variants except gl_Position, gl_FragCoord and gl_Fog
                content = content.replace("gl_", "osg_")
                content = content.replace("osg_Position", "gl_Position")
                content = content.replace("osg_FragCoord", "gl_FragCoord")
                content = content.replace("osg_ClipDistance", "gl_ClipDistance")
                content = content.replace("osg_CullDistance", "gl_CullDistance")

                // Remove default values from uniforms (not supported on es)
                content = content.replace("uniform bool useAdvancedShader = false;", "uniform bool useAdvancedShader;")
                content = content.replace("uniform vec2 scaling = vec2(1.0, 1.0);", "uniform vec2 scaling;")
                content = content.replace("uniform bool useDiffuseMapForShadowAlpha = true;", "uniform bool useDiffuseMapForShadowAlpha;")
                content = content.replace("uniform bool alphaTestShadows = true;", "uniform bool alphaTestShadows;")

                if (it.extension == "frag") {
                    // Add osg build-in uniforms
                    content = addLineToHeader(content, "uniform mat4 osg_ModelViewMatrix;")
                    content = addLineToHeader(content, "uniform mat3 osg_NormalMatrix;")

                    // slow gl_ModelViewMatrixInverse replacement
                    content = content.replace("osg_ModelViewMatrixInverse", "inverse(osg_ModelViewMatrix)")

                    // Add fragment output variables
                    content = addLineToHeader(content, "layout(location = 0) out vec4 Color0;")
                    content = addLineToHeader(content, "layout(location = 1) out vec4 Color1;")
                    content = content.replace("osg_FragData[0]", "Color0")
                    content = content.replace("osg_FragData[1]", "Color1")
                    content = content.replace("osg_FragColor", "Color0")

                    // Add some defines
                    content = addLineToHeader(content, "#define texture2D texture")
                    content = addLineToHeader(content, "#define textureSize2D textureSize")
                    content = addLineToHeader(content, "#define varying in")

                    // Add some shadows stuff
                    content = addLineToHeader(content, "#define shadow2DProj custom_shadow2DProj")
                    //content = addLineToHeader(content, "vec4 custom_shadow2DProj(sampler2DShadow sampler, vec4 uv) { return vec4(textureProj(sampler, uv)); }")
                }
                else if (it.extension == "vert") {

                    // clipplane
                    content = content.replace("#version 320 es\n", "#version 320 es\n#extension GL_EXT_clip_cull_distance : enable\n")
                    content = content.replace("osg_ClipVertex = viewPos;\n", "")
                    /*
                                   if (content.contains("osg_ClipVertex")) {
                                       content = content.replace("#version 320 es\n", "#version 320 es\n#extension GL_EXT_clip_cull_distance : enable\n")
                                       content = content.replace("osg_ClipVertex = viewPos;\n", "if (isReflection) gl_ClipDistance[0] = dot(osg_ModelViewMatrix * osg_Vertex, omw_ClipPlane0);\n")
                                       content = addLineToHeader(content, "uniform vec4 omw_ClipPlane0;")
                                       content = addLineToHeader(content, "uniform bool isReflection;")
                                   }
                    */
                    if (it.name.contains("terrain_composite")) {
                        content = content.replace("osg_ModelViewMatrix * ", "")
                    }

                    if (it.name.contains("shadowcasting")) {
                        content = content.replace("    vec4 viewPos", "#if !@useDepthClamp\n    gl_Position.z = max(gl_Position.z, -gl_Position.w);\n#endif\n    vec4 viewPos")
                    }

                    // Add osg build-in attributes/uniforms
                    content = addLineToHeader(content, "in vec4 osg_Vertex;")
                    content = addLineToHeader(content, "in vec3 osg_Normal;")
                    content = addLineToHeader(content, "in vec4 osg_Color;")
                    content = addLineToHeader(content, "in vec3 osg_MultiTexCoord0;")
                    content = addLineToHeader(content, "in vec3 osg_MultiTexCoord1;")
                    content = addLineToHeader(content, "in vec3 osg_MultiTexCoord2;")
                    content = addLineToHeader(content, "in vec3 osg_MultiTexCoord3;")
                    content = addLineToHeader(content, "in vec3 osg_MultiTexCoord4;")
                    content = addLineToHeader(content, "in vec3 osg_MultiTexCoord5;")
                    content = addLineToHeader(content, "in vec3 osg_MultiTexCoord6;")
                    content = addLineToHeader(content, "in vec3 osg_MultiTexCoord7;")

                    content = addLineToHeader(content, "uniform mat4 osg_ModelViewProjectionMatrix;")
                    content = addLineToHeader(content, "uniform mat4 osg_ModelViewMatrix;")
                    content = addLineToHeader(content, "uniform mat3 osg_NormalMatrix;")

                    // Add some defines
                    content = addLineToHeader(content, "#define attribute in")
                    content = addLineToHeader(content, "#define varying out")

                    // Fix normalMaps compile error
                    content = content.replace("passTangent = osg_MultiTexCoord7.xyzw;", "passTangent = vec4(osg_MultiTexCoord7.xyz, 1.0);")

                }
                else if (it.extension == "comp") {
                    content = content.replace("#version 430 core", "#version 320 es\n#extension GL_EXT_shader_implicit_conversions : enable\nprecision highp float;\nprecision highp int;\nprecision highp image2D;\n\n//HEADER_END\n")
                    content = content.replace("#version 440 core", "#version 320 es\nprecision highp float;\nprecision highp int;\nprecision highp image2D;\n\n//HEADER_END\n")

                    content = content.replace("osg_GlobalInvocationID", "gl_GlobalInvocationID")
                    content = content.replace("osg_LocalInvocationIndex", "gl_LocalInvocationIndex")
                    content = content.replace("osg_WorkGroupID", "gl_WorkGroupID")
                    content = content.replace("ivec2(gl_GlobalInvocationID.xy + offset);", "ivec2(vec2(gl_GlobalInvocationID.xy) + offset);")
                }
                else if (it.extension == "glsl") {
                    content = content.replace("sampler2DShadow", "highp sampler2DShadow")
                    content = content.replace("textureSize2D(diffuseMap, 0);", "vec2(textureSize2D(diffuseMap, 0));")

                    content = content.replace("osg_FragData[0]", "Color0")

                    content = content.replace("if (fog.depth >= 0)", "if (fog.depth >= 0.0)")

                }

                File(it.toString()).writeText(content + "\n#pragma GLES\n")
            }
        }
    }
}
