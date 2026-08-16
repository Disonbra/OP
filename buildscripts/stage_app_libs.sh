#!/bin/bash
# Stages the engine dylibs from the ios_build tree into the app's
# per-platform embedded-library directories. Run after build_ios.sh.
#
#   ./buildscripts/stage_app_libs.sh            # stage both platforms
#   ./buildscripts/stage_app_libs.sh device     # device only
#   ./buildscripts/stage_app_libs.sh sim        # simulator only
#
# The Xcode project's "Select Platform Libraries" build phase copies the
# right set into iosApp/EmbeddedLibs/ at build time.
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${REPO_DIR}/ios_build"
OPENMW_SRC=$(ls -d "${WORK_DIR}/src/"openmw-* 2>/dev/null | head -1)

DYLIBS=(
    libSDL2-2.0.0.dylib
    libopenal.1.dylib
    libcollada-dom2.5-dp.0.dylib
    libbz2.1.dylib
    libjpeg.62.dylib
    libz.1.dylib
)

RESOURCES=(
    defaults.bin
    gamecontrollerdb.txt
    openmw.cfg
)

stage_platform() {
    local platform="$1" dest="$2" openmw_config="$3"
    local prefix="${WORK_DIR}/ios-libs/${platform}"
    local assets_dest="${REPO_DIR}/iosApp/OpenMWAssets"
    mkdir -p "${dest}"
    mkdir -p "${assets_dest}"

    for lib in "${DYLIBS[@]}"; do
        if [ ! -e "${prefix}/lib/${lib}" ]; then
            echo "MISSING: ${prefix}/lib/${lib} (run build_ios.sh first)" >&2
            exit 1
        fi
        cp -L "${prefix}/lib/${lib}" "${dest}/${lib}"
    done

    # Copy resources to OpenMWAssets
    local resources_src="${OPENMW_SRC}/build_openmw_${platform}/OpenMW.app/Contents/Resources"
    for res in "${RESOURCES[@]}"; do
        if [ -e "${resources_src}/${res}" ]; then
            cp -L "${resources_src}/${res}" "${assets_dest}/${res}"
            echo "Copied ${res} to OpenMWAssets"
        elif [ -e "${resources_src}/${openmw_config}/${res}" ]; then
            cp -L "${resources_src}/${openmw_config}/${res}" "${assets_dest}/${res}"
            echo "Copied ${openmw_config}/${res} to OpenMWAssets"
        else
            echo "WARNING: Resource ${res} not found in ${resources_src} (or ${openmw_config}/ subfolder)"
        fi
    done

    # Copy the resources folder (always from Release)
    if [ -d "${resources_src}/Release/resources" ]; then
        echo "Copying resources folder from Release..."
        rm -rf "${assets_dest}/resources"
        cp -R "${resources_src}/Release/resources" "${assets_dest}/resources"
        echo "Copied resources folder to OpenMWAssets"
    fi

    # Fix openmw.cfg to use local paths
    if [ -f "${assets_dest}/openmw.cfg" ]; then
        sed -i '' 's|\${OPENMW_RESOURCE_FILES}|resources|g' "${assets_dest}/openmw.cfg"
        sed -i '' 's|resources=../Resources/resources|resources=resources|g' "${assets_dest}/openmw.cfg"
        sed -i '' 's|data=../Resources/resources/vfs-mw|data=resources/vfs-mw|g' "${assets_dest}/openmw.cfg"
    fi

    # SDL's debug build names itself libSDL2-2.0d; normalise the id so it
    # matches libopenmw's load command.
    install_name_tool -id @rpath/libSDL2-2.0.0.dylib "${dest}/libSDL2-2.0.0.dylib"
    codesign -f -s - "${dest}/libSDL2-2.0.0.dylib" 2>/dev/null || true

    # libopenmw comes from the engine build dir (the buildscript does not
    # install it into the prefix).
    local openmw=""
    # Check candidates: prefix, then the requested config, then fallbacks
    local candidates=(
        "${prefix}/lib/libopenmw.dylib"
        "${OPENMW_SRC}/build_openmw_${platform}/OpenMW.app/Contents/MacOS/${openmw_config}/libopenmw.dylib"
        "${OPENMW_SRC}/build_openmw_${platform}/OpenMW.app/Contents/MacOS/Release/libopenmw.dylib"
        "${OPENMW_SRC}/build_openmw_${platform}/OpenMW.app/Contents/MacOS/Debug/libopenmw.dylib"
        "${OPENMW_SRC}/build_openmw_${platform}/OpenMW.app/Contents/MacOS/RelWithDebInfo/libopenmw.dylib"
    )

    for candidate in "${candidates[@]}"; do
        if [ -e "${candidate}" ]; then openmw="${candidate}"; break; fi
    done
    if [ -z "${openmw}" ]; then
        echo "MISSING: libopenmw.dylib for ${platform} (build OpenMW first)" >&2
        exit 1
    fi
    cp -L "${openmw}" "${dest}/libopenmw.dylib"
    echo "Staged ${platform} -> ${dest}"
}

case "${1:-both}" in
    device) stage_platform OS64 "${REPO_DIR}/iosApp/EmbeddedLibsDevice" Release ;;
    sim)    stage_platform SIMULATORARM64 "${REPO_DIR}/iosApp/EmbeddedLibsSim" Release ;;
    both)
        stage_platform OS64 "${REPO_DIR}/iosApp/EmbeddedLibsDevice" Release
        stage_platform SIMULATORARM64 "${REPO_DIR}/iosApp/EmbeddedLibsSim" Release
        ;;
    *) echo "usage: $0 [device|sim|both]" >&2; exit 1 ;;
esac
