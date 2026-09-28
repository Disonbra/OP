#!/bin/bash
# Stages the engine dylibs from the ios_build tree into the app's
# per-platform embedded framework directories. Run after build_ios.sh.
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

RESOURCES=(
    defaults.bin
    gamecontrollerdb.txt
    openmw.cfg
)

create_framework_bundle() {
    local src_dylib="$1"
    local dest_dir="$2"
    local fw_name="$3"
    local bin_name="$4"
    local bundle_id="$5"

    local fw_dir="${dest_dir}/${fw_name}.framework"
    mkdir -p "${fw_dir}"

    cp -L "${src_dylib}" "${fw_dir}/${bin_name}"

    cat <<EOF > "${fw_dir}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${bin_name}</string>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${bin_name}</string>
    <key>CFBundlePackageType</key>
    <string>FWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>16.4</string>
</dict>
</plist>
EOF

    install_name_tool -id "@rpath/${fw_name}.framework/${bin_name}" "${fw_dir}/${bin_name}"
}

fix_framework_dependencies() {
    local bin="$1"
    install_name_tool -change "@rpath/libSDL2-2.0.0.dylib" "@rpath/libSDL2.framework/libSDL2" "${bin}" 2>/dev/null || true
    install_name_tool -change "@rpath/libopenal.1.dylib" "@rpath/libopenal.framework/libopenal" "${bin}" 2>/dev/null || true
    install_name_tool -change "@rpath/libcollada-dom2.5-dp.0.dylib" "@rpath/libcollada.framework/libcollada" "${bin}" 2>/dev/null || true
    install_name_tool -change "@rpath/libbz2.1.dylib" "@rpath/libbz2.framework/libbz2" "${bin}" 2>/dev/null || true
    install_name_tool -change "@rpath/libjpeg.62.dylib" "@rpath/libjpeg.framework/libjpeg" "${bin}" 2>/dev/null || true
    install_name_tool -change "@rpath/libz.1.dylib" "@rpath/libz.framework/libz" "${bin}" 2>/dev/null || true
    install_name_tool -change "@rpath/libopenmw.dylib" "@rpath/libopenmw.framework/libopenmw" "${bin}" 2>/dev/null || true
    codesign -f -s - "${bin}" 2>/dev/null || true
}

stage_platform() {
    local platform="$1" dest="$2" openmw_config="$3"
    local prefix="${WORK_DIR}/ios-libs/${platform}"
    local assets_dest="${REPO_DIR}/iosApp/OpenMWAssets"
    rm -rf "${dest}"
    mkdir -p "${dest}"
    mkdir -p "${assets_dest}"

    # Verify dylibs exist in prefix
    local required_dylibs=(
        "libSDL2-2.0.0.dylib"
        "libopenal.1.dylib"
        "libcollada-dom2.5-dp.0.dylib"
        "libbz2.1.dylib"
        "libjpeg.62.dylib"
        "libz.1.dylib"
    )
    for lib in "${required_dylibs[@]}"; do
        if [ ! -e "${prefix}/lib/${lib}" ]; then
            echo "MISSING: ${prefix}/lib/${lib} (run build_ios.sh first)" >&2
            exit 1
        fi
    done

    echo "=== Packaging dynamic frameworks for ${platform} ==="
    create_framework_bundle "${prefix}/lib/libSDL2-2.0.0.dylib" "${dest}" "libSDL2" "libSDL2" "org.openmw.libSDL2"
    create_framework_bundle "${prefix}/lib/libopenal.1.dylib" "${dest}" "libopenal" "libopenal" "org.openmw.libopenal"
    create_framework_bundle "${prefix}/lib/libcollada-dom2.5-dp.0.dylib" "${dest}" "libcollada" "libcollada" "org.openmw.libcollada"
    create_framework_bundle "${prefix}/lib/libbz2.1.dylib" "${dest}" "libbz2" "libbz2" "org.openmw.libbz2"
    create_framework_bundle "${prefix}/lib/libjpeg.62.dylib" "${dest}" "libjpeg" "libjpeg" "org.openmw.libjpeg"
    create_framework_bundle "${prefix}/lib/libz.1.dylib" "${dest}" "libz" "libz" "org.openmw.libz"

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

    # Copy default settings.cfg from buildscripts
    if [ -f "${REPO_DIR}/buildscripts/settings.cfg" ]; then
        cp "${REPO_DIR}/buildscripts/settings.cfg" "${assets_dest}/settings.cfg"
        echo "Copied default settings.cfg to OpenMWAssets"
    fi

    # Copy pointer_arrow.png from buildscripts
    if [ -f "${REPO_DIR}/buildscripts/UI/pointer_arrow.png" ]; then
        cp "${REPO_DIR}/buildscripts/UI/pointer_arrow.png" "${assets_dest}/pointer_arrow.png"
        echo "Copied pointer_arrow.png to OpenMWAssets"
    elif [ -f "${REPO_DIR}/buildscripts/pointer_arrow.png" ]; then
        cp "${REPO_DIR}/buildscripts/pointer_arrow.png" "${assets_dest}/pointer_arrow.png"
        echo "Copied pointer_arrow.png to OpenMWAssets"
    fi

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

    # libopenmw comes from the engine build dir
    local openmw=""
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

    create_framework_bundle "${openmw}" "${dest}" "libopenmw" "libopenmw" "org.openmw.libopenmw"

    # Fix dependencies and sign all framework binaries
    for fw in "${dest}"/*.framework; do
        bin_name=$(basename "$fw" .framework)
        fix_framework_dependencies "${fw}/${bin_name}"
    done

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
