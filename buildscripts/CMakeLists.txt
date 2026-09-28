cmake_minimum_required(VERSION 3.19)
if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()
set(CMAKE_WARN_DEPRECATED OFF CACHE BOOL "" FORCE)
project(OpenMW_iOS_Deps NONE)

include(ExternalProject)

# ------------------- Configuration -------------------
set(IOS_PLATFORM "OS64" CACHE STRING "iOS Platform (OS64, SIMULATORARM64)")
set(DEPLOYMENT_TARGET "16.4")
set(COMMON_FLAGS "-O3 -fPIC -stdlib=libc++ -w")
cmake_host_system_information(RESULT BUILD_JOBS QUERY NUMBER_OF_LOGICAL_CORES)

if(IOS_PLATFORM STREQUAL "OS64")
    set(SDK_NAME "iphoneos")
    set(LUAJIT_PLATFORM "ios")
    set(ARCH "arm64")
    set(MIN_VERSION_FLAG "-miphoneos-version-min=${DEPLOYMENT_TARGET}")
else()
    set(SDK_NAME "iphonesimulator")
    set(LUAJIT_PLATFORM "isimulator")
    set(ARCH "arm64")
    set(MIN_VERSION_FLAG "-mios-simulator-version-min=${DEPLOYMENT_TARGET}")
endif()

execute_process(COMMAND xcrun --sdk ${SDK_NAME} --show-sdk-path OUTPUT_VARIABLE IOS_SDK_PATH OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND xcrun --sdk ${SDK_NAME} -f clang OUTPUT_VARIABLE IOS_CLANG OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND xcrun --sdk ${SDK_NAME} -f clang++ OUTPUT_VARIABLE IOS_CLANGXX OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND xcrun --sdk ${SDK_NAME} -f ar OUTPUT_VARIABLE IOS_AR OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND xcrun --sdk ${SDK_NAME} -f nm OUTPUT_VARIABLE IOS_NM OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND xcrun --sdk ${SDK_NAME} -f ranlib OUTPUT_VARIABLE IOS_RANLIB OUTPUT_STRIP_TRAILING_WHITESPACE)

# ------------------- Paths -------------------
set(WORK_DIR "${CMAKE_BINARY_DIR}/ios_build")
set(SRC_DIR "${WORK_DIR}/src")
set(PREFIX "${WORK_DIR}/ios-libs")
set(INSTALL_PREFIX "${PREFIX}/${IOS_PLATFORM}")
set(TOOLCHAIN_DIR "${WORK_DIR}/ios-cmake")
set(PATCHES_DIR "${CMAKE_SOURCE_DIR}/buildscripts/patches")

file(MAKE_DIRECTORY "${SRC_DIR}" "${PREFIX}")

set(CONFIGURE_CFLAGS "${COMMON_FLAGS} -isysroot ${IOS_SDK_PATH} -arch ${ARCH} ${MIN_VERSION_FLAG}")
set(CONFIGURE_CPPFLAGS "-isysroot ${IOS_SDK_PATH} -I${INSTALL_PREFIX}/include")
set(CONFIGURE_LDFLAGS "-isysroot ${IOS_SDK_PATH} -arch ${ARCH} -L${INSTALL_PREFIX}/lib")

set(CONFIGURE_ENV
    "CC=${IOS_CLANG}"
    "CXX=${IOS_CLANGXX}"
    "AR=${IOS_AR}"
    "NM=${IOS_NM}"
    "RANLIB=${IOS_RANLIB}"
    "CFLAGS=${CONFIGURE_CFLAGS}"
    "CPPFLAGS=${CONFIGURE_CPPFLAGS}"
    "LDFLAGS=${CONFIGURE_LDFLAGS}"
    "PKG_CONFIG_LIBDIR=${INSTALL_PREFIX}/lib/pkgconfig:${INSTALL_PREFIX}/share/pkgconfig"
    "PKG_CONFIG_PATH=${INSTALL_PREFIX}/lib/pkgconfig:${INSTALL_PREFIX}/share/pkgconfig"
)

set(ENV_CMAKE ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} ${CMAKE_COMMAND})

set(GLES_INCLUDE "${IOS_SDK_PATH}/System/Library/Frameworks")
set(GLES_LIBRARY "${IOS_SDK_PATH}/System/Library/Frameworks/OpenGLES.framework")

# ------------------- Toolchain Setup -------------------
ExternalProject_Add(ios_toolchain
    GIT_REPOSITORY https://github.com/leetal/ios-cmake.git
    SOURCE_DIR "${TOOLCHAIN_DIR}"
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
)

set(TOOLCHAIN_FILE "${TOOLCHAIN_DIR}/ios.toolchain.cmake")

# ------------------- Versions -------------------
set(LIBJPEG_TURBO_VERSION 3.1.0)
set(LIBPNG_VERSION 1.6.48)
set(BROTLI_VERSION 1.2.0)
set(FREETYPE2_VERSION 2.14.1)
set(OPENAL_VERSION 1.24.3)
set(BOOST_VERSION 1.88.0)
set(LIBICU_VERSION 78.1)
set(FFMPEG_VERSION 7.1.1)
set(SDL2_VERSION 2.32.4)
set(BULLET_VERSION 3.25)
set(ZLIB_VERSION 1.3.2)
set(LIBXML2_VERSION 2.14.3)
set(MYGUI_VERSION 3.4.3)
set(COLLADA_DOM_VERSION 2.5.0)
set(OSG_VERSION 638f0a1e73687633fd99bf110d04226e78ff69c6)
set(LZ4_VERSION 1.10.0)
set(LUA_VERSION 5.1.5)
set(LUAJIT_VERSION 2.1.ROLLING)
set(OPENMW_VERSION 09243a3aa57f903ae69e541fc4d81617c8c4b15a)
set(RECAST_VERSION 455a019e7aef99354ac3020f04c1fe3541aa4d19)
set(XZ_VERSION 5.8.2)

# ------------------- Common CMake Args -------------------
set(CMAKE_PLATFORM_ARGS
    -G "Unix Makefiles"
    -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}
    -DPLATFORM=${IOS_PLATFORM}
    -DDEPLOYMENT_TARGET=${DEPLOYMENT_TARGET}
    -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_FLAGS=${COMMON_FLAGS}
    -DCMAKE_CXX_FLAGS=${COMMON_FLAGS}
    -DCMAKE_FIND_ROOT_PATH=${INSTALL_PREFIX}
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
    -DOPENGL_INCLUDE_DIR=${GLES_INCLUDE}
    -DOPENGL_gl_LIBRARY=${GLES_LIBRARY}
    -DOPENGL_glx_LIBRARY=${GLES_LIBRARY}
    -Wno-author
    -Wno-deprecated
)

# ------------------- ICU (Host and Cross) -------------------
ExternalProject_Add(icu_host
    URL https://github.com/unicode-org/icu/archive/refs/tags/release-${LIBICU_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/icu"
    BINARY_DIR "${WORK_DIR}/icu_host_build"
    CONFIGURE_COMMAND <SOURCE_DIR>/icu4c/source/configure --prefix=<BINARY_DIR>/install --disable-tests --disable-samples --disable-icuio --disable-extras
    BUILD_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make -j${BUILD_JOBS}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make install
)

ExternalProject_Add(icu
    DEPENDS icu_host ios_toolchain
    URL https://github.com/unicode-org/icu/archive/refs/tags/release-${LIBICU_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/icu"
    BINARY_DIR "${WORK_DIR}/icu_cross_build"
    CONFIGURE_COMMAND <SOURCE_DIR>/icu4c/source/configure
        --host=arm-apple-darwin
        --prefix=${INSTALL_PREFIX}
        --enable-static
        --disable-shared
        --disable-tests
        --disable-samples
        --disable-icuio
        --disable-extras
        --disable-tools
        --with-cross-build=${WORK_DIR}/icu_host_build
        ${CONFIGURE_ENV}
    BUILD_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make -j${BUILD_JOBS}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make install
)

# ------------------- Bzip2 -------------------
ExternalProject_Add(bzip2
    DEPENDS ios_toolchain
    GIT_REPOSITORY https://github.com/libarchive/bzip2.git
    SOURCE_DIR "${SRC_DIR}/bzip2"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS} -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DENABLE_APP=OFF
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- Luajit -------------------
ExternalProject_Add(luajit
    GIT_REPOSITORY https://github.com/mpvkit/libluajit-build.git
    GIT_TAG main
    SOURCE_DIR "${SRC_DIR}/luajit"
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make build platform=${LUAJIT_PLATFORM} XCFLAGS+=-DLUAJIT_ENABLE_GC64
    INSTALL_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} ${CMAKE_COMMAND} -E copy_directory dist/release/libluajit/include/luajit-2.1/ ${INSTALL_PREFIX}/include/
            COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} ${CMAKE_COMMAND} -E copy dist/release/libluajit/lib/ios/thin/arm64/lib/libluajit.a ${INSTALL_PREFIX}/lib/
)

# ------------------- Zlib -------------------
ExternalProject_Add(zlib
    DEPENDS ios_toolchain
    URL https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/zlib"
    PATCH_COMMAND sed -i "" "s/add_executable(example/#/g" CMakeLists.txt &&
                  sed -i "" "s/add_executable(minigzip/#/g" CMakeLists.txt
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release -- -j${BUILD_JOBS}
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- libpng -------------------
ExternalProject_Add(libpng
    DEPENDS ios_toolchain zlib
    URL https://downloads.sourceforge.net/project/libpng/libpng16/${LIBPNG_VERSION}/libpng-${LIBPNG_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/libpng"
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} <SOURCE_DIR>/configure --host=arm-apple-darwin --prefix=${INSTALL_PREFIX} --enable-static --disable-shared
    BUILD_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make -j${BUILD_JOBS}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make install
)

# ------------------- FreeType -------------------
ExternalProject_Add(freetype
    DEPENDS ios_toolchain zlib libpng
    URL https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE2_VERSION}.tar.xz
    SOURCE_DIR "${SRC_DIR}/freetype"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- libxml2 -------------------
ExternalProject_Add(libxml2
    DEPENDS ios_toolchain zlib
    URL https://download.gnome.org/sources/libxml2/2.14/libxml2-${LIBXML2_VERSION}.tar.xz
    SOURCE_DIR "${SRC_DIR}/libxml2"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DBUILD_SHARED_LIBS=OFF
        -DLIBXML2_WITH_THREADS=ON
        -DLIBXML2_WITH_ZLIB=ON
        -DLIBXML2_WITH_ICONV=OFF
        -DLIBXML2_WITH_LZMA=OFF
        -DLIBXML2_WITH_PROGRAMS=OFF
        -DLIBXML2_WITH_TESTS=OFF
        -DLIBXML2_WITH_PYTHON=OFF
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- libjpeg-turbo -------------------
ExternalProject_Add(libjpeg-turbo
    DEPENDS ios_toolchain
    URL https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${LIBJPEG_TURBO_VERSION}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/libjpeg-turbo"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DENABLE_SHARED=OFF
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- OpenAL-Soft -------------------
ExternalProject_Add(openal
    DEPENDS ios_toolchain
    URL https://github.com/kcat/openal-soft/archive/${OPENAL_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/openal"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DALSOFT_EXAMPLES=OFF
        -DALSOFT_TESTS=OFF
        -DALSOFT_UTILS=OFF
        -DALSOFT_NO_CONFIG_UTIL=ON
        -DALSOFT_BACKEND_WAVE=OFF
        -DALSOFT_REQUIRE_COREAUDIO=ON
        -DENABLE_STRICT_TRY_COMPILE=ON
        -DBUILD_SHARED_LIBS=ON
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- Boost -------------------
ExternalProject_Add(boost
    DEPENDS ios_toolchain
    URL https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}-cmake.tar.gz
    SOURCE_DIR "${SRC_DIR}/boost"
    PATCH_COMMAND patch -p1 -d libs/system < ${PATCHES_DIR}/system.diff
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DBOOST_INCLUDE_LIBRARIES=filesystem\;program_options\;iostreams\;geometry\;system
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- libiconv -------------------
ExternalProject_Add(iconv
    DEPENDS ios_toolchain
    URL https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz
    SOURCE_DIR "${SRC_DIR}/libiconv"
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} <SOURCE_DIR>/configure --host=arm-apple-darwin --prefix=${INSTALL_PREFIX} --disable-nls --enable-static --disable-shared
    BUILD_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make -j${BUILD_JOBS}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make install
)

# ------------------- liblzma -------------------
ExternalProject_Add(liblzma
    DEPENDS ios_toolchain
    URL https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/xz-${XZ_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/xz"
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} <SOURCE_DIR>/configure --host=arm-apple-darwin --prefix=${INSTALL_PREFIX}
        --disable-rpath --disable-nls --disable-doc --disable-scripts --disable-lzmainfo --disable-lzmadec --disable-lzma-links --disable-xz --disable-xzdec --disable-xzdiff --disable-xzgrep --disable-xzless --disable-xzmore SKIP_WERROR_CHECK=yes
    BUILD_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make -j${BUILD_JOBS}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make install
)

# ------------------- FFmpeg -------------------
ExternalProject_Add(ffmpeg
    DEPENDS ios_toolchain iconv
    URL https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2
    SOURCE_DIR "${SRC_DIR}/ffmpeg"
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} <SOURCE_DIR>/configure
        --prefix=${INSTALL_PREFIX}
        --sysroot=${IOS_SDK_PATH}
        --arch=arm64
        --target-os=darwin
        --enable-cross-compile
        --enable-pic
        --cc=${IOS_CLANG}
        --cxx=${IOS_CLANGXX}
        --ar=${IOS_AR}
        --nm=${IOS_NM}
        --ranlib=${IOS_RANLIB}
        --extra-cflags="-arch ${ARCH} ${MIN_VERSION_FLAG} ${COMMON_FLAGS}"
        --extra-ldflags="-arch ${ARCH} -isysroot ${IOS_SDK_PATH} -L${INSTALL_PREFIX}/lib"
        --disable-everything
        --disable-programs
        --disable-doc
        --enable-decoder=mp3 --enable-demuxer=mp3
        --enable-decoder=bink --enable-decoder=binkaudio_rdft --enable-decoder=binkaudio_dct
        --enable-demuxer=bink --enable-demuxer=wav --enable-decoder=pcm_*
        --enable-decoder=vp8 --enable-decoder=vp9 --enable-decoder=opus --enable-decoder=vorbis
        --enable-demuxer=matroska --enable-demuxer=ogg
        --disable-asm --disable-optimizations --disable-audiotoolbox --disable-iconv --disable-avfilter --disable-avdevice --disable-lzma --disable-videotoolbox
    BUILD_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make -j${BUILD_JOBS}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E env ${CONFIGURE_ENV} make install
)

# ------------------- SDL2 -------------------
ExternalProject_Add(sdl2
    DEPENDS ios_toolchain
    URL https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/sdl2"
    PATCH_COMMAND patch -p1 < ${PATCHES_DIR}/sdl2_ios_scene.patch
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS} -DSDL_STATIC=OFF -DSDL_SHARED=ON -DSDL_FORCE_GCC_FVISIBILITY=OFF
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- Bullet -------------------
ExternalProject_Add(bullet
    DEPENDS ios_toolchain
    URL https://github.com/bulletphysics/bullet3/archive/${BULLET_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/bullet"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
        -DBUILD_BULLET2_DEMOS=OFF -DBUILD_CPU_DEMOS=OFF -DBUILD_UNIT_TESTS=OFF -DBUILD_EXTRAS=OFF
        -DUSE_DOUBLE_PRECISION=ON -DBULLET2_MULTITHREADING=ON -DBUILD_SHARED_LIBS=OFF -DINSTALL_LIBS=ON
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- MyGUI -------------------
ExternalProject_Add(mygui
    DEPENDS ios_toolchain freetype
    URL https://github.com/MyGUI/mygui/archive/MyGUI${MYGUI_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/mygui"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DMYGUI_RENDERSYSTEM=1 -DMYGUI_BUILD_DEMOS=OFF -DMYGUI_BUILD_TOOLS=OFF -DMYGUI_BUILD_PLUGINS=OFF
        -DMYGUI_DONT_USE_OBSOLETE=ON -DMYGUI_STATIC=ON -DBUILD_SHARED_LIBS=OFF
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- LZ4 -------------------
ExternalProject_Add(lz4
    DEPENDS ios_toolchain
    URL https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/lz4"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR>/build/cmake ${CMAKE_PLATFORM_ARGS} -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- Libogg & Vorbis -------------------
ExternalProject_Add(libogg
    DEPENDS ios_toolchain
    URL https://github.com/xiph/ogg/releases/download/v1.3.5/libogg-1.3.5.tar.gz
    SOURCE_DIR "${SRC_DIR}/libogg"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS} -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

ExternalProject_Add(vorbis
    DEPENDS ios_toolchain libogg
    URL https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz
    SOURCE_DIR "${SRC_DIR}/vorbis"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS} -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- COLLADA-DOM -------------------
ExternalProject_Add(collada
    DEPENDS ios_toolchain boost libxml2 zlib
    URL https://github.com/rdiankov/collada-dom/archive/v${COLLADA_DOM_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/collada"
    PATCH_COMMAND sed -i ".bak" "s|#include <boost/filesystem/convenience.hpp>|#include <boost/filesystem.hpp>|g" dom/include/dae.h &&
                  sed -i ".bak" "s|#include <boost/filesystem/convenience.hpp>|#include <boost/filesystem.hpp>|g" dom/src/dae/daeUtils.cpp &&
                  sed -i ".bak" "s|archivePath.branch_path().string()|archivePath.parent_path().string()|g" dom/src/dae/daeUtils.cpp
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
        -DCMAKE_CXX_STANDARD=11
        -DCMAKE_CXX_STANDARD_REQUIRED=ON
        -Dliburiparser_FOUND=OFF
        -Dminizip_FOUND=OFF
        "-DCMAKE_CXX_FLAGS=${COMMON_FLAGS} -DNO_BOOST -DNO_ZAE -I<SOURCE_DIR>/dom/external-libs/minizip-1.1"
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- glslang -------------------
ExternalProject_Add(glslang
    DEPENDS ios_toolchain
    GIT_REPOSITORY https://github.com/KhronosGroup/glslang.git
    GIT_TAG main
    SOURCE_DIR "${SRC_DIR}/glslang"
    PATCH_COMMAND sed -i '' "s/3.22.1/3.19.6/g" CMakeLists.txt
          COMMAND sed -i '' "s/CMAKE_CXX_STANDARD 23/CMAKE_CXX_STANDARD 17/g" CMakeLists.txt
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DBUILD_EXTERNAL=OFF -DENABLE_OPT=OFF -DENABLE_PCH=OFF -DENABLE_GLSLANG_BINARIES=OFF
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${INSTALL_PREFIX}/include/glslang
            COMMAND ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR>/glslang ${INSTALL_PREFIX}/include/glslang
            COMMAND ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR>/SPIRV ${INSTALL_PREFIX}/include/glslang/SPIRV
)

# ------------------- spirv-cross -------------------
ExternalProject_Add(spirv-cross
    DEPENDS ios_toolchain
    GIT_REPOSITORY https://github.com/KhronosGroup/SPIRV-Cross.git
    GIT_TAG main
    SOURCE_DIR "${SRC_DIR}/spirv-cross"
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DSPIRV_CROSS_CLI=OFF -DSPIRV_CROSS_ENABLE_CPP=OFF -DSPIRV_CROSS_ENABLE_HLSL=OFF -DSPIRV_CROSS_ENABLE_MSL=OFF
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- OpenSceneGraph -------------------
ExternalProject_Add(osg
    DEPENDS ios_toolchain freetype libpng libjpeg-turbo collada
    URL https://github.com/sisah2/osg/archive/${OSG_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/osg"
    PATCH_COMMAND patch -p1 < ${PATCHES_DIR}/osg_iOS.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/remove-lib-prefix-from-plugins.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/fix-freetype-include-dirs.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/0001-Replace-Atomic-impl-with-std-atomic.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/0002-BufferObject-make-numClients-atomic.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/0004-IncrementalCompileOperation-wrap-some-stuff-in-atomi.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/force-add-plugins.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/dae_collada.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/enable-some-features.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/OSGtextures.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/msaa+clean-log.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/0005-CullSettings-make-inheritanceMask-atomic-to-silence-.patch
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DOPENGL_PROFILE=GLES3 -DOSG_BUILD_PLATFORM_IPHONE=ON -DOSG_WINDOWING_SYSTEM=IOS
        -DDYNAMIC_OPENTHREADS=OFF -DDYNAMIC_OPENSCENEGRAPH=OFF
        -DBUILD_OSG_PLUGIN_OSG=ON -DBUILD_OSG_PLUGIN_DAE=ON -DBUILD_OSG_PLUGIN_DDS=ON
        -DBUILD_OSG_PLUGIN_KTX=ON -DBUILD_OSG_PLUGIN_TGA=ON -DBUILD_OSG_PLUGIN_BMP=ON
        -DBUILD_OSG_PLUGIN_JPEG=ON -DBUILD_OSG_PLUGIN_PNG=ON -DBUILD_OSG_PLUGIN_FREETYPE=ON
        -DOSG_CPP_EXCEPTIONS_AVAILABLE=TRUE -DOSG_GL1_AVAILABLE=OFF -DOSG_GL2_AVAILABLE=OFF
        -DOSG_GL3_AVAILABLE=OFF -DOSG_GLES1_AVAILABLE=OFF -DOSG_GLES2_AVAILABLE=OFF -DOSG_GLES3_AVAILABLE=ON
        -DBUILD_OSG_APPLICATIONS=OFF -DBUILD_OSG_PLUGINS_BY_DEFAULT=OFF -DBUILD_OSG_DEPRECATED_SERIALIZERS=OFF
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)

# ------------------- OpenMW -------------------
ExternalProject_Add(openmw
    DEPENDS ios_toolchain osg bullet mygui luajit icu ffmpeg sdl2 lz4
    URL https://github.com/sisah2/openmw/archive/${OPENMW_VERSION}.tar.gz
    SOURCE_DIR "${SRC_DIR}/openmw"
    PATCH_COMMAND patch -p1 < ${PATCHES_DIR}/OpenMW_iOS_2.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/0001-loadingscreen-disable-for-now.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/0009-windowmanagerimp-always-show-mouse-when-possible-pat.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/ktx.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/base-changes.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/allow-more-es-versions.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/GLES-3-OMW.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/textures.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/features.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/misc.patch
          COMMAND patch -p1 < ${PATCHES_DIR}/iosGLESomw.patch
    CONFIGURE_COMMAND ${ENV_CMAKE} <SOURCE_DIR> ${CMAKE_PLATFORM_ARGS}
        -DBUILD_BSATOOL=0 -DBUILD_NIFTEST=0 -DBUILD_ESMTOOL=0 -DBUILD_LAUNCHER=0
        -DBUILD_MWINIIMPORTER=0 -DBUILD_ESSIMPORTER=0 -DBUILD_OPENCS=0 -DBUILD_NAVMESHTOOL=0
        -DBUILD_WIZARD=0 -DBUILD_MYGUI_PLUGIN=0 -DBUILD_BULLETOBJECTTOOL=0
        -DOPENMW_USE_SYSTEM_SQLITE3=OFF -DOPENMW_USE_SYSTEM_YAML_CPP=OFF -DOPENMW_USE_SYSTEM_ICU=ON
        -DLUA_HAS_CUSTOM_ALLOCATOR=ON -DOSG_STATIC=TRUE -DCMAKE_CXX_STANDARD=20
    BUILD_COMMAND ${ENV_CMAKE} --build . --config Release
    INSTALL_COMMAND ${ENV_CMAKE} --install . --config Release
)
