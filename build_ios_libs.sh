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
SRC_DIR="${WORK_DIR}/src"
TOOLCHAIN_DIR="${WORK_DIR}/ios-cmake"
PREFIX="${WORK_DIR}/ios-libs"
MARKERS_DIR="${PREFIX}/markers"
BUILD_JOBS=$(sysctl -n hw.logicalcpu)

PLATFORM="OS64COMBINED"
DEPLOYMENT_TARGET="17.0"
COMMON_FLAGS="-O3 -fPIC -stdlib=libc++"

LIBJPEG_TURBO_VERSION=3.1.0
LIBPNG_VERSION=1.6.48
FREETYPE2_VERSION=2.13.3
OPENAL_VERSION=1.24.3
BOOST_VERSION=1.88.0 # Starts at line 417
LIBICU_VERSION=78.1
FFMPEG_VERSION=7.1.1
SDL2_VERSION=2.32.4
BULLET_VERSION=3.25
ZLIB_VERSION=1.3.1
LIBXML2_VERSION=2.14.3
MYGUI_VERSION=3.4.3
GL4ES_VERSION=2d7949c0ad55e850f9aa9ed28f5e6ff6490984ee
COLLADA_DOM_VERSION=2.5.0
OSG_VERSION=495b370da37d9e3c739914a190f9821884619a4a
LZ4_VERSION=1.10.0
LUAJIT_VERSION=2.1.ROLLING
OPENMW_VERSION=96565e9afb9bbebf77c1bbc108d5bf4f9bee2e6f
JAVA_VERSION=21

mkdir -p "${SRC_DIR}" "${PREFIX}" "${MARKERS_DIR}"
cd "${WORK_DIR}"

echo "=== Downloading ios-cmake toolchain ==="
if [ ! -d "${TOOLCHAIN_DIR}" ]; then
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

# ------------------- Helper function for CMake builds -------------------
build_cmake_lib() {
    local name="$1"
    local src_dir="$2"
    shift 2
    local extra_args=("$@")

    echo "=== Building ${name} ==="
    mkdir -p "build_${name}" && cd "build_${name}"

    cmake "${src_dir}" \
        -G Xcode \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DPLATFORM="${PLATFORM}" \
        -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="${COMMON_FLAGS}" \
        -DCMAKE_CXX_FLAGS="${COMMON_FLAGS}" \
        -Wno-deprecated \
        "${extra_args[@]}"

    cmake --build . --config Release -j"${BUILD_JOBS}"
    cmake --install . --config Release

    cd ..
    rm -rf "build_${name}"
}

# ------------------- ICU (universal static, device + simulator) -------------------
if skip_if_installed "icu" "ICU"; then true; else
    echo "=== Downloading and building ICU (universal static) ==="
    cd "${SRC_DIR}"

    # Download and extract
    if [ ! -d "icu-release-${LIBICU_VERSION}" ]; then
        wget -c https://github.com/unicode-org/icu/archive/refs/tags/release-${LIBICU_VERSION}.tar.gz -O - | tar -xz
    fi

    ICU_SOURCE_DIR="${SRC_DIR}/icu-release-${LIBICU_VERSION}/icu4c/source"

    # Step 1: Build host (macOS) tools first
    echo "=== Building ICU host tools (macOS) ==="
    mkdir -p icu_host_build && cd icu_host_build
    "${ICU_SOURCE_DIR}/configure" \
        --prefix="$(pwd)/install" \
        --disable-tests \
        --disable-samples \
        --disable-icuio \
        --disable-extras
    make -j"${BUILD_JOBS}"
    make install
    cd ..

    # Step 2: Cross-build for device
    echo "=== Building ICU for iOS device ==="
    mkdir -p build_icu_device && cd build_icu_device
    "${ICU_SOURCE_DIR}/configure" \
        --host=arm-apple-darwin \
        --prefix="${PREFIX}/icu_device" \
        --disable-tests \
        --disable-samples \
        --disable-icuio \
        --disable-extras \
        --disable-tools \
        CC="clang -arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path)" \
        CXX="clang++ -arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path)" \
        CFLAGS="${COMMON_FLAGS} -miphoneos-version-min=${DEPLOYMENT_TARGET}" \
        CXXFLAGS="${COMMON_FLAGS} -miphoneos-version-min=${DEPLOYMENT_TARGET}" \
        LDFLAGS="-isysroot $(xcrun --sdk iphoneos --show-sdk-path)" \
        --with-cross-build="${SRC_DIR}/icu_host_build"

    make -j"${BUILD_JOBS}"
    make install
    cd ..

    # Step 3: Cross-build for simulator
    echo "=== Building ICU for iOS simulator ==="
    mkdir -p build_icu_sim && cd build_icu_sim
    "${ICU_SOURCE_DIR}/configure" \
        --host=arm-apple-darwin \
        --enable-static \
        --disable-shared \
        --prefix="${PREFIX}/icu_sim" \
        --disable-tests \
        --disable-samples \
        --disable-icuio \
        --disable-extras \
        --disable-tools \
        CC="clang -arch arm64 -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path)" \
        CXX="clang++ -arch arm64 -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path)" \
        CFLAGS="${COMMON_FLAGS} -miphonesimulator-version-min=${DEPLOYMENT_TARGET}" \
        CXXFLAGS="${COMMON_FLAGS} -miphonesimulator-version-min=${DEPLOYMENT_TARGET}" \
        LDFLAGS="-isysroot $(xcrun --sdk iphonesimulator --show-sdk-path)" \
        --with-cross-build="${SRC_DIR}/icu_host_build"
        
    make -j"${BUILD_JOBS}"
    make install
    cd ..

    # Step 4: Merge static libs into universal
    echo "=== Merging ICU libs into universal ==="
    cd "${PREFIX}/lib"
    for lib in libicudata.a libicui18n.a libicuuc.a libicuio.a libicule.a libiculx.a; do
        if [ -f "${PREFIX}/icu_device/lib/$lib" ] && [ -f "${PREFIX}/icu_sim/lib/$lib" ]; then
            lipo -create "${PREFIX}/icu_device/lib/$lib" "${PREFIX}/icu_sim/lib/$lib" -output "$lib"
            echo "Created universal $lib"
        fi
    done

    # Copy headers (use device ones)
    cp -r "${PREFIX}/icu_device/include" "${PREFIX}/"

    # Clean up
    rm -rf "${PREFIX}/icu_device" "${PREFIX}/icu_sim" "${SRC_DIR}/icu_host_build"

    mark_as_installed "icu" "ICU"
fi

# ------------------- Bzip2 -------------------
if skip_if_installed "bzip2"; then true; else
    echo "=== Downloading and building bzip2 ==="
    cd "${SRC_DIR}"
    if [ ! -d "bzip2" ]; then
        git clone https://github.com/libarchive/bzip2.git
    fi
    cd bzip2

    build_cmake_lib "bzip2" "${SRC_DIR}/bzip2" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_STATIC_LIBS=ON \
        -DENABLE_APP=OFF

    mark_as_installed "bzip2"
fi

# ------------------- Zlib -------------------
if skip_if_installed "zlib"; then true; else
    echo "=== Downloading and building zlib ==="
    cd "${SRC_DIR}"
    wget -c https://zlib.net/zlib-1.3.1.tar.gz -O - | tar -xz
    cd zlib-1.3.1

    build_cmake_lib "zlib" "${SRC_DIR}/zlib-1.3.1"

    mark_as_installed "zlib"
fi

# ------------------- libpng -------------------
if skip_if_installed "libpng"; then true; else
    echo "=== Downloading and building libpng ==="
    cd "${SRC_DIR}"
    wget -c https://downloads.sourceforge.net/project/libpng/libpng16/1.6.48/libpng-1.6.48.tar.gz -O - | tar -xz
    cd libpng-1.6.48

    mkdir -p build && cd build
    IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)

    ../configure \
        --host=arm-apple-darwin \
        --enable-static \
        --disable-shared \
        --prefix="${PREFIX}" \
        CFLAGS="${COMMON_FLAGS} -isysroot ${IOS_SDK_PATH} -arch arm64 -miphoneos-version-min=${DEPLOYMENT_TARGET}" \
        CPPFLAGS="-isysroot ${IOS_SDK_PATH}" \
        LDFLAGS="-isysroot ${IOS_SDK_PATH}"

    make -j"${BUILD_JOBS}"
    make install
    cd ../..
    rm -rf build

    mark_as_installed "libpng"
fi

# ------------------- FreeType -------------------
if skip_if_installed "freetype"; then true; else
    echo "=== Downloading and building freetype ==="
    cd "${SRC_DIR}"
    wget -c https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz -O - | tar -xJ
    cd freetype-2.13.3

    build_cmake_lib "freetype" "${SRC_DIR}/freetype-2.13.3" \
        -DCMAKE_DISABLE_FIND_PACKAGE_BZip2=OFF \
        -DCMAKE_DISABLE_FIND_PACKAGE_PNG=OFF \
        -DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=OFF

    mark_as_installed "freetype"
fi

# ------------------- libxml2 -------------------
if skip_if_installed "libxml2"; then true; else
    echo "=== Downloading and building libxml2 ==="
    cd "${SRC_DIR}"
    wget -c https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.3.tar.xz -O - | tar -xJ
    cd libxml2-2.14.3

    build_cmake_lib "libxml2" "${SRC_DIR}/libxml2-2.14.3" \
        -DBUILD_SHARED_LIBS=OFF \
        -DLIBXML2_WITH_THREADS=ON \
        -DLIBXML2_WITH_ZLIB=ON \
        -DLIBXML2_WITH_ICONV=OFF \
        -DLIBXML2_WITH_LZMA=OFF \
        -DLIBXML2_WITH_PROGRAMS=OFF \
        -DLIBXML2_WITH_TESTS=OFF \
        -DLIBXML2_WITH_PYTHON=OFF

    mark_as_installed "libxml2"
fi

# ------------------- libjpeg-turbo -------------------
if skip_if_installed "libjpeg-turbo"; then true; else
    echo "=== Downloading and building libjpeg-turbo ==="
    cd "${SRC_DIR}"
    if [ ! -d "libjpeg-turbo-3.1.0" ]; then
        wget -c https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.0/libjpeg-turbo-3.1.0.tar.gz -O - | tar -xz
    fi

    # Device
    mkdir -p build_jpeg_device && cd build_jpeg_device
    cmake "${SRC_DIR}/libjpeg-turbo-3.1.0" \
        -G Xcode -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" -DPLATFORM=OS64 \
        -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release -DENABLE_SHARED=ON -DENABLE_STATIC=ON \
        -DWITH_TURBOJPEG=ON -DWITH_TOOLS=OFF \
        -DCMAKE_C_FLAGS="${COMMON_FLAGS}" -DCMAKE_CXX_FLAGS="${COMMON_FLAGS}" -Wno-deprecated
    cmake --build . --config Release -j"${BUILD_JOBS}"
    cmake --install . --config Release
    cd ..
    rm -rf build_jpeg_device

    # Simulator
    mkdir -p build_jpeg_sim && cd build_jpeg_sim
    cmake "${SRC_DIR}/libjpeg-turbo-3.1.0" \
        -G Xcode -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" -DPLATFORM=SIMULATOR64 \
        -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" -DCMAKE_INSTALL_PREFIX="${PREFIX}_sim" \
        -DCMAKE_BUILD_TYPE=Release -DENABLE_SHARED=ON -DENABLE_STATIC=ON \
        -DWITH_TURBOJPEG=ON -DWITH_TOOLS=OFF \
        -DCMAKE_C_FLAGS="${COMMON_FLAGS}" -DCMAKE_CXX_FLAGS="${COMMON_FLAGS}" -Wno-deprecated
    cmake --build . --config Release -j"${BUILD_JOBS}"
    cmake --install . --config Release
    cd ..
    rm -rf build_jpeg_sim

    # Merge
    cd "${PREFIX}/lib"
    for lib in libjpeg.a libturbojpeg.a; do
        if [ -f "${PREFIX}_sim/lib/$lib" ]; then
            lipo -create "$lib" "${PREFIX}_sim/lib/$lib" -output "$lib.universal"
            mv "$lib.universal" "$lib"
        fi
    done
    rm -f *.dylib
    cd "${WORK_DIR}"
    rm -rf "${PREFIX}_sim"

    mark_as_installed "libjpeg-turbo"
fi

# ------------------- OpenAL-Soft (universal shared dylib) -------------------
if skip_if_installed "openal" "OpenAL-Soft"; then true; else
    echo "=== Downloading and building OpenAL-Soft (shared) ==="
    cd "${SRC_DIR}"
    if [ ! -d "openal-soft-1.24.3" ]; then
        wget -c https://github.com/kcat/openal-soft/archive/1.24.3.tar.gz -O - | tar -xz
    fi
    cd openal-soft-1.24.3

    # Device build (shared)
    echo "=== Building OpenAL-Soft for iOS device (shared) ==="
    mkdir -p build_openal_device && cd build_openal_device
    cmake "${SRC_DIR}/openal-soft-1.24.3" \
        -G Xcode \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DPLATFORM=OS64 \
        -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DALSOFT_EXAMPLES=OFF \
        -DALSOFT_TESTS=OFF \
        -DALSOFT_UTILS=OFF \
        -DALSOFT_NO_CONFIG_UTIL=ON \
        -DALSOFT_BACKEND_WAVE=OFF \
        -DALSOFT_REQUIRE_COREAUDIO=ON \
        -DENABLE_STRICT_TRY_COMPILE=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_C_FLAGS="${COMMON_FLAGS} -fPIC" \
        -DCMAKE_CXX_FLAGS="${COMMON_FLAGS} -fPIC" \
        -Wno-deprecated
    cmake --build . --config Release -j"${BUILD_JOBS}"
    cmake --install . --config Release
    cd ..
    rm -rf build_openal_device

    # Simulator build (shared)
    echo "=== Building OpenAL-Soft for iOS simulator (shared) ==="
    mkdir -p build_openal_sim && cd build_openal_sim
    cmake "${SRC_DIR}/openal-soft-1.24.3" \
        -G Xcode \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DPLATFORM=SIMULATOR64 \
        -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}_sim" \
        -DCMAKE_BUILD_TYPE=Release \
        -DALSOFT_EXAMPLES=OFF \
        -DALSOFT_TESTS=OFF \
        -DALSOFT_UTILS=OFF \
        -DALSOFT_NO_CONFIG_UTIL=ON \
        -DALSOFT_BACKEND_WAVE=OFF \
        -DALSOFT_REQUIRE_COREAUDIO=ON \
        -DENABLE_STRICT_TRY_COMPILE=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_C_FLAGS="${COMMON_FLAGS} -fPIC" \
        -DCMAKE_CXX_FLAGS="${COMMON_FLAGS} -fPIC" \
        -Wno-deprecated
    cmake --build . --config Release -j"${BUILD_JOBS}"
    cmake --install . --config Release
    cd ..
    rm -rf build_openal_sim

    # Merge into universal fat dylib
    echo "=== Creating universal libopenal.dylib ==="
    cd "${PREFIX}/lib"
    if [ -f "${PREFIX}_sim/lib/libopenal.1.dylib" ]; then
        lipo -create "libopenal.1.dylib" "${PREFIX}_sim/lib/libopenal.1.dylib" -output "libopenal.1.dylib.universal"
        mv "libopenal.1.dylib.universal" "libopenal.1.dylib"
        echo "Created universal libopenal.1.dylib"
    fi

    # Also create the versionless symlink if needed
    ln -sf libopenal.1.dylib libopenal.dylib

    cd "${WORK_DIR}"
    rm -rf "${PREFIX}_sim"

    mark_as_installed "openal" "OpenAL-Soft"
fi

# ------------------- Boost -------------------
if skip_if_installed "boost"; then true; else
    echo "=== Downloading and building boost ==="
    cd "${SRC_DIR}"
    if [ ! -d "boost-${BOOST_VERSION}" ]; then
        wget -c https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}-cmake.tar.gz -O - | tar -xz
        
        patch -d ${SRC_DIR}/boost-${BOOST_VERSION}/libs/system/ -p1 -t -N < ../../patches/system.diff
        #patch -d ${SRC_DIR}/boost-${BOOST_VERSION}/libs/regex/ -p1 -t -N < ../../patches/regex.diff
    fi

    mkdir -p build_boost && cd build_boost
    cmake "${SRC_DIR}/boost-${BOOST_VERSION}" \
        -G Xcode -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" -DPLATFORM="${PLATFORM}" \
        -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_FLAGS="${COMMON_FLAGS}" -Wno-deprecated \
        -DBOOST_INCLUDE_LIBRARIES="filesystem;program_options;iostreams;geometry;system"
    cmake --build . --config Release -j"${BUILD_JOBS}"
    cmake --install . --config Release

    xcrun ranlib ${PREFIX}/lib/libboost_{filesystem,program_options,iostreams}.a
    cd ..
    rm -rf build_boost

    mark_as_installed "boost"
fi

# ------------------- FFmpeg (as XCFramework) -------------------
if skip_if_installed "ffmpeg" "FFmpeg"; then true; else
    echo "=== Downloading and building FFmpeg (XCFramework) ==="
    cd "${SRC_DIR}"
    if [ ! -d "ffmpeg-7.1.1" ]; then
        wget -c https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.bz2 -O - | tar -xjf -
    fi
    cd ffmpeg-7.1.1

    # Device build
    echo "=== Building FFmpeg for iOS device ==="
    mkdir -p build_ffmpeg_device && cd build_ffmpeg_device
    ../configure \
        --arch=arm64 \
        --enable-cross-compile \
        --target-os=darwin \
        --cc="clang" \
        --sysroot="$(xcrun --sdk iphoneos --show-sdk-path)" \
        --extra-cflags="-arch arm64 -miphoneos-version-min=${DEPLOYMENT_TARGET} ${COMMON_FLAGS}" \
        --extra-ldflags="-arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path)" \
        --prefix="${PREFIX}/ffmpeg_device" \
        --enable-static --disable-shared \
        --enable-pic \
        --disable-everything \
        --disable-programs --disable-doc \
        --enable-decoder=mp3 --enable-demuxer=mp3 \
        --enable-decoder=bink --enable-decoder=binkaudio_rdft --enable-decoder=binkaudio_dct \
        --enable-demuxer=bink --enable-demuxer=wav --enable-decoder=pcm_* \
        --enable-decoder=vp8 --enable-decoder=vp9 --enable-decoder=opus --enable-decoder=vorbis \
        --enable-demuxer=matroska --enable-demuxer=ogg \
        --disable-asm
    make -j"${BUILD_JOBS}"
    make install
    cd ..
    rm -rf build_ffmpeg_device

    # Simulator build
    echo "=== Building FFmpeg for iOS simulator ==="
    mkdir -p build_ffmpeg_sim && cd build_ffmpeg_sim
    ../configure \
        --arch=arm64 \
        --enable-cross-compile \
        --target-os=darwin \
        --cc="clang" \
        --sysroot="$(xcrun --sdk iphonesimulator --show-sdk-path)" \
        --extra-cflags="-arch arm64 -miphonesimulator-version-min=${DEPLOYMENT_TARGET} ${COMMON_FLAGS}" \
        --extra-ldflags="-arch arm64 -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path)" \
        --prefix="${PREFIX}/ffmpeg_sim" \
        --enable-static --disable-shared \
        --enable-pic \
        --disable-everything \
        --disable-programs --disable-doc \
        --enable-decoder=mp3 --enable-demuxer=mp3 \
        --enable-decoder=bink --enable-decoder=binkaudio_rdft --enable-decoder=binkaudio_dct \
        --enable-demuxer=bink --enable-demuxer=wav --enable-decoder=pcm_* \
        --enable-decoder=vp8 --enable-decoder=vp9 --enable-decoder=opus --enable-decoder=vorbis \
        --enable-demuxer=matroska --enable-demuxer=ogg \
        --disable-asm
    make -j"${BUILD_JOBS}"
    make install
    cd ..
    rm -rf build_ffmpeg_sim

    # Create separate XCFrameworks for each FFmpeg library
    echo "=== Creating separate XCFrameworks for FFmpeg libraries ==="
    mkdir -p "${PREFIX}/xcframeworks"

    for lib_name in avcodec avformat avutil swresample swscale; do
        xcframework_path="${PREFIX}/xcframeworks/lib${lib_name}.xcframework"
        echo "Creating ${xcframework_path}..."

        rm -rf "${xcframework_path}"  # Clean any old one

        xcodebuild -create-xcframework \
            -library "${PREFIX}/ffmpeg_device/lib/lib${lib_name}.a" \
            -headers "${PREFIX}/ffmpeg_device/include" \
            -library "${PREFIX}/ffmpeg_sim/lib/lib${lib_name}.a" \
            -headers "${PREFIX}/ffmpeg_sim/include" \
            -output "${xcframework_path}"
    done

    # Optional: clean up intermediate dirs
    rm -rf "${PREFIX}/ffmpeg_device" "${PREFIX}/ffmpeg_sim"

    mark_as_installed "ffmpeg" "FFmpeg"
fi

# ------------------- SDL2 (static, universal) -------------------
if skip_if_installed "sdl2" "SDL2"; then true; else
    echo "=== Downloading and building SDL2 ==="
    cd "${SRC_DIR}"
    if [ ! -d "SDL2-2.32.4" ]; then
        wget -c https://github.com/libsdl-org/SDL/releases/download/release-2.32.4/SDL2-2.32.4.tar.gz -O - | tar -xz
    fi
    cd SDL2-2.32.4

    build_cmake_lib "sdl2" "${SRC_DIR}/SDL2-2.32.4" \
        -DSDL_STATIC=ON \
        -DSDL_SHARED=OFF \
        -DSDL_TEST=OFF \
        -DSDL_RENDER=ON \
        -DSDL_VIDEO=ON \
        -DSDL_AUDIO=ON \
        -DSDL_OPENGL=OFF \
        -DSDL_OPENGLES=ON \
        -DSDL_VULKAN=OFF \
        -DSDL_METAL=ON \
        -DSDL_X11=OFF \
        -DSDL_WAYLAND=OFF \
        -DSDL_KMSDRM=OFF \
        -DSDL_IBUS=OFF \
        -DSDL_DIRECTX=OFF \
        -DSDL_DISKAUDIO=OFF \
        -DSDL_DUMMYAUDIO=OFF \
        -DSDL_DUMMYVIDEO=OFF \
        -DSDL_FORCE_GCC_ATOMICS=OFF \
        -DSDL_FORCE_GCC_FVISIBILITY=OFF

    mark_as_installed "sdl2" "SDL2"
fi

# ------------------- Bullet Physics -------------------
if skip_if_installed "bullet" "Bullet Physics"; then true; else
    echo "=== Downloading and building Bullet Physics (from master) ==="
    cd "${SRC_DIR}"
    if [ ! -d "bullet3-master" ]; then
        git clone https://github.com/bulletphysics/bullet3.git bullet3-master
    fi
    cd bullet3-master

    build_cmake_lib "bullet" "${SRC_DIR}/bullet3-master" \
        -DBUILD_BULLET2_DEMOS=OFF \
        -DBUILD_CPU_DEMOS=OFF \
        -DBUILD_UNIT_TESTS=OFF \
        -DBUILD_EXTRAS=OFF \
        -DUSE_DOUBLE_PRECISION=ON \
        -DBULLET2_MULTITHREADING=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DINSTALL_LIBS=ON

    mark_as_installed "bullet" "Bullet Physics"
fi

# # ------------------- GL4ES -------------------
# if skip_if_installed "gl4es" "GL4ES"; then true; else
#     echo "=== Downloading and building NG-GL4ES (OpenMW branch) ==="
#     cd "${SRC_DIR}"
#
#     if [ ! -d "gl4es" ]; then
#         git clone https://github.com/BZLZHH/NG-GL4ES.git gl4es
#     fi
#
#     cd gl4es
#     git fetch
#     git submodule init
#     git submodule update --recursive
#
#     sed -i '' '4056s/.*/#ifdef __APPLE__\ntypedef void *GLhandleARB;\n#else\ntypedef unsigned int GLhandleARB;\n#endif/' include/GL/glext.h
#
#     echo "=== Building NG-GL4ES (OS64COMBINED) ==="
#     mkdir -p build_gl4es && cd build_gl4es
#
#     cmake "${SRC_DIR}/gl4es" \
#         -G Xcode \
#         -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
#         -DPLATFORM=OS64COMBINED \
#         -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
#         -DCMAKE_INSTALL_PREFIX="${PREFIX}/gl4es" \
#         -DCMAKE_BUILD_TYPE=Release \
#         -DNOEGL=ON \
#         -DNOX11=ON \
#         -DDEFAULT_ES=2 \
#         -DSTATICLIB=OFF \
#         -DCMAKE_C_FLAGS="${COMMON_FLAGS} -fPIC" \
#         -DCMAKE_CXX_FLAGS="${COMMON_FLAGS} -fPIC" \
#         -Wno-deprecated
#
#     cmake --build . --config Release --target ng_gl4es -j"${BUILD_JOBS}"
#     cmake --install . --config Release
#     cd ..
#
#     echo "=== Creating GL4ES.xcframework ==="
#     mkdir -p "${PREFIX}/xcframeworks"
#     rm -rf "${PREFIX}/xcframeworks/GL4ES.xcframework"
#
#     xcodebuild -create-xcframework \
#         -library "${PREFIX}/gl4es/lib/libGL.dylib" \
#         -headers "${PREFIX}/gl4es/include" \
#         -output "${PREFIX}/xcframeworks/GL4ES.xcframework"
#
#     rm -rf "${PREFIX}/gl4es_device" "${PREFIX}/gl4es_sim"
#
#     mark_as_installed "gl4es" "GL4ES"
# fi

# ------------------- MyGUI -------------------
if skip_if_installed "mygui" "MyGUI"; then true; else
    echo "=== Downloading and building MyGUI ==="
    cd "${SRC_DIR}"
    if [ ! -d "mygui-MyGUI3.4.3" ]; then
        wget -c https://github.com/MyGUI/mygui/archive/MyGUI3.4.3.tar.gz -O - | tar -xz
    fi
    cd mygui-MyGUI3.4.3

    # Patch UString.h for modern C++ (char32_t/char16_t instead of uint32/uint16)
    sed -i '' 's/using unicode_char = uint32;/using unicode_char = char32_t;/g' MyGUIEngine/include/MyGUI_UString.h
    sed -i '' 's/using code_point = uint16;/using code_point = char16_t;/g' MyGUIEngine/include/MyGUI_UString.h

    build_cmake_lib "mygui" "${SRC_DIR}/mygui-MyGUI3.4.3" \
        -DMYGUI_RENDERSYSTEM=1 \
        -DMYGUI_BUILD_DEMOS=OFF \
        -DMYGUI_BUILD_TOOLS=OFF \
        -DMYGUI_BUILD_PLUGINS=OFF \
        -DMYGUI_DONT_USE_OBSOLETE=ON \
        -DMYGUI_STATIC=ON \
        -DBUILD_SHARED_LIBS=OFF

    mark_as_installed "mygui" "MyGUI"
fi

# ------------------- LZ4 -------------------
if skip_if_installed "lz4" "LZ4"; then true; else
    echo "=== Downloading and building LZ4 ==="
    cd "${SRC_DIR}"
    if [ ! -d "lz4-1.10.0" ]; then
        wget -c https://github.com/lz4/lz4/archive/v1.10.0.tar.gz -O - | tar -xz
    fi
    cd lz4-1.10.0

    build_cmake_lib "lz4" "${SRC_DIR}/lz4-1.10.0/build/cmake" \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_SHARED_LIBS=OFF

    mark_as_installed "lz4" "LZ4"
fi

# ------------------- COLLADA-DOM -------------------
if skip_if_installed "collada" "COLLADA-DOM"; then true; else
    echo "=== Downloading and building COLLADA-DOM ==="
    cd "${SRC_DIR}"
    if [ ! -d "collada-dom-${COLLADA_DOM_VERSION}" ]; then
        wget -c https://github.com/rdiankov/collada-dom/archive/v${COLLADA_DOM_VERSION}.tar.gz -O - | tar -xz
        
        # Create backup with .bak extension
        sed -i '.bak' 's|#include <boost/filesystem/convenience.hpp>|#include <boost/filesystem.hpp>|g' ${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION}/dom/include/dae.h
        sed -i '.bak' 's|#include <boost/filesystem/convenience.hpp>|#include <boost/filesystem.hpp>|g' ${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION}/dom/src/dae/daeUtils.cpp
        sed -i '.bak' 's|std::string dir = archivePath.branch_path().string();|std::string dir = archivePath.parent_path().string();|g' ${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION}/dom/src/dae/daeUtils.cpp
    fi

    mkdir -p build_collada_device && cd build_collada_device
    cmake "${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION}" \
        -G Xcode \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DPLATFORM=OS64 \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_FLAGS="-std=gnu++11 -DNO_BOOST -DNO_ZAE" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5

    cmake --build . --config Release -j"${BUILD_JOBS}"
    cmake --install . --config Release
    
    #cd ..
    
    #mkdir -p build_collada_sim && cd build_collada_sim

    #cmake "${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION}" \
    #    -G Xcode \
    #    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
    #    -DPLATFORM=SIMULATOR64 \
    #    -DCMAKE_INSTALL_PREFIX="${PREFIX}_sim" \
    #    -DCMAKE_BUILD_TYPE=Release \
    #    -DCMAKE_CXX_FLAGS="-std=gnu++11 -DNO_BOOST -DNO_ZAE" \
    #    -DCMAKE_POLICY_VERSION_MINIMUM=3.5

    #cmake --build . --config Release -j"${BUILD_JOBS}"
    #cmake --install . --config Release
        
    mark_as_installed "collada" "COLLADA-DOM"
fi

# ------------------- OpenSceneGraph -------------------
if skip_if_installed "osg" "OpenSceneGraph"; then true; else
    echo "=== Downloading and building OpenSceneGraph ==="
    cd "${SRC_DIR}"
    if [ ! -d "osg-${OSG_VERSION}" ]; then
        wget -c https://github.com/Duron27/osg/archive/${OSG_VERSION}.tar.gz -O - | tar -xz
    fi
    cd osg-${OSG_VERSION}

    build_cmake_lib "osg" "${SRC_DIR}/osg-${OSG_VERSION}" \
        -DOPENGL_PROFILE=GL2 \
        -DDYNAMIC_OPENTHREADS=OFF \
        -DDYNAMIC_OPENSCENEGRAPH=OFF \
        -DBUILD_OSG_PLUGIN_OSG=ON \
        -DBUILD_OSG_PLUGIN_DAE=ON \
        -DBUILD_OSG_PLUGIN_DDS=ON \
        -DBUILD_OSG_PLUGIN_TGA=ON \
        -DBUILD_OSG_PLUGIN_BMP=ON \
        -DBUILD_OSG_PLUGIN_JPEG=ON \
        -DBUILD_OSG_PLUGIN_PNG=ON \
        -DBUILD_OSG_PLUGIN_KTX=ON \
        -DBUILD_OSG_PLUGIN_FREETYPE=ON \
        -DOSG_CPP_EXCEPTIONS_AVAILABLE=TRUE \
        -DJPEG_INCLUDE_DIR="${PREFIX}/include" \
        -DPNG_INCLUDE_DIR="${PREFIX}/include" \
        -DCOLLADA_INCLUDE_DIR="${PREFIX}/include/collada-dom2.5" \
        -DOSG_GL1_AVAILABLE=ON \
        -DOSG_GL2_AVAILABLE=ON \
        -DOSG_GL3_AVAILABLE=OFF \
        -DOSG_GLES1_AVAILABLE=OFF \
        -DOSG_GLES2_AVAILABLE=OFF \
        -DOSG_GL_LIBRARY_STATIC=OFF \
        -DOSG_GL_DISPLAYLISTS_AVAILABLE=ON \
        -DOSG_GL_MATRICES_AVAILABLE=ON \
        -DOSG_GL_VERTEX_FUNCS_AVAILABLE=ON \
        -DOSG_GL_VERTEX_ARRAY_FUNCS_AVAILABLE=ON \
        -DOSG_GL_FIXED_FUNCTION_AVAILABLE=ON \
        -DBUILD_OSG_APPLICATIONS=OFF \
        -DBUILD_OSG_PLUGINS_BY_DEFAULT=OFF \
        -DBUILD_OSG_DEPRECATED_SERIALIZERS=OFF \
        -DOSG_FIND_3RD_PARTY_DEPS=OFF \
        -DOPENGL_INCLUDE_DIR="${PREFIX}/include" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_CXX_FLAGS="-std=gnu++11 -I${PREFIX}/include/freetype2"

    mark_as_installed "osg" "OpenSceneGraph"
fi

echo "=== All done! ==="
echo "Libraries are in: ${PREFIX}"
echo "To force rebuild a library, run:"
echo "  rm ${MARKERS_DIR}/<name>.installed"
echo "Then re-run the script."
