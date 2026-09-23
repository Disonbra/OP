cmake_minimum_required(VERSION 3.20)

if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()

if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    project(openmw_ios_deps NONE)
endif()

include(ExternalProject)
include(ProcessorCount)

ProcessorCount(NUM_CORES)
if(NOT NUM_CORES OR NUM_CORES EQUAL 0)
    set(NUM_CORES 8)
endif()

# ------------------- Configuration & Versions -------------------
set(DEPLOYMENT_TARGET "26.2" CACHE STRING "iOS Deployment Target")
set(COMMON_FLAGS "-O3 -fPIC -stdlib=libc++")
set(IOS_PLATFORMS "SIMULATORARM64" CACHE STRING "Target iOS platforms (OS64, SIMULATORARM64)")

set(LIBJPEG_TURBO_VERSION "3.1.0")
set(LIBPNG_VERSION "1.6.48")
set(FREETYPE2_VERSION "2.14.1")
set(OPENAL_VERSION "1.24.3")
set(BOOST_VERSION "1.88.0")
set(LIBICU_VERSION "78.1")
set(FFMPEG_VERSION "7.1.1")
set(SDL2_VERSION "2.32.4")
set(BULLET_VERSION "3.25")
set(ZLIB_VERSION "1.3.2")
set(LIBXML2_VERSION "2.14.3")
set(MYGUI_VERSION "3.4.3")
set(COLLADA_DOM_VERSION "2.5.0")
set(OSG_VERSION "495b370da37d9e3c739914a190f9821884619a4a")
set(LZ4_VERSION "1.10.0")
set(OPENMW_VERSION "96565e9afb9bbebf77c1bbc108d5bf4f9bee2e6f")
set(XZ_VERSION "5.8.2")
set(LIBICONV_VERSION "1.17")
set(LIBOGG_VERSION "1.3.5")
set(LIBVORBIS_VERSION "1.3.7")

# ------------------- Directories Setup -------------------
set(WORK_DIR "${CMAKE_BINARY_DIR}/ios_build")
set(SRC_DIR "${WORK_DIR}/src")
set(PREFIX "${WORK_DIR}/ios-libs")
set(TOOLCHAIN_DIR "${WORK_DIR}/ios-cmake")
set(TOOLCHAIN_FILE "${TOOLCHAIN_DIR}/ios.toolchain.cmake")
set(PATCHES_DIR "${CMAKE_CURRENT_LIST_DIR}/patches")

file(MAKE_DIRECTORY "${SRC_DIR}" "${PREFIX}")

# ------------------- Query iOS SDK Paths -------------------
execute_process(
    COMMAND xcrun --sdk iphoneos --show-sdk-path
    OUTPUT_VARIABLE SDK_PATH_OS64
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(
    COMMAND xcrun --sdk iphonesimulator --show-sdk-path
    OUTPUT_VARIABLE SDK_PATH_SIMULATORARM64
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(MIN_FLAG_OS64 "-miphoneos-version-min=${DEPLOYMENT_TARGET}")
set(MIN_FLAG_SIMULATORARM64 "-mios-simulator-version-min=${DEPLOYMENT_TARGET}")

set(CFLAGS_OS64 "${COMMON_FLAGS} -isysroot ${SDK_PATH_OS64} -arch arm64 ${MIN_FLAG_OS64}")
set(CPPFLAGS_OS64 "-isysroot ${SDK_PATH_OS64}")
set(LDFLAGS_OS64 "-isysroot ${SDK_PATH_OS64}")

set(CFLAGS_SIMULATORARM64 "${COMMON_FLAGS} -isysroot ${SDK_PATH_SIMULATORARM64} -arch arm64 ${MIN_FLAG_SIMULATORARM64}")
set(CPPFLAGS_SIMULATORARM64 "-isysroot ${SDK_PATH_SIMULATORARM64}")
set(LDFLAGS_SIMULATORARM64 "-isysroot ${SDK_PATH_SIMULATORARM64}")

# ------------------- Toolchain Target -------------------
ExternalProject_Add(ios_toolchain
    GIT_REPOSITORY https://github.com/leetal/ios-cmake.git
    SOURCE_DIR "${TOOLCHAIN_DIR}"
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E echo "Toolchain ready"
    BUILD_COMMAND ${CMAKE_COMMAND} -E echo "Toolchain ready"
    INSTALL_COMMAND ${CMAKE_COMMAND} -E echo "Toolchain ready"
)

# ------------------- Helper: Source Download Target -------------------
function(add_source_target NAME)
    cmake_parse_arguments(ARG "" "URL;URL_HASH;GIT_REPOSITORY;GIT_TAG;SOURCE_DIR_NAME" "PATCH_COMMAND" ${ARGN})
    if(NOT ARG_SOURCE_DIR_NAME)
        set(ARG_SOURCE_DIR_NAME "${NAME}")
    endif()

    set(ep_args
        PREFIX "${WORK_DIR}/${NAME}_src"
        SOURCE_DIR "${SRC_DIR}/${ARG_SOURCE_DIR_NAME}"
        CONFIGURE_COMMAND ${CMAKE_COMMAND} -E echo "Source configured for ${NAME}"
        BUILD_COMMAND ${CMAKE_COMMAND} -E echo "Source built for ${NAME}"
        INSTALL_COMMAND ${CMAKE_COMMAND} -E echo "Source installed for ${NAME}"
    )

    if(ARG_URL)
        list(APPEND ep_args URL "${ARG_URL}")
        if(ARG_URL_HASH)
            list(APPEND ep_args URL_HASH "${ARG_URL_HASH}")
        endif()
    elseif(ARG_GIT_REPOSITORY)
        list(APPEND ep_args GIT_REPOSITORY "${ARG_GIT_REPOSITORY}")
        if(ARG_GIT_TAG)
            list(APPEND ep_args GIT_TAG "${ARG_GIT_TAG}")
        endif()
    endif()

    if(ARG_PATCH_COMMAND)
        list(APPEND ep_args PATCH_COMMAND ${ARG_PATCH_COMMAND})
    endif()

    ExternalProject_Add(${NAME}_src ${ep_args})
endfunction()

# ------------------- Helper: CMake Platform Subproject -------------------
function(add_ios_cmake_dependency NAME SOURCE_DIR_NAME)
    cmake_parse_arguments(ARG "" "SOURCE_SUBDIR" "DEPENDS;EXTRA_ARGS" ${ARGN})

    foreach(PLATFORM IN LISTS IOS_PLATFORMS)
        set(install_prefix "${PREFIX}/${PLATFORM}")
        set(target_name "${NAME}_${PLATFORM}")

        set(default_cmake_args
            "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
            "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
            "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
            "-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"
            "-DCMAKE_IGNORE_PATH=/usr;/usr/local;/opt/local;/opt/homebrew"
            "-DCMAKE_SYSTEM_IGNORE_PATH=/usr;/usr/local"
            "-DCMAKE_PREFIX_PATH=${install_prefix}"
            "-DCMAKE_FIND_ROOT_PATH=${install_prefix}"
            "-DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=TRUE"
            "-DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}"
            "-DPLATFORM=${PLATFORM}"
            "-DDEPLOYMENT_TARGET=${DEPLOYMENT_TARGET}"
            "-DCMAKE_INSTALL_PREFIX=${install_prefix}"
            "-DCMAKE_BUILD_TYPE=Release"
            "-DDEFAULT_ES=2"
            "-DNOX11=1"
            "-DNOEGL=1"
            "-DSTATICLIB=0"
            "-DCMAKE_C_FLAGS=${COMMON_FLAGS}"
            "-DCMAKE_CXX_FLAGS=-I${install_prefix}/include/ -I${install_prefix}/include/freetype2/ ${COMMON_FLAGS}"
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
            "-DOPENGL_INCLUDE_DIR=${install_prefix}/include/gl4es/include/"
            "-DMyGUI_LIBRARY=${install_prefix}/lib/libMyGUIEngineStatic.a"
            "-DOPENGL_gl_LIBRARY=${install_prefix}/lib/libGL.dylib"
            "-DOPENGL_glx_LIBRARY=${install_prefix}/lib/libGL.dylib"
            "-DOPENAL_INCLUDE_DIR=${install_prefix}/include/AL/"
            "-DBullet_INCLUDE_DIR=${install_prefix}/include/bullet/"
            "-DJPEG_INCLUDE_DIR=${install_prefix}/include/"
            "-DPNG_INCLUDE_DIR=${install_prefix}/include/"
            "-DPNG_LIBRARY=${install_prefix}/lib/libpng16.a"
            "-DCOLLADA_INCLUDE_DIR=${install_prefix}/include/collada-dom2.5/"
            "-DCOLLADA_DOM_ROOT=${install_prefix}/include/collada-dom2.5/1.4/dom"
            "-Wno-deprecated"
            "-Wno-dev"
            "-DIOS_DEPS_PREFIX=${install_prefix}"
        )

        set(platform_deps ios_toolchain ${NAME}_src)
        foreach(dep IN LISTS ARG_DEPENDS)
            list(APPEND platform_deps "${dep}_${PLATFORM}")
        endforeach()

        set(ep_args
            PREFIX "${WORK_DIR}/${target_name}"
            SOURCE_DIR "${SRC_DIR}/${SOURCE_DIR_NAME}"
            BINARY_DIR "${WORK_DIR}/build_${NAME}_${PLATFORM}"
            INSTALL_DIR "${install_prefix}"
            DEPENDS ${platform_deps}
            DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E echo "Using source for ${NAME}_${PLATFORM}"
            CMAKE_GENERATOR Xcode
            CMAKE_ARGS ${default_cmake_args} ${ARG_EXTRA_ARGS}
            BUILD_COMMAND ${CMAKE_COMMAND} --build . --config Release
            INSTALL_COMMAND ${CMAKE_COMMAND} --install . --config Release
        )

        if(ARG_SOURCE_SUBDIR)
            list(APPEND ep_args SOURCE_SUBDIR "${ARG_SOURCE_SUBDIR}")
        endif()

        ExternalProject_Add(${target_name} ${ep_args})
    endforeach()
endfunction()

# ------------------- 1. ICU -------------------
add_source_target(icu
    URL "https://github.com/unicode-org/icu/archive/refs/tags/release-${LIBICU_VERSION}.tar.gz"
    SOURCE_DIR_NAME "icu-release-${LIBICU_VERSION}"
)

ExternalProject_Add(icu_host
    DEPENDS icu_src
    SOURCE_DIR "${SRC_DIR}/icu-release-${LIBICU_VERSION}/icu4c/source"
    BINARY_DIR "${WORK_DIR}/icu_host_build"
    INSTALL_DIR "${WORK_DIR}/icu_host_install"
    DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E echo "Using source for icu_host"
    CONFIGURE_COMMAND <SOURCE_DIR>/configure
        --prefix=${WORK_DIR}/icu_host_install
        --disable-tests
        --disable-samples
        --disable-icuio
        --disable-extras
    BUILD_COMMAND make -j${NUM_CORES}
    INSTALL_COMMAND make install
)

foreach(PLATFORM IN LISTS IOS_PLATFORMS)
    ExternalProject_Add(icu_${PLATFORM}
        DEPENDS icu_src icu_host
        SOURCE_DIR "${SRC_DIR}/icu-release-${LIBICU_VERSION}/icu4c/source"
        BINARY_DIR "${WORK_DIR}/build_icu_${PLATFORM}"
        INSTALL_DIR "${PREFIX}/${PLATFORM}"
        DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E echo "Using source for icu_${PLATFORM}"
        CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env
            "CFLAGS=${CFLAGS_${PLATFORM}}"
            "CPPFLAGS=${CPPFLAGS_${PLATFORM}}"
            "LDFLAGS=${LDFLAGS_${PLATFORM}}"
            <SOURCE_DIR>/configure
            --host=arm-apple-darwin
            --prefix=${PREFIX}/${PLATFORM}
            --enable-static
            --disable-shared
            --disable-tests
            --disable-samples
            --disable-icuio
            --disable-extras
            --disable-tools
            --with-cross-build=${WORK_DIR}/icu_host_build
        BUILD_COMMAND make -j${NUM_CORES}
        INSTALL_COMMAND make install
    )
endforeach()

# ------------------- 2. Bzip2 -------------------
add_source_target(bzip2
    GIT_REPOSITORY https://github.com/libarchive/bzip2.git
    SOURCE_DIR_NAME "bzip2"
)
add_ios_cmake_dependency(bzip2 bzip2
    EXTRA_ARGS
        -DBUILD_SHARED_LIBS=OFF
        -DBUILD_STATIC_LIBS=ON
        -DENABLE_APP=OFF
)

# ------------------- 3. LuaJIT -------------------
add_source_target(luajit
    GIT_REPOSITORY https://github.com/mpvkit/libluajit-build.git
    GIT_TAG main
    SOURCE_DIR_NAME "luajit"
)

foreach(PLATFORM IN LISTS IOS_PLATFORMS)
    if(PLATFORM STREQUAL "OS64")
        set(LUAJIT_TARGET "ios")
        set(LUAJIT_LIB_SUBDIR "ios")
    else()
        set(LUAJIT_TARGET "isimulator")
        set(LUAJIT_LIB_SUBDIR "isimulator")
    endif()

    ExternalProject_Add(luajit_${PLATFORM}
        DEPENDS luajit_src
        SOURCE_DIR "${SRC_DIR}/luajit"
        BINARY_DIR "${SRC_DIR}/luajit"
        DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E echo "Using source for luajit_${PLATFORM}"
        CONFIGURE_COMMAND ${CMAKE_COMMAND} -E echo "Configuring LuaJIT"
        BUILD_COMMAND make build platform=${LUAJIT_TARGET} XCFLAGS+=-DLUAJIT_ENABLE_GC64
        INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory "${PREFIX}/${PLATFORM}/include" "${PREFIX}/${PLATFORM}/lib"
        COMMAND ${CMAKE_COMMAND} -E copy_directory "<SOURCE_DIR>/dist/release/libluajit/include/luajit-2.1" "${PREFIX}/${PLATFORM}/include"
        COMMAND ${CMAKE_COMMAND} -E copy "<SOURCE_DIR>/dist/release/libluajit/lib/${LUAJIT_LIB_SUBDIR}/thin/arm64/lib/libluajit.a" "${PREFIX}/${PLATFORM}/lib/libluajit.a"
    )
endforeach()

# ------------------- 4. Zlib -------------------
add_source_target(zlib
    URL "https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz"
    SOURCE_DIR_NAME "zlib-${ZLIB_VERSION}"
)
add_ios_cmake_dependency(zlib zlib-${ZLIB_VERSION})

# ------------------- 5. libpng -------------------
add_source_target(libpng
    URL "https://downloads.sourceforge.net/project/libpng/libpng16/${LIBPNG_VERSION}/libpng-${LIBPNG_VERSION}.tar.gz"
    SOURCE_DIR_NAME "libpng-${LIBPNG_VERSION}"
)

foreach(PLATFORM IN LISTS IOS_PLATFORMS)
    ExternalProject_Add(libpng_${PLATFORM}
        DEPENDS libpng_src zlib_${PLATFORM}
        SOURCE_DIR "${SRC_DIR}/libpng-${LIBPNG_VERSION}"
        BINARY_DIR "${WORK_DIR}/build_libpng_${PLATFORM}"
        INSTALL_DIR "${PREFIX}/${PLATFORM}"
        DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E echo "Using source for libpng_${PLATFORM}"
        CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env
            "CFLAGS=${CFLAGS_${PLATFORM}} -I${PREFIX}/${PLATFORM}/include"
            "CPPFLAGS=${CPPFLAGS_${PLATFORM}} -I${PREFIX}/${PLATFORM}/include"
            "LDFLAGS=${LDFLAGS_${PLATFORM}} -L${PREFIX}/${PLATFORM}/lib"
            <SOURCE_DIR>/configure
            --host=arm-apple-darwin
            --prefix=${PREFIX}/${PLATFORM}
            --enable-static
            --disable-shared
        BUILD_COMMAND make -j${NUM_CORES}
        INSTALL_COMMAND make install
    )
endforeach()

# ------------------- 6. FreeType -------------------
add_source_target(freetype
    URL "https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE2_VERSION}.tar.xz"
    SOURCE_DIR_NAME "freetype-${FREETYPE2_VERSION}"
)
add_ios_cmake_dependency(freetype freetype-${FREETYPE2_VERSION}
    DEPENDS zlib libpng bzip2
)

# ------------------- 7. GL4ES -------------------
add_source_target(gl4es
    GIT_REPOSITORY https://github.com/khanhduytran0/gl4es.git
    GIT_TAG "e095812c2ff29971ca76c481035934fbac976ce0"
    SOURCE_DIR_NAME "gl4es"
    PATCH_COMMAND bash -c "patch -p1 -t -N -i \"${PATCHES_DIR}/gl4es_114.patch\" || true"
)

foreach(PLATFORM IN LISTS IOS_PLATFORMS)
    set(install_prefix "${PREFIX}/${PLATFORM}")
    ExternalProject_Add(gl4es_${PLATFORM}
        DEPENDS ios_toolchain gl4es_src
        SOURCE_DIR "${SRC_DIR}/gl4es"
        BINARY_DIR "${WORK_DIR}/build_gl4es_${PLATFORM}"
        INSTALL_DIR "${install_prefix}"
        DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E echo "Using source for gl4es_${PLATFORM}"
        CMAKE_GENERATOR Xcode
        CMAKE_ARGS
            "-DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}"
            "-DPLATFORM=${PLATFORM}"
            "-DDEPLOYMENT_TARGET=${DEPLOYMENT_TARGET}"
            "-DCMAKE_INSTALL_PREFIX=${install_prefix}"
            "-DCMAKE_BUILD_TYPE=Release"
            "-DDEFAULT_ES=2"
            "-DNOX11=1"
            "-DNOEGL=1"
            "-DSTATICLIB=0"
            "-DCMAKE_C_FLAGS=${COMMON_FLAGS}"
            "-DCMAKE_CXX_FLAGS=-I${install_prefix}/include/ ${COMMON_FLAGS}"
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
        INSTALL_COMMAND ${CMAKE_COMMAND} -DSRC_DIR=${SRC_DIR}/gl4es -DDEST_DIR=${install_prefix} -P "${CMAKE_CURRENT_LIST_DIR}/install_gl4es.cmake"
    )
endforeach()

# ------------------- 8. libxml2 -------------------
add_source_target(libxml2
    URL "https://download.gnome.org/sources/libxml2/2.14/libxml2-${LIBXML2_VERSION}.tar.xz"
    SOURCE_DIR_NAME "libxml2-${LIBXML2_VERSION}"
)
add_ios_cmake_dependency(libxml2 libxml2-${LIBXML2_VERSION}
    DEPENDS zlib
    EXTRA_ARGS
        -DBUILD_SHARED_LIBS=OFF
        -DLIBXML2_WITH_THREADS=ON
        -DLIBXML2_WITH_ZLIB=ON
        -DLIBXML2_WITH_ICONV=OFF
        -DLIBXML2_WITH_LZMA=OFF
        -DLIBXML2_WITH_PROGRAMS=OFF
        -DLIBXML2_WITH_TESTS=OFF
        -DLIBXML2_WITH_PYTHON=OFF
)

# ------------------- 9. libjpeg-turbo -------------------
add_source_target(libjpeg_turbo
    URL "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${LIBJPEG_TURBO_VERSION}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz"
    SOURCE_DIR_NAME "libjpeg-turbo-${LIBJPEG_TURBO_VERSION}"
)
add_ios_cmake_dependency(libjpeg_turbo libjpeg-turbo-${LIBJPEG_TURBO_VERSION}
    EXTRA_ARGS
        -DENABLE_SHARED=ON
        -DENABLE_STATIC=ON
        -DWITH_TURBOJPEG=ON
        -DWITH_TOOLS=OFF
)

# ------------------- 10. OpenAL-Soft -------------------
add_source_target(openal
    URL "https://github.com/kcat/openal-soft/archive/${OPENAL_VERSION}.tar.gz"
    SOURCE_DIR_NAME "openal-soft-${OPENAL_VERSION}"
)
add_ios_cmake_dependency(openal openal-soft-${OPENAL_VERSION}
    EXTRA_ARGS
        -DALSOFT_EXAMPLES=OFF
        -DALSOFT_TESTS=OFF
        -DALSOFT_UTILS=OFF
        -DALSOFT_NO_CONFIG_UTIL=ON
        -DALSOFT_BACKEND_WAVE=OFF
        -DALSOFT_REQUIRE_COREAUDIO=ON
        -DENABLE_STRICT_TRY_COMPILE=ON
        -DBUILD_SHARED_LIBS=ON
)

# ------------------- 11. Boost -------------------
add_source_target(boost
    URL "https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}-cmake.tar.gz"
    SOURCE_DIR_NAME "boost-${BOOST_VERSION}"
    PATCH_COMMAND bash -c "patch -p1 -t -N -d libs/system -i \"${PATCHES_DIR}/system.diff\" || true"
)
add_ios_cmake_dependency(boost boost-${BOOST_VERSION}
    EXTRA_ARGS
        -DBOOST_INCLUDE_LIBRARIES=filesystem\;program_options\;iostreams\;geometry\;system
)

foreach(PLATFORM IN LISTS IOS_PLATFORMS)
    ExternalProject_Add_Step(boost_${PLATFORM} ranlib
        COMMAND ${CMAKE_COMMAND} -E echo "Running ranlib on boost libraries..."
        COMMAND bash -c "xcrun ranlib ${PREFIX}/${PLATFORM}/lib/libboost_*.a 2>/dev/null || true"
        DEPENDEE install
    )
endforeach()

# ------------------- 12. libiconv -------------------
add_source_target(libiconv
    URL "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${LIBICONV_VERSION}.tar.gz"
    SOURCE_DIR_NAME "libiconv-${LIBICONV_VERSION}"
)

foreach(PLATFORM IN LISTS IOS_PLATFORMS)
    ExternalProject_Add(libiconv_${PLATFORM}
        DEPENDS libiconv_src
        SOURCE_DIR "${SRC_DIR}/libiconv-${LIBICONV_VERSION}"
        BINARY_DIR "${WORK_DIR}/build_iconv_${PLATFORM}"
        INSTALL_DIR "${PREFIX}/${PLATFORM}"
        DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E echo "Using source for libiconv_${PLATFORM}"
        CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env
            "CFLAGS=${CFLAGS_${PLATFORM}}"
            "CPPFLAGS=${CPPFLAGS_${PLATFORM}}"
            "LDFLAGS=${LDFLAGS_${PLATFORM}}"
            <SOURCE_DIR>/configure
            --host=arm-apple-darwin
            --prefix=${PREFIX}/${PLATFORM}
            --enable-static
            --disable-shared
            --disable-nls
        BUILD_COMMAND make -j${NUM_CORES}
        INSTALL_COMMAND make install
    )
endforeach()

# ------------------- 13. liblzma -------------------
add_source_target(liblzma
    URL "https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/xz-${XZ_VERSION}.tar.gz"
    SOURCE_DIR_NAME "xz-${XZ_VERSION}"
)

foreach(PLATFORM IN LISTS IOS_PLATFORMS)
    ExternalProject_Add(liblzma_${PLATFORM}
        DEPENDS liblzma_src
        SOURCE_DIR "${SRC_DIR}/xz-${XZ_VERSION}"
        BINARY_DIR "${WORK_DIR}/build_liblzma_${PLATFORM}"
        INSTALL_DIR "${PREFIX}/${PLATFORM}"
        DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E echo "Using source for liblzma_${PLATFORM}"
        CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env
            "CFLAGS=${CFLAGS_${PLATFORM}}"
            "CPPFLAGS=${CPPFLAGS_${PLATFORM}}"
            "LDFLAGS=${LDFLAGS_${PLATFORM}}"
            <SOURCE_DIR>/configure
            --host=arm-apple-darwin
            --prefix=${PREFIX}/${PLATFORM}
            --enable-static
            --disable-shared
            --disable-rpath
            --disable-nls
            --disable-doc
            --disable-scripts
            --disable-lzmainfo
            --disable-lzmadec
            --disable-lzma-links
            --disable-xz
            --disable-xzdec
            --disable-xzdiff
            --disable-xzgrep
            --disable-xzless
            --disable-xzmore
            SKIP_WERROR_CHECK=yes
        BUILD_COMMAND make -j${NUM_CORES}
        INSTALL_COMMAND make install
    )
endforeach()

# ------------------- 14. FFmpeg -------------------
add_source_target(ffmpeg
    URL "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2"
    SOURCE_DIR_NAME "ffmpeg-${FFMPEG_VERSION}"
)

foreach(PLATFORM IN LISTS IOS_PLATFORMS)
    ExternalProject_Add(ffmpeg_${PLATFORM}
        DEPENDS ffmpeg_src libiconv_${PLATFORM}
        SOURCE_DIR "${SRC_DIR}/ffmpeg-${FFMPEG_VERSION}"
        BINARY_DIR "${WORK_DIR}/build_ffmpeg_${PLATFORM}"
        INSTALL_DIR "${PREFIX}/${PLATFORM}"
        DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E echo "Using source for ffmpeg_${PLATFORM}"
        CONFIGURE_COMMAND <SOURCE_DIR>/configure
            --prefix=${PREFIX}/${PLATFORM}
            --sysroot=${SDK_PATH_${PLATFORM}}
            --extra-cflags=-arch\ arm64\ ${MIN_FLAG_${PLATFORM}}\ ${COMMON_FLAGS}\ -I${PREFIX}/${PLATFORM}/include
            --extra-ldflags=-arch\ arm64\ -isysroot\ ${SDK_PATH_${PLATFORM}}\ -L${PREFIX}/${PLATFORM}/lib
            --arch=arm64
            --enable-cross-compile
            --target-os=darwin
            --cc=clang
            --enable-pic
            --disable-everything
            --disable-programs
            --disable-doc
            --enable-decoder=mp3
            --enable-demuxer=mp3
            --enable-decoder=bink
            --enable-decoder=binkaudio_rdft
            --enable-decoder=binkaudio_dct
            --enable-demuxer=bink
            --enable-demuxer=wav
            --enable-decoder=pcm_*
            --enable-decoder=vp8
            --enable-decoder=vp9
            --enable-decoder=opus
            --enable-decoder=vorbis
            --enable-demuxer=matroska
            --enable-demuxer=ogg
            --disable-asm
            --disable-optimizations
            --disable-audiotoolbox
            --disable-iconv
            --disable-avfilter
            --disable-avdevice
            --disable-lzma
            --disable-videotoolbox
        BUILD_COMMAND make -j${NUM_CORES}
        INSTALL_COMMAND make install
    )
endforeach()

# ------------------- 15. SDL2 -------------------
add_source_target(sdl2
    URL "https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz"
    SOURCE_DIR_NAME "SDL2-${SDL2_VERSION}"
    PATCH_COMMAND bash -c "patch -p1 -t -N -i \"${PATCHES_DIR}/sdl2_ios_scene.patch\" || true"
)
add_ios_cmake_dependency(sdl2 SDL2-${SDL2_VERSION}
    EXTRA_ARGS
        -DSDL_STATIC=OFF
        -DSDL_SHARED=ON
        -DSDL_FORCE_GCC_FVISIBILITY=OFF
)

# ------------------- 16. Bullet Physics -------------------
add_source_target(bullet
    URL "https://github.com/bulletphysics/bullet3/archive/${BULLET_VERSION}.tar.gz"
    SOURCE_DIR_NAME "bullet3-${BULLET_VERSION}"
)
add_ios_cmake_dependency(bullet bullet3-${BULLET_VERSION}
    EXTRA_ARGS
        -DBUILD_BULLET2_DEMOS=OFF
        -DBUILD_CPU_DEMOS=OFF
        -DBUILD_UNIT_TESTS=OFF
        -DBUILD_EXTRAS=OFF
        -DUSE_DOUBLE_PRECISION=ON
        -DBULLET2_MULTITHREADING=ON
        -DBUILD_SHARED_LIBS=OFF
        -DINSTALL_LIBS=ON
)

# ------------------- 17. MyGUI -------------------
add_source_target(mygui
    URL "https://github.com/MyGUI/mygui/archive/MyGUI${MYGUI_VERSION}.tar.gz"
    SOURCE_DIR_NAME "mygui-MyGUI${MYGUI_VERSION}"
)
add_ios_cmake_dependency(mygui mygui-MyGUI${MYGUI_VERSION}
    DEPENDS freetype
    EXTRA_ARGS
        -DMYGUI_RENDERSYSTEM=1
        -DMYGUI_BUILD_DEMOS=OFF
        -DMYGUI_BUILD_TOOLS=OFF
        -DMYGUI_BUILD_PLUGINS=OFF
        -DMYGUI_DONT_USE_OBSOLETE=ON
        -DMYGUI_STATIC=ON
        -DBUILD_SHARED_LIBS=OFF
)

# ------------------- 18. LZ4 -------------------
add_source_target(lz4
    URL "https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz"
    SOURCE_DIR_NAME "lz4-${LZ4_VERSION}"
)
add_ios_cmake_dependency(lz4 lz4-${LZ4_VERSION}
    SOURCE_SUBDIR "build/cmake"
    EXTRA_ARGS
        -DBUILD_STATIC_LIBS=ON
        -DBUILD_SHARED_LIBS=OFF
)

# ------------------- 19. libogg -------------------
add_source_target(libogg
    URL "https://github.com/xiph/ogg/releases/download/v1.3.5/libogg-${LIBOGG_VERSION}.tar.gz"
    SOURCE_DIR_NAME "libogg-${LIBOGG_VERSION}"
)
add_ios_cmake_dependency(libogg libogg-${LIBOGG_VERSION})

# ------------------- 20. Vorbis -------------------
add_source_target(vorbis
    URL "https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-${LIBVORBIS_VERSION}.tar.gz"
    SOURCE_DIR_NAME "libvorbis-${LIBVORBIS_VERSION}"
)
add_ios_cmake_dependency(vorbis libvorbis-${LIBVORBIS_VERSION}
    DEPENDS libogg
)

# ------------------- 21. COLLADA-DOM -------------------
add_source_target(collada
    URL "https://github.com/rdiankov/collada-dom/archive/v${COLLADA_DOM_VERSION}.tar.gz"
    SOURCE_DIR_NAME "collada-dom-${COLLADA_DOM_VERSION}"
    PATCH_COMMAND ${CMAKE_COMMAND} -DCOLLADA_DIR=${SRC_DIR}/collada-dom-${COLLADA_DOM_VERSION} -P "${CMAKE_CURRENT_LIST_DIR}/patch_collada.cmake"
)
add_ios_cmake_dependency(collada collada-dom-${COLLADA_DOM_VERSION}
    DEPENDS boost libxml2
    EXTRA_ARGS
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_CXX_STANDARD=11
        -DCMAKE_CXX_STANDARD_REQUIRED=ON
        "-DCMAKE_CXX_FLAGS=-DNO_BOOST -DNO_ZAE ${COMMON_FLAGS}"
)

# ------------------- 22. OpenSceneGraph (OSG) -------------------
add_source_target(osg
    URL "https://github.com/Duron27/osg/archive/${OSG_VERSION}.tar.gz"
    SOURCE_DIR_NAME "osg-${OSG_VERSION}"
    PATCH_COMMAND bash -c "patch -p1 -t -N -i \"${PATCHES_DIR}/osg_iOS.patch\" || true"
)
add_ios_cmake_dependency(osg osg-${OSG_VERSION}
    DEPENDS gl4es freetype libjpeg_turbo libpng collada
    EXTRA_ARGS
        -DOPENGL_PROFILE=GL1
        -DCMAKE_VERBOSE_MAKEFILE=ON
        -DOSG_BUILD_PLATFORM_IPHONE=ON
        -DOSG_WINDOWING_SYSTEM=IOS
        -DDYNAMIC_OPENTHREADS=OFF
        -DDYNAMIC_OPENSCENEGRAPH=OFF
        -DBUILD_OSG_PLUGIN_OSG=ON
        -DBUILD_OSG_PLUGIN_DAE=OFF
        -DBUILD_OSG_PLUGIN_DDS=ON
        -DBUILD_OSG_PLUGIN_TGA=ON
        -DBUILD_OSG_PLUGIN_BMP=ON
        -DBUILD_OSG_PLUGIN_JPEG=ON
        -DBUILD_OSG_PLUGIN_PNG=ON
        -DBUILD_OSG_PLUGIN_KTX=ON
        -DBUILD_OSG_PLUGIN_FREETYPE=ON
        -DOSG_CPP_EXCEPTIONS_AVAILABLE=TRUE
        -DOSG_GL1_AVAILABLE=ON
        -DOSG_GL2_AVAILABLE=OFF
        -DOSG_GL3_AVAILABLE=OFF
        -DOSG_GLES1_AVAILABLE=OFF
        -DOSG_GLES2_AVAILABLE=OFF
        -DOSG_GL_LIBRARY_STATIC=OFF
        -DOSG_GL_DISPLAYLISTS_AVAILABLE=OFF
        -DOSG_GL_MATRICES_AVAILABLE=ON
        -DOSG_GL_VERTEX_FUNCS_AVAILABLE=ON
        -DOSG_GL_VERTEX_ARRAY_FUNCS_AVAILABLE=ON
        -DOSG_GL_FIXED_FUNCTION_AVAILABLE=ON
        -DBUILD_OSG_APPLICATIONS=OFF
        -DBUILD_OSG_PLUGINS_BY_DEFAULT=OFF
        -DBUILD_OSG_DEPRECATED_SERIALIZERS=OFF
        -DOSG_FIND_3RD_PARTY_DEPS=OFF
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_CXX_STANDARD=11
        -DCMAKE_CXX_STANDARD_REQUIRED=ON
)

# ------------------- 23. OpenMW -------------------
add_source_target(openmw
    URL "https://github.com/OpenMW/openmw/archive/${OPENMW_VERSION}.tar.gz"
    SOURCE_DIR_NAME "openmw-${OPENMW_VERSION}"
    PATCH_COMMAND bash -c "patch -p1 -t -N -i \"${PATCHES_DIR}/OpenMW_iOS_2.patch\" || true"
)
add_ios_cmake_dependency(openmw openmw-${OPENMW_VERSION}
    DEPENDS osg bullet mygui sdl2 ffmpeg boost icu luajit openal lz4 liblzma
    EXTRA_ARGS
        -DBUILD_BSATOOL=0
        -DBUILD_NIFTEST=0
        -DBUILD_ESMTOOL=0
        -DBUILD_LAUNCHER=0
        -DBUILD_MWINIIMPORTER=0
        -DBUILD_ESSIMPORTER=0
        -DBUILD_OPENCS=0
        -DBUILD_NAVMESHTOOL=0
        -DBUILD_WIZARD=0
        -DBUILD_MYGUI_PLUGIN=0
        -DBUILD_BULLETOBJECTTOOL=0
        -DOPENMW_USE_SYSTEM_SQLITE3=OFF
        -DOPENMW_USE_SYSTEM_YAML_CPP=OFF
        -DOPENMW_USE_SYSTEM_ICU=ON
        -DLUA_HAS_CUSTOM_ALLOCATOR=ON
        -DOSG_STATIC=TRUE
        -DCMAKE_CXX_STANDARD=20
        -DCMAKE_CXX_STANDARD_REQUIRED=ON
)

# ------------------- Top-Level Targets -------------------
add_custom_target(openmw_ios_all ALL)
foreach(PLATFORM IN LISTS IOS_PLATFORMS)
    add_dependencies(openmw_ios_all openmw_${PLATFORM})
endforeach()

if("OS64" IN_LIST IOS_PLATFORMS AND "SIMULATORARM64" IN_LIST IOS_PLATFORMS)
    set(STAGE_PLATFORM_ARG "both")
elseif("OS64" IN_LIST IOS_PLATFORMS)
    set(STAGE_PLATFORM_ARG "device")
else()
    set(STAGE_PLATFORM_ARG "sim")
endif()

add_custom_target(stage_libs
    COMMAND "${CMAKE_CURRENT_LIST_DIR}/stage_app_libs.sh" "${STAGE_PLATFORM_ARG}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Staging built libraries into app embedded directories"
)
