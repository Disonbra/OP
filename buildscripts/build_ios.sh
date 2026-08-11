#!/usr/bin/env bash
# build_ios_libs.sh
# Full block skipping: if already installed, skip download + build entirely

set -e  # Exit on error

# ------------------- Logging Setup -------------------
LOG_FILE="$(pwd)/ios_build/build.log"
mkdir -p "$(dirname "${LOG_FILE}")"
echo "=== Build started at $(date) ===" > "${LOG_FILE}"

# Redirect all output to log file + terminal (only if running interactively)
if [[ -t 1 ]]; then  # Check if stdout is a terminal
    exec > >(tee -ia "${LOG_FILE}")
    exec 2>&1
fi

# ------------------- Configuration -------------------
WORK_DIR="$(pwd)/ios_build"
PATCHES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/patches" && pwd)"
SRC_DIR="${WORK_DIR}/src"
TOOLCHAIN_DIR="${WORK_DIR}/ios-cmake"
PREFIX="${WORK_DIR}/ios-libs"
DEVICE_PREFIX="${PREFIX}/OS64"
SIM_PREFIX="${PREFIX}/SIMULATORARM64"
MARKERS_DIR="${PREFIX}/markers"
BUILD_JOBS=$(sysctl -n hw.logicalcpu)

DEPLOYMENT_TARGET="26.2"
COMMON_FLAGS="-O3 -fPIC -stdlib=libc++"

LIBJPEG_TURBO_VERSION=3.1.0
LIBPNG_VERSION=1.6.48
BROTLI_VERSION=1.2.0
FREETYPE2_VERSION=2.14.1
OPENAL_VERSION=1.24.3
BOOST_VERSION=1.88.0
LIBICU_VERSION=78.1
FFMPEG_VERSION=7.1.1
SDL2_VERSION=2.32.4
BULLET_VERSION=3.25
ZLIB_VERSION=1.3.2
LIBXML2_VERSION=2.14.3
MYGUI_VERSION=3.4.3
GL4ES_VERSION=2d7949c0ad55e850f9aa9ed28f5e6ff6490984ee
COLLADA_DOM_VERSION=2.5.0
OSG_VERSION=495b370da37d9e3c739914a190f9821884619a4a
LZ4_VERSION=1.10.0
LUA_VERSION=5.1.5
LUAJIT_VERSION=2.1.ROLLING
OPENMW_VERSION=96565e9afb9bbebf77c1bbc108d5bf4f9bee2e6f
RECAST_VERSION=455a019e7aef99354ac3020f04c1fe3541aa4d19
VSG_VERSION=1.0.9
VSGXCHANGE_VERSION=1.0.5
VSGOPENMW_VERSION=0.2
XZ_VERSION=5.8.2

mkdir -p "${SRC_DIR}" "${PREFIX}" "${MARKERS_DIR}"
cd "${WORK_DIR}"

if [ ! -d "${TOOLCHAIN_DIR}" ]; then
    echo "=== Downloading ios-cmake toolchain ==="
    git clone https://github.com/leetal/ios-cmake.git "${TOOLCHAIN_DIR}"
fi

TOOLCHAIN_FILE="${TOOLCHAIN_DIR}/ios.toolchain.cmake"

# ------------------- Skip helper -------------------
skip_if_installed() {
    local lib_name="$1"
    local marker="${MARKERS_DIR}/${lib_name}.installed"

    if [ -f "${marker}" ]; then
        echo "=== Skipping ${lib_name} entirely (already built and installed) ==="
        return 0  # skip the whole block
    else
        return 1  # proceed
    fi
}

mark_as_installed() {
    local lib_name="$1"
    touch "${MARKERS_DIR}/${lib_name}.installed"
    echo "=== ${lib_name} built and marked as installed ==="
}

# ------------------- Configure-based build functions -------------------
build_configure_platform_lib() {
    local name="$1"
    local platform="$2"
    local src_dir="$3"
    shift 3
    local configure_args=("$@")
    
    local build_dir="build_${name}_${platform}"
    local install_prefix="${PREFIX}/${platform}"
    
    echo "=== Building ${name} for ${platform} using configure ==="
    mkdir -p "${build_dir}" && cd "${build_dir}"
    
    # Set SDK path based on platform
    if [ "${platform}" = "OS64" ]; then
        IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
        ARCH="arm64"
        MIN_VERSION_FLAG="-miphoneos-version-min=${DEPLOYMENT_TARGET}"
    else  # SIMULATORARM64
        IOS_SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
        ARCH="arm64"  # Apple Silicon simulators use arm64
        MIN_VERSION_FLAG="-mios-simulator-version-min=${DEPLOYMENT_TARGET}"
    fi
    
    # Common configure flags
    CFLAGS="${COMMON_FLAGS} -isysroot ${IOS_SDK_PATH} -arch ${ARCH} ${MIN_VERSION_FLAG}"
    CPPFLAGS="-isysroot ${IOS_SDK_PATH}"
    LDFLAGS="-isysroot ${IOS_SDK_PATH}"
    
    # Run configure
    if [[ "${name}" == *"ffmpeg"* ]]; then
        # FFmpeg configure with its own flags; sysroot and arch flags must
        # match the platform being built or simulator builds silently get
        # device objects.
        "${src_dir}/configure" \
            --prefix="${install_prefix}" \
            --sysroot="${IOS_SDK_PATH}" \
            --extra-cflags="-arch ${ARCH} ${MIN_VERSION_FLAG} ${COMMON_FLAGS}" \
            --extra-ldflags="-arch ${ARCH} -isysroot ${IOS_SDK_PATH}" \
            "${configure_args[@]}"
    else
        # Standard configure for other libraries
        "${src_dir}/configure" \
            --host=arm-apple-darwin \
            --prefix="${install_prefix}" \
            --enable-static \
            --disable-shared \
            CFLAGS="${CFLAGS}" \
            CPPFLAGS="${CPPFLAGS}" \
            LDFLAGS="${LDFLAGS}" \
            "${configure_args[@]}"
    fi
    
    make -j"${BUILD_JOBS}"
    make install
    
    cd ..
}

build_configure_dual_platform() {
    local name="$1"
    local src_dir="$2"
    shift 2
    local configure_args=("$@")
    
    # Build for device
    if skip_if_installed "${name}_device"; then true; else
        cd "${src_dir}"
        build_configure_platform_lib "${name}" "OS64" "${src_dir}" "${configure_args[@]}"
        
        mark_as_installed "${name}_device"
    fi
    
    # Build for simulator
    if skip_if_installed "${name}_sim"; then true; else
        cd "${src_dir}"
        build_configure_platform_lib "${name}" "SIMULATORARM64" "${src_dir}" "${configure_args[@]}"

        mark_as_installed "${name}_sim"
    fi
}

# ------------------- Modified build function -------------------
build_dual_platform() {
    local name="$1"
    local src_dir="$2"
    shift 2
    local extra_args=("$@")
    
    # Build for device
    if skip_if_installed "${name}_device"; then true; else
        echo "=== Building ${name} for device ==="
        cd "${src_dir}"
        
        # Process arguments for device
        local device_args=()
        for arg in "${extra_args[@]}"; do
            device_args+=("${arg//\$\{PLATFORM_PREFIX\}/${PREFIX}/OS64}")
        done
        
        build_platform_lib "${name}" "OS64" "${src_dir}" "${extra_args[@]}"
        
        mark_as_installed "${name}_device"
    fi
    
    
    if skip_if_installed "${name}_sim"; then true; else
        echo "=== Building ${name} for simulator ==="
        cd "${src_dir}"
        
        # Process arguments for simulator
        local sim_args=()
        for arg in "${extra_args[@]}"; do
            sim_args+=("${arg//\$\{PLATFORM_PREFIX\}/${PREFIX}/SIMULATORARM64}")
        done
       
        build_platform_lib "${name}" "SIMULATORARM64" "${src_dir}" "${extra_args[@]}"
        
        mark_as_installed "${name}_sim"
    fi
}

# ------------------- Modified build function -------------------
build_platform_lib() {
    local name="$1"
    local platform="$2"  # "OS64" or "SIMULATORARM64"
    local src_dir="$3"
    shift 3
    local extra_args=("$@")
    
    local build_dir="build_${name}_${platform}"
    local install_prefix="${PREFIX}/${platform}"
    
    mkdir -p "${build_dir}" && cd "${build_dir}"
    
    cmake "${src_dir}" \
        -G Xcode \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DCMAKE_IGNORE_PATH="/usr;/usr/local;/opt/local;/opt/homebrew" \
        -DCMAKE_SYSTEM_IGNORE_PATH="/usr;/usr/local" \
        -DCMAKE_PREFIX_PATH="${install_prefix}" \
        -DCMAKE_FIND_ROOT_PATH="${install_prefix}" \
        -DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=TRUE \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DPLATFORM="${platform}" \
        -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
        -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_FIND_ROOT_PATH="${install_prefix}" \
        -DDEFAULT_ES=2 -DNOX11=1 -DNOEGL=1 -DSTATICLIB=0 \
        -DCMAKE_C_FLAGS="${COMMON_FLAGS}" \
        -DCMAKE_CXX_FLAGS="-I${install_prefix}/include/ -I${install_prefix}/include/freetype2/ ${COMMON_FLAGS}" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DOPENGL_INCLUDE_DIR="${install_prefix}/include/gl4es/include/" \
        -DMyGUI_LIBRARY="${install_prefix}/lib/libMyGUIEngineStatic.a" \
        -DOPENGL_gl_LIBRARY="${install_prefix}/lib/libGL.dylib" \
        -DOPENGL_glx_LIBRARY="${install_prefix}/lib/libGL.dylib" \
        -DOPENAL_INCLUDE_DIR="${install_prefix}/include/AL/" \
        -DBullet_INCLUDE_DIR="${install_prefix}/include/bullet/" \
        -DJPEG_INCLUDE_DIR="${install_prefix}/include/" \
        -DPNG_INCLUDE_DIR="${install_prefix}/include/" \
        -DPNG_LIBRARY="${install_prefix}/lib/libpng16.a" \
        -DCOLLADA_INCLUDE_DIR="${install_prefix}/include/collada-dom2.5/" \
        -DCOLLADA_DOM_ROOT="${install_prefix}/include/collada-dom2.5/1.4/dom" \
        -Wno-deprecated -Wno-dev \
        -DIOS_DEPS_PREFIX="${install_prefix}" \
        "${extra_args[@]}"
    
    cmake --build . --config Release -j"${BUILD_JOBS}"
    cmake --install . --config Release
    
    # gl4es upstream has no CMake install rules: stage the dylib and the
    # headers into the prefix ourselves. The dylib output path is shared
    # between the device and simulator builds, so this must run right
    # after each platform's build (or the second build overwrites the
    # first's dylib).
    if [[ "${name}" == *"gl4es"* ]]; then
        echo "=== Installing gl4es into ${install_prefix} ==="
        mkdir -p "${install_prefix}/lib" "${install_prefix}/include/gl4es"
        cp "${src_dir}/lib/Release/libGL.dylib" "${install_prefix}/lib/libGL.dylib"
        # Both header layouts are consumed: OSG/OpenMW are pointed at
        # include/gl4es/include/ via OPENGL_INCLUDE_DIR, and other code
        # includes <GL/gl.h> from the flat include dir.
        cp -r "${src_dir}/include" "${install_prefix}/include/gl4es/"
        cp -r "${src_dir}/include/"* "${install_prefix}/include/"
    fi
    
    cd ..
}

# ------------------- ICU (universal static, device + simulator) -------------------
if skip_if_installed "icu"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "icu-release-${LIBICU_VERSION}" ]; then
        wget -c https://github.com/unicode-org/icu/archive/refs/tags/release-${LIBICU_VERSION}.tar.gz -O - | tar -xz
    fi
    
    if [ ! -d "${SRC_DIR}/icu_host_build" ]; then
        echo "=== Building ICU for host ==="
        mkdir -p icu_host_build && cd icu_host_build
        "${SRC_DIR}/icu-release-${LIBICU_VERSION}/icu4c/source/configure" \
            --prefix="$(pwd)/install" \
            --disable-tests \
            --disable-samples \
            --disable-icuio \
            --disable-extras
        make -j"${BUILD_JOBS}"
        cd ..
    fi
    
    build_configure_dual_platform "icu" "${SRC_DIR}/icu-release-${LIBICU_VERSION}/icu4c/source" \
        --disable-tests \
        --disable-samples \
        --disable-icuio \
        --disable-extras \
        --disable-tools \
        --with-cross-build="${SRC_DIR}/icu_host_build"
fi

# ------------------- Bzip2 -------------------
if skip_if_installed "bzip2"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "bzip2" ]; then
        echo "=== Downloading and building bzip2 ==="
        git clone https://github.com/libarchive/bzip2.git
    fi
    
    build_dual_platform "bzip2" "${SRC_DIR}/bzip2" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_STATIC_LIBS=ON \
        -DENABLE_APP=OFF
fi

# ------------------- Luajit -------------------
if skip_if_installed "luajit"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "luajit" ]; then
        echo "=== Downloading and building luajit ==="
        git clone https://github.com/mpvkit/libluajit-build.git luajit
    fi
    
    cd luajit
    make build platform=ios,isimulator XCFLAGS+="-DLUAJIT_ENABLE_GC64"
    
    # Copy include files to both device and simulator prefixes
    echo "=== Copying Luajit headers ==="
    cp -Rf dist/release/libluajit/include/luajit-2.1/* "${DEVICE_PREFIX}/include/"
    cp -Rf dist/release/libluajit/include/luajit-2.1/* "${SIM_PREFIX}/include/"
    
    # Copy libraries to respective prefixes
    echo "=== Copying Luajit libraries ==="
    cp -f dist/release/libluajit/lib/ios/thin/arm64/lib/libluajit.a "${DEVICE_PREFIX}/lib/"
    cp -f dist/release/libluajit/lib/isimulator/thin/arm64/lib/libluajit.a "${SIM_PREFIX}/lib/"
    
    mark_as_installed "luajit"
fi

# ------------------- Zlib -------------------
if skip_if_installed "zlib"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "zlib-${ZLIB_VERSION}" ]; then
        echo "=== Downloading and building zlib ==="
        wget -c https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz -O - | tar -xz
    fi

    build_dual_platform "zlib" "${SRC_DIR}/zlib-${ZLIB_VERSION}"
fi

# ------------------- libpng -------------------
if skip_if_installed "libpng"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "libpng-${LIBPNG_VERSION}" ]; then
        echo "=== Downloading and building libpng ==="
        wget -c https://downloads.sourceforge.net/project/libpng/libpng16/${LIBPNG_VERSION}/libpng-${LIBPNG_VERSION}.tar.gz -O - | tar -xz
    fi

    # Build for both platforms using configure
    build_configure_dual_platform "libpng" "${SRC_DIR}/libpng-${LIBPNG_VERSION}"
fi

# ------------------- FreeType -------------------
if skip_if_installed "freetype"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "freetype-${FREETYPE2_VERSION}" ]; then
        echo "=== Downloading and building freetype ==="
        wget -c https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE2_VERSION}.tar.xz -O - | tar -xJ
    fi
    
    build_dual_platform "freetype" "${SRC_DIR}/freetype-${FREETYPE2_VERSION}"
fi

# ------------------- GL4ES_114 -------------------
if skip_if_installed "gl4es"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "gl4es" ]; then
        echo "=== Downloading and building GL4ES (OpenMW branch) ==="
        git clone https://github.com/khanhduytran0/gl4es.git gl4es
        # Pin to the commit gl4es_114.patch was written against; upstream
        # master can drift and break the patch.
        git -C ${SRC_DIR}/gl4es checkout e095812c2ff29971ca76c481035934fbac976ce0
        patch -d ${SRC_DIR}/gl4es/ -p1 -t -N < ${PATCHES_DIR}/gl4es_114.patch
    fi

    build_dual_platform "gl4es" "${SRC_DIR}/gl4es"
fi

# ------------------- NG-GL4ES -------------------
#if skip_if_installed "ng-gl4es"; then true; else
#    cd "${SRC_DIR}"
#    if [ ! -d "ng-gl4es" ]; then
#        echo "=== Downloading and building NG-GL4ES (OpenMW branch) ==="
#        wget -c https://github.com/Duron27/NG-GL4ES/archive/refs/heads/iOS.zip -O iOS.zip
#        unzip -q iOS.zip
#        mv NG-GL4ES-iOS ng-gl4es
#        rm -f iOS.zip
#    fi
    
#    build_dual_platform "ng-gl4es" "${SRC_DIR}/ng-gl4es" \
#        -DNOEGL=ON \
#        -DNOX11=ON \
#        -DSTATICLIB=OFF
#fi

# ------------------- GL4ES -------------------
#if skip_if_installed "gl4es"; then true; else
#    cd "${SRC_DIR}"
#    if [ ! -d "gl4es" ]; then
#        echo "=== Downloading and building GL4ES (OpenMW branch) ==="
#        git clone https://github.com/ptitSeb/gl4es.git gl4es
#        patch -d ${SRC_DIR}/gl4es/ -p1 -t -N < ${PATCHES_DIR}/gl4es_ios.patch
#    fi
    
#    build_dual_platform "gl4es" "${SRC_DIR}/gl4es" \
#        -DNOEGL=ON \
#        -DNOX11=ON \
#        -DDEFAULT_ES=2 \
#        -DSTATICLIB=OFF
#fi

# zink, moltenvk
# Set Python environment variables
# export PYTHONPATH="/Users/mac/Library/Python/3.9/lib/python/site-packages:$PYTHONPATH"
# export PATH="/Users/mac/Library/Python/3.9/bin:$PATH"


# brew install meson ninja pkg-config bison flex, pip3 install mako
# pip3 install pyyaml
# git clone https://github.com/KhronosGroup/MoltenVK.git
# inside folder, ./fetchDependencies --ios
# make ios

# git clone https://gitlab.freedesktop.org/mesa/mesa.git

# ------------------- libxml2 -------------------
if skip_if_installed "libxml2"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "libxml2-${LIBXML2_VERSION}" ]; then
        echo "=== Downloading and building libxml2 ==="
        wget -c https://download.gnome.org/sources/libxml2/2.14/libxml2-${LIBXML2_VERSION}.tar.xz -O - | tar -xJ
    fi

    build_dual_platform "libxml2" "${SRC_DIR}/libxml2-${LIBXML2_VERSION}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DLIBXML2_WITH_THREADS=ON \
        -DLIBXML2_WITH_ZLIB=ON \
        -DLIBXML2_WITH_ICONV=OFF \
        -DLIBXML2_WITH_LZMA=OFF \
        -DLIBXML2_WITH_PROGRAMS=OFF \
        -DLIBXML2_WITH_TESTS=OFF \
        -DLIBXML2_WITH_PYTHON=OFF
fi

# ------------------- libjpeg-turbo -------------------
if skip_if_installed "libjpeg-turbo"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "libjpeg-turbo-${LIBJPEG_TURBO_VERSION}" ]; then
        echo "=== Downloading and building libjpeg-turbo ==="
        wget -c https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${LIBJPEG_TURBO_VERSION}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz -O - | tar -xz
    fi

    build_dual_platform "libjpeg-turbo" "${SRC_DIR}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}" \
        -DENABLE_SHARED=ON \
        -DENABLE_STATIC=ON \
        -DWITH_TURBOJPEG=ON \
        -DWITH_TOOLS=OFF
fi

# ------------------- OpenAL-Soft (universal shared dylib) -------------------
if skip_if_installed "openal"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "openal-soft-${OPENAL_VERSION}" ]; then
        echo "=== Downloading and building OpenAL-Soft (shared) ==="
        wget -c https://github.com/kcat/openal-soft/archive/${OPENAL_VERSION}.tar.gz -O - | tar -xz
    fi
    
    build_dual_platform "openal" "${SRC_DIR}/openal-soft-${OPENAL_VERSION}" \
        -DALSOFT_EXAMPLES=OFF \
        -DALSOFT_TESTS=OFF \
        -DALSOFT_UTILS=OFF \
        -DALSOFT_NO_CONFIG_UTIL=ON \
        -DALSOFT_BACKEND_WAVE=OFF \
        -DALSOFT_REQUIRE_COREAUDIO=ON \
        -DENABLE_STRICT_TRY_COMPILE=ON \
        -DBUILD_SHARED_LIBS=ON
fi

# ------------------- Boost -------------------
if skip_if_installed "boost"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "boost-${BOOST_VERSION}" ]; then
        echo "=== Downloading and building boost ==="
        wget -c https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}-cmake.tar.gz -O - | tar -xz
        
        patch -d ${SRC_DIR}/boost-${BOOST_VERSION}/libs/system/ -p1 -t -N < ${PATCHES_DIR}/system.diff
        #patch -d ${SRC_DIR}/boost-${BOOST_VERSION}/libs/regex/ -p1 -t -N < ${PATCHES_DIR}/regex.diff
    fi

    build_dual_platform "boost" "${SRC_DIR}/boost-${BOOST_VERSION}" \
        -DBOOST_INCLUDE_LIBRARIES="filesystem;program_options;iostreams;geometry;system"

    xcrun ranlib ${PREFIX}/OS64/lib/libboost_{filesystem,program_options,iostreams}.a
    xcrun ranlib ${PREFIX}/SIMULATORARM64/lib/libboost_{filesystem,program_options,iostreams}.a
fi

# ------------------- Build libiconv -------------------
build_iconv() {
    local iconv_version="1.17"
    cd "${SRC_DIR}"
    
    if [ ! -d "libiconv-${iconv_version}" ]; then
        wget -c "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${iconv_version}.tar.gz" -O - | tar -xzf -
    fi
    
    # Build for device
    echo "=== Building libiconv ==="
        build_configure_dual_platform "iconv" "${SRC_DIR}/libiconv-${iconv_version}" \
        --disable-nls
}

# ------------------- liblzma (xz-utils) -------------------
if skip_if_installed "liblzma"; then true; else
    cd "${SRC_DIR}"
    
    if [ ! -d "xz-${XZ_VERSION}" ]; then
        echo "=== Downloading and building liblzma ==="
        wget -c https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/xz-${XZ_VERSION}.tar.gz -O - | tar -xzf -
    fi
    
    # Build for device
    echo "=== Building liblzma ==="
        build_configure_dual_platform "liblzma" "${SRC_DIR}/xz-${XZ_VERSION}" \
        --disable-rpath \
        --disable-nls \
        --disable-doc \
        --disable-scripts \
        --disable-lzmainfo \
        --disable-lzmadec \
        --disable-lzma-links \
        --disable-xz \
        --disable-xzdec \
        --disable-xzdiff \
        --disable-xzgrep \
        --disable-xzless \
        --disable-xzmore SKIP_WERROR_CHECK=yes
fi

# ------------------- FFmpeg -------------------
if skip_if_installed "ffmpeg"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "ffmpeg-${FFMPEG_VERSION}" ]; then
        echo "=== Downloading and building ffmpeg ==="
        wget -c https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 -O - | tar -xjf -
    fi
    
    # Build iconv if not already built
    if skip_if_installed "iconv"; then true; else
        echo "=== Building libiconv ==="
        build_iconv
        mark_as_installed "iconv"
    fi
    
    build_configure_dual_platform "ffmpeg" "${SRC_DIR}/ffmpeg-${FFMPEG_VERSION}" \
        --arch=arm64 \
        --enable-cross-compile \
        --target-os=darwin \
        --cc="clang" \
        --enable-pic \
        --disable-everything \
        --disable-programs --disable-doc \
        --enable-decoder=mp3 --enable-demuxer=mp3 \
        --enable-decoder=bink --enable-decoder=binkaudio_rdft --enable-decoder=binkaudio_dct \
        --enable-demuxer=bink --enable-demuxer=wav --enable-decoder=pcm_* \
        --enable-decoder=vp8 --enable-decoder=vp9 --enable-decoder=opus --enable-decoder=vorbis \
        --enable-demuxer=matroska --enable-demuxer=ogg \
        --disable-asm --disable-optimizations --disable-audiotoolbox --disable-iconv --disable-avfilter --disable-avdevice --disable-lzma --disable-videotoolbox
fi

# ------------------- SDL2 -------------------
if skip_if_installed "sdl2"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "SDL2-${SDL2_VERSION}" ]; then
        echo "=== Downloading and building SDL2 ==="
        wget -c https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz -O - | tar -xz
        patch -d ${SRC_DIR}/SDL2-${SDL2_VERSION}/ -p1 -t -N < ${PATCHES_DIR}/sdl2_ios_scene.patch
    fi

    build_dual_platform "sdl2" "${SRC_DIR}/SDL2-${SDL2_VERSION}" \
        -DSDL_STATIC=OFF \
        -DSDL_SHARED=ON \
        -DSDL_FORCE_GCC_FVISIBILITY=OFF
fi

# ------------------- Bullet Physics -------------------
if skip_if_installed "bullet"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "bullet3-${BULLET_VERSION}" ]; then
        echo "=== Downloading and building Bullet Physics (from master) ==="
        wget -c https://github.com/bulletphysics/bullet3/archive/${BULLET_VERSION}.tar.gz -O - | tar -xz
    fi

    build_dual_platform "bullet" "${SRC_DIR}/bullet3-${BULLET_VERSION}" \
        -DBUILD_BULLET2_DEMOS=OFF \
        -DBUILD_CPU_DEMOS=OFF \
        -DBUILD_UNIT_TESTS=OFF \
        -DBUILD_EXTRAS=OFF \
        -DUSE_DOUBLE_PRECISION=ON \
        -DBULLET2_MULTITHREADING=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DINSTALL_LIBS=ON
fi

# ------------------- MyGUI -------------------
if skip_if_installed "mygui"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "mygui-MyGUI${MYGUI_VERSION}" ]; then
        echo "=== Downloading and building MyGUI ==="
        wget -c https://github.com/MyGUI/mygui/archive/MyGUI${MYGUI_VERSION}.tar.gz -O - | tar -xz
        # Patch UString.h for modern C++ (char32_t/char16_t instead of uint32/uint16)
        #sed -i '' 's/using unicode_char = uint32;/using unicode_char = char32_t;/g' MyGUIEngine/include/MyGUI_UString.h
        #sed -i '' 's/using code_point = uint16;/using code_point = char16_t;/g' MyGUIEngine/include/MyGUI_UString.h
    fi

    build_dual_platform "mygui" "${SRC_DIR}/mygui-MyGUI${MYGUI_VERSION}" \
        -DMYGUI_RENDERSYSTEM=1 \
        -DMYGUI_BUILD_DEMOS=OFF \
        -DMYGUI_BUILD_TOOLS=OFF \
        -DMYGUI_BUILD_PLUGINS=OFF \
        -DMYGUI_DONT_USE_OBSOLETE=ON \
        -DMYGUI_STATIC=ON \
        -DBUILD_SHARED_LIBS=OFF
fi

# ------------------- LZ4 -------------------
if skip_if_installed "lz4"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "lz4-${LZ4_VERSION}" ]; then
        echo "=== Downloading and building LZ4 ==="
        wget -c https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz -O - | tar -xz
    fi

    build_dual_platform "lz4" "${SRC_DIR}/lz4-${LZ4_VERSION}/build/cmake" \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_SHARED_LIBS=OFF
fi

# ------------------- Libogg -------------------
if skip_if_installed "libogg"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "${SRC_DIR}/libogg-1.3.5" ]; then
        echo "=== Downloading and building libogg ==="
        wget -c https://github.com/xiph/ogg/releases/download/v1.3.5/libogg-1.3.5.tar.gz -O - | tar -xz
    fi

    build_dual_platform "libogg" "${SRC_DIR}/libogg-1.3.5"
fi

# ------------------- Vorbis -------------------
if skip_if_installed "vorbis"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "${SRC_DIR}/libvorbis-1.3.7" ]; then
        echo "=== Downloading and building vorbis ==="
        wget -c https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz -O - | tar -xz
    fi

    build_dual_platform "vorbis" "${SRC_DIR}/libvorbis-1.3.7"
fi

# ------------------- uqm -------------------
#if skip_if_installed "uqm"; then true; else
#    cd "${SRC_DIR}"
#    if [ ! -d "${SRC_DIR}/UQM-MegaMod" ]; then
#        echo "=== Downloading and building uqm ==="
#        git clone --branch ReAndroid --single-branch https://github.com/JHGuitarFreak/UQM-MegaMod.git
#    fi

#    build_dual_platform "uqm" "${SRC_DIR}/UQM-MegaMod"
#fi

# ------------------- COLLADA-DOM -------------------
if skip_if_installed "collada"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "collada-dom-${COLLADA_DOM_VERSION}" ]; then
        echo "=== Downloading and building COLLADA-DOM ==="
        wget -c https://github.com/rdiankov/collada-dom/archive/v${COLLADA_DOM_VERSION}.tar.gz -O - | tar -xz
        
        # Create backup with .bak extension
        sed -i '.bak' 's|#include <boost/filesystem/convenience.hpp>|#include <boost/filesystem.hpp>|g' ${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION}/dom/include/dae.h
        sed -i '.bak' 's|#include <boost/filesystem/convenience.hpp>|#include <boost/filesystem.hpp>|g' ${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION}/dom/src/dae/daeUtils.cpp
        sed -i '.bak' 's|std::string dir = archivePath.branch_path().string();|std::string dir = archivePath.parent_path().string();|g' ${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION}/dom/src/dae/daeUtils.cpp
    fi
    
    build_dual_platform "collada" "${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=11 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_FLAGS="-DNO_BOOST -DNO_ZAE ${COMMON_FLAGS}"
fi

# ------------------- OpenSceneGraph -------------------
if skip_if_installed "osg"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "osg-${OSG_VERSION}" ]; then
        echo "=== Downloading and building osg ==="
        wget -c https://github.com/Duron27/osg/archive/${OSG_VERSION}.tar.gz -O - | tar -xz
        patch -d ${SRC_DIR}/osg-${OSG_VERSION}/ -p1 -t -N < ${PATCHES_DIR}/osg_iOS.patch
    fi

    build_dual_platform "osg" "${SRC_DIR}/osg-${OSG_VERSION}" \
        -DOPENGL_PROFILE=GL1 \
        -DCMAKE_VERBOSE_MAKEFILE=ON \
        -DOSG_BUILD_PLATFORM_IPHONE=ON \
        -DOSG_WINDOWING_SYSTEM=IOS \
        -DDYNAMIC_OPENTHREADS=OFF \
        -DDYNAMIC_OPENSCENEGRAPH=OFF \
        -DBUILD_OSG_PLUGIN_OSG=ON \
        -DBUILD_OSG_PLUGIN_DAE=OFF \
        -DBUILD_OSG_PLUGIN_DDS=ON \
        -DBUILD_OSG_PLUGIN_TGA=ON \
        -DBUILD_OSG_PLUGIN_BMP=ON \
        -DBUILD_OSG_PLUGIN_JPEG=ON \
        -DBUILD_OSG_PLUGIN_PNG=ON \
        -DBUILD_OSG_PLUGIN_KTX=ON \
        -DBUILD_OSG_PLUGIN_FREETYPE=ON \
        -DOSG_CPP_EXCEPTIONS_AVAILABLE=TRUE \
        -DOSG_GL1_AVAILABLE=ON \
        -DOSG_GL2_AVAILABLE=OFF \
        -DOSG_GL3_AVAILABLE=OFF \
        -DOSG_GLES1_AVAILABLE=OFF \
        -DOSG_GLES2_AVAILABLE=OFF \
        -DOSG_GL_LIBRARY_STATIC=OFF \
        -DOSG_GL_DISPLAYLISTS_AVAILABLE=OFF \
        -DOSG_GL_MATRICES_AVAILABLE=ON \
        -DOSG_GL_VERTEX_FUNCS_AVAILABLE=ON \
        -DOSG_GL_VERTEX_ARRAY_FUNCS_AVAILABLE=ON \
        -DOSG_GL_FIXED_FUNCTION_AVAILABLE=ON \
        -DBUILD_OSG_APPLICATIONS=OFF \
        -DBUILD_OSG_PLUGINS_BY_DEFAULT=OFF \
        -DBUILD_OSG_DEPRECATED_SERIALIZERS=OFF \
        -DOSG_FIND_3RD_PARTY_DEPS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=11 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON
fi

# ------------------- OpenMW -------------------
if skip_if_installed "openmw"; then true; else
    cd "${SRC_DIR}"
    if [ ! -d "openmw-${OPENMW_VERSION}" ]; then
        echo "=== Downloading and building OpenMW ==="
        wget -c https://github.com/OpenMW/openmw/archive/${OPENMW_VERSION}.tar.gz -O - | tar -xz
        patch -d ${SRC_DIR}/openmw-${OPENMW_VERSION}/ -p1 -t -N < ${PATCHES_DIR}/OpenMW_iOS_2.patch
    fi

    build_dual_platform "openmw" "${SRC_DIR}/openmw-${OPENMW_VERSION}" \
        -DBUILD_BSATOOL=0 \
        -DBUILD_NIFTEST=0 \
        -DBUILD_ESMTOOL=0 \
        -DBUILD_LAUNCHER=0 \
        -DBUILD_MWINIIMPORTER=0 \
        -DBUILD_ESSIMPORTER=0 \
        -DBUILD_OPENCS=0 \
        -DBUILD_NAVMESHTOOL=0 \
        -DBUILD_WIZARD=0 \
        -DBUILD_MYGUI_PLUGIN=0 \
        -DBUILD_BULLETOBJECTTOOL=0 \
        -DOPENMW_USE_SYSTEM_SQLITE3=OFF \
        -DOPENMW_USE_SYSTEM_YAML_CPP=OFF \
        -DOPENMW_USE_SYSTEM_ICU=ON \
        -DLUA_HAS_CUSTOM_ALLOCATOR=ON \
        -DOSG_STATIC=TRUE \
        -DCMAKE_CXX_STANDARD=20 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON
fi

echo "=== All done! ==="
echo "Libraries are in: ${PREFIX}"
echo "To force rebuild a library, run:"
echo "  rm ${MARKERS_DIR}/<name>.installed"
echo "Then re-run the script."
