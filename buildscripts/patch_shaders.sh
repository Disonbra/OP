#!/bin/bash
# patch_shaders.sh
# Ported from Kotlin patching logic in App.kt

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SHADERS_DIR="${REPO_DIR}/iosApp/OpenMWAssets/resources/shaders"

SHADERS_DIR="${1:-$DEFAULT_SHADERS_DIR}"
if [ -z "$SHADERS_DIR" ]; then
    echo "Usage: $0 <shaders_directory>"
    exit 1
fi

if [ ! -d "$SHADERS_DIR" ]; then
    echo "Error: Directory $SHADERS_DIR not found."
    exit 1
fi

echo "=== Patching Shaders in $SHADERS_DIR ==="

# --- Part 1: patchShadersLinking (Specific files) ---

# lib/core/vertex.h.glsl
VERTEX_H="$SHADERS_DIR/lib/core/vertex.h.glsl"
VERTEX_GLSL="$SHADERS_DIR/lib/core/vertex.glsl"
if [ -f "$VERTEX_H" ] && ! grep -q "#pragma CONVERTED" "$VERTEX_H"; then
    echo "  - Patching vertex.h.glsl"
    content=$(cat "$VERTEX_GLSL")
    # Apply replacements from Kotlin code
    content=$(echo "$content" | perl -pe 's/#version 120/vec4 modelToView(vec4 pos);/')
    content=$(echo "$content" | perl -pe 's/uniform vec2 screenRes;/ \/\/uniform vec2 screenRes;/')
    content=$(echo "$content" | perl -pe 's|lib/core/vertex.h.glsl"|lib/core/lighting_vertex_impl.glsl"\n#include "lib/material/struct.glsl"|g')
    printf "%s\n#pragma CONVERTED\n" "$content" > "$VERTEX_H"
fi

# lib/core/fragment.h.glsl
FRAGMENT_H="$SHADERS_DIR/lib/core/fragment.h.glsl"
FRAGMENT_GLSL="$SHADERS_DIR/lib/core/fragment.glsl"
if [ -f "$FRAGMENT_H" ] && ! grep -q "#pragma CONVERTED" "$FRAGMENT_H"; then
    echo "  - Patching fragment.h.glsl"
    content=$(cat "$FRAGMENT_GLSL")
    content=$(echo "$content" | perl -pe 's/#version 120//')
    content=$(echo "$content" | perl -pe 's|lib/core/fragment.h.glsl"|lib/core/lighting_fragment_impl.glsl"\n#include "lib/material/struct.glsl"|g')
    printf "%s\n#pragma CONVERTED\n" "$content" > "$FRAGMENT_H"
fi

# compatibility/objects.frag
OBJECTS_FRAG="$SHADERS_DIR/compatibility/objects.frag"
if [ -f "$OBJECTS_FRAG" ] && ! grep -q "#pragma CONVERTED" "$OBJECTS_FRAG"; then
    echo "  - Patching objects.frag"
    perl -i -pe 's/uniform vec2 screenRes;/ \/\/uniform vec2 screenRes;/g' "$OBJECTS_FRAG"
    perl -i -pe 's/uniform float near;/ \/\/uniform float near;/g' "$OBJECTS_FRAG"
    echo "#pragma CONVERTED" >> "$OBJECTS_FRAG"
fi

# compatibility/objects.vert
OBJECTS_VERT="$SHADERS_DIR/compatibility/objects.vert"
if [ -f "$OBJECTS_VERT" ] && ! grep -q "#pragma CONVERTED" "$OBJECTS_VERT"; then
    echo "  - Patching objects.vert"
    perl -i -pe 's/uniform vec2 screenRes;/ \/\/uniform vec2 screenRes;/g' "$OBJECTS_VERT"
    echo "#pragma CONVERTED" >> "$OBJECTS_VERT"
fi

# compatibility/terrain.frag
TERRAIN_FRAG="$SHADERS_DIR/compatibility/terrain.frag"
if [ -f "$TERRAIN_FRAG" ] && ! grep -q "#pragma CONVERTED" "$TERRAIN_FRAG"; then
    echo "  - Patching terrain.frag"
    perl -i -pe 's/uniform vec2 screenRes;/ \/\/uniform vec2 screenRes;/g' "$TERRAIN_FRAG"
    perl -i -pe 's/uniform float near;/ \/\/uniform float near;/g' "$TERRAIN_FRAG"
    echo "#pragma CONVERTED" >> "$TERRAIN_FRAG"
fi

# compatibility/groundcover.frag
GROUNDCOVER_FRAG="$SHADERS_DIR/compatibility/groundcover.frag"
if [ -f "$GROUNDCOVER_FRAG" ] && ! grep -q "#pragma CONVERTED" "$GROUNDCOVER_FRAG"; then
    echo "  - Patching groundcover.frag"
    perl -i -pe 's/uniform vec2 screenRes;/ \/\/uniform vec2 screenRes;/g' "$GROUNDCOVER_FRAG"
    echo "#pragma CONVERTED" >> "$GROUNDCOVER_FRAG"
fi

# compatibility/groundcover.vert
GROUNDCOVER_VERT="$SHADERS_DIR/compatibility/groundcover.vert"
if [ -f "$GROUNDCOVER_VERT" ] && ! grep -q "#pragma CONVERTED" "$GROUNDCOVER_VERT"; then
    echo "  - Patching groundcover.vert"
    perl -i -0777 -pe 's|#include "lib/light/clamp.glsl"\n#include|#include|g' "$GROUNDCOVER_VERT"
    echo "#pragma CONVERTED" >> "$GROUNDCOVER_VERT"
fi

# compatibility/water.frag
WATER_FRAG="$SHADERS_DIR/compatibility/water.frag"
if [ -f "$WATER_FRAG" ] && ! grep -q "#pragma CONVERTED" "$WATER_FRAG"; then
    echo "  - Patching water.frag"
    perl -i -pe 's/uniform vec2 screenRes;/ \/\/uniform vec2 screenRes;/g' "$WATER_FRAG"
    perl -i -pe 's/uniform float near;/ \/\/uniform float near;/g' "$WATER_FRAG"
    perl -i -pe 's/uniform DirectionalLight sun;/ \/\/uniform DirectionalLight sun;/g' "$WATER_FRAG"
    echo "#pragma CONVERTED" >> "$WATER_FRAG"
fi

# lib/light/util.glsl
LIGHTUTIL="$SHADERS_DIR/lib/light/util.glsl"
if [ -f "$LIGHTUTIL" ] && ! grep -q "#pragma CONVERTED" "$LIGHTUTIL"; then
    echo "  - Patching light/util.glsl"
    perl -i -pe 's/\* int\(gridSize.z\)\) \//\* gridSize.z) \//g' "$LIGHTUTIL"
    echo "#pragma CONVERTED" >> "$LIGHTUTIL"
fi

# compatibility/fog.glsl
FOG_GLSL="$SHADERS_DIR/compatibility/fog.glsl"
if [ -f "$FOG_GLSL" ] && ! grep -q "#pragma CONVERTED" "$FOG_GLSL"; then
    echo "  - Patching fog.glsl"
    perl -i -pe 's/#include/\/\//g' "$FOG_GLSL"
    echo "#pragma CONVERTED" >> "$FOG_GLSL"
fi


# --- Part 2: patchShadersToGLES (All files) ---

find "$SHADERS_DIR" -type f \( -name "*.vert" -o -name "*.frag" -o -name "*.comp" -o -name "*.glsl" \) | while read -r file; do
    if grep -q "#pragma GLES" "$file"; then
        continue
    fi

    echo "  - Converting to GLES: $(basename "$file")"

    # Replace version and add basic headers
    # Note: Convert both 120 and 320 to 300 es
    perl -i -pe 's/#version 120/#version 300 es\nprecision highp float;\nprecision highp int;\n\n\/\/HEADER_END\n/g' "$file"
    perl -i -pe 's/#version 320 es/#version 300 es\nprecision highp float;\nprecision highp int;\n\n\/\/HEADER_END\n/g' "$file"

    # Extensions and gl_ build-ins
    perl -i -pe 's/#extension/\/\/extension/g' "$file"
    perl -i -pe 's/gl_/osg_/g' "$file"
    perl -i -pe 's/osg_Position/gl_Position/g' "$file"
    perl -i -pe 's/osg_FragCoord/gl_FragCoord/g' "$file"
    perl -i -pe 's/osg_ClipDistance/gl_ClipDistance/g' "$file"
    perl -i -pe 's/osg_CullDistance/gl_CullDistance/g' "$file"

    # Uniform default values
    perl -i -pe 's/uniform bool useAdvancedShader = false;/uniform bool useAdvancedShader;/g' "$file"
    perl -i -pe 's/uniform vec2 scaling = vec2\(1.0, 1.0\);/uniform vec2 scaling;/g' "$file"
    perl -i -pe 's/uniform bool useDiffuseMapForShadowAlpha = true;/uniform bool useDiffuseMapForShadowAlpha;/g' "$file"
    perl -i -pe 's/uniform bool alphaTestShadows = true;/uniform bool alphaTestShadows;/g' "$file"

    ext="${file##*.}"
    filename=$(basename "$file")

    if [ "$ext" = "frag" ]; then
        # Add osg built-in uniforms
        perl -i -pe 's|\/\/HEADER_END\n|uniform mat4 osg_ModelViewMatrix;\nuniform mat3 osg_NormalMatrix;\n\/\/HEADER_END\n|g' "$file"

        # osg_ModelViewMatrixInverse replacement
        perl -i -pe 's/osg_ModelViewMatrixInverse/inverse(osg_ModelViewMatrix)/g' "$file"

        # Fragment output variables
        perl -i -pe 's|\/\/HEADER_END\n|layout(location = 0) out vec4 Color0;\nlayout(location = 1) out vec4 Color1;\n\/\/HEADER_END\n|g' "$file"
        perl -i -pe 's/osg_FragData\[0\]/Color0/g' "$file"
        perl -i -pe 's/osg_FragData\[1\]/Color1/g' "$file"
        perl -i -pe 's/osg_FragColor/Color0/g' "$file"

        # Defines
        header_add="#define texture2D texture\n#define textureSize2D textureSize\n#define varying in\n#define shadow2DProj custom_shadow2DProj\n"
        perl -i -pe "s|\/\/HEADER_END\n|$header_add\/\/HEADER_END\n|g" "$file"

    elif [ "$ext" = "vert" ]; then
        # clipplane
        perl -i -pe 's/#version 300 es\n/#version 300 es\n#extension GL_EXT_clip_cull_distance : enable\n/g' "$file"
        perl -i -pe 's/osg_ClipVertex = viewPos;//g' "$file"

        if [[ "$filename" == *"terrain_composite"* ]]; then
            perl -i -pe 's/osg_ModelViewMatrix \* //g' "$file"
        fi

        if [[ "$filename" == *"shadowcasting"* ]]; then
             perl -i -pe 's/    vec4 viewPos/#if !defined(USE_DEPTH_CLAMP)\n    gl_Position.z = max(gl_Position.z, -gl_Position.w);\n#endif\n    vec4 viewPos/g' "$file"
        fi

        # osg attributes/uniforms
        header_add="in vec4 osg_Vertex;\nin vec3 osg_Normal;\nin vec4 osg_Color;\nin vec3 osg_MultiTexCoord0;\nin vec3 osg_MultiTexCoord1;\nin vec3 osg_MultiTexCoord2;\nin vec3 osg_MultiTexCoord3;\nin vec3 osg_MultiTexCoord4;\nin vec3 osg_MultiTexCoord5;\nin vec3 osg_MultiTexCoord6;\nin vec3 osg_MultiTexCoord7;\nuniform mat4 osg_ModelViewProjectionMatrix;\nuniform mat4 osg_ModelViewMatrix;\nuniform mat3 osg_NormalMatrix;\n#define attribute in\n#define varying out\n"
        perl -i -pe "s|\/\/HEADER_END\n|$header_add\/\/HEADER_END\n|g" "$file"

        # Normal maps compile error fix
        perl -i -pe 's/passTangent = osg_MultiTexCoord7.xyzw;/passTangent = vec4(osg_MultiTexCoord7.xyz, 1.0);/g' "$file"

    elif [ "$ext" = "comp" ]; then
        perl -i -pe 's/#version 430 core/#version 300 es\n#extension GL_EXT_shader_implicit_conversions : enable\nprecision highp float;\nprecision highp int;\nprecision highp image2D;\n\n\/\/HEADER_END\n/g' "$file"
        perl -i -pe 's/#version 440 core/#version 300 es\nprecision highp float;\nprecision highp int;\nprecision highp image2D;\n\n\/\/HEADER_END\n/g' "$file"

        perl -i -pe 's/osg_GlobalInvocationID/gl_GlobalInvocationID/g' "$file"
        perl -i -pe 's/osg_LocalInvocationIndex/gl_LocalInvocationIndex/g' "$file"
        perl -i -pe 's/osg_WorkGroupID/gl_WorkGroupID/g' "$file"
        perl -i -pe 's/ivec2\(gl_GlobalInvocationID.xy \+ offset\);/ivec2(vec2(gl_GlobalInvocationID.xy) + offset);/g' "$file"

    elif [ "$ext" = "glsl" ]; then
        perl -i -pe 's/sampler2DShadow/highp sampler2DShadow/g' "$file"
        perl -i -pe 's/textureSize2D\(diffuseMap, 0\);/vec2(textureSize2D(diffuseMap, 0));/g' "$file"
        perl -i -pe 's/osg_FragData\[0\]/Color0/g' "$file"
        perl -i -pe 's/if \(fog.depth >= 0\)/if (fog.depth >= 0.0)/g' "$file"
    fi

    echo -e "\n#pragma GLES" >> "$file"
done

echo "=== Shader Patching Complete ==="
