# Run via: cmake -DREPO_DIR=... -DWORK_DIR=... -DBUILD_DIR=... \
#                -DPLATFORM=... -DDEST=... [-DOPENMW_CONFIG=...] \
#                -P stage_app_libs.cmake

if(NOT DEFINED REPO_DIR OR NOT DEFINED WORK_DIR OR NOT DEFINED PLATFORM OR NOT DEFINED DEST)
    message(FATAL_ERROR "REPO_DIR, WORK_DIR, PLATFORM and DEST must be provided")
endif()
if(NOT DEFINED BUILD_DIR)
    set(BUILD_DIR "${WORK_DIR}/..")
endif()
if(NOT DEFINED OPENMW_CONFIG)
    set(OPENMW_CONFIG Release)
endif()

set(ASSETS_DEST "${REPO_DIR}/iosApp/OpenMWAssets")
set(prefix      "${WORK_DIR}/ios-libs/${PLATFORM}")

# --- Locate the OpenMW source tree (equivalent to: ls -d src/openmw-* | head -1)
# Try the shell-script layout first, then this CMake project's ExternalProject default.
set(_src_candidates)
file(GLOB _globbed "${WORK_DIR}/src/openmw-*")
list(APPEND _src_candidates ${_globbed})
list(APPEND _src_candidates
    "${WORK_DIR}/src/openmw"
    "${BUILD_DIR}/openmw-prefix/src/openmw"
)
set(OPENMW_SRC "")
foreach(c IN LISTS _src_candidates)
    if(IS_DIRECTORY "${c}")
        set(OPENMW_SRC "${c}")
        break()
    endif()
endforeach()
if(OPENMW_SRC STREQUAL "")
    message(FATAL_ERROR "Cannot find OpenMW source tree. Tried: ${_src_candidates}")
endif()

# --- Locate the OpenMW build dir (shell script: ${OPENMW_SRC}/build_openmw_${PLATFORM})
set(_bld_candidates
    "${OPENMW_SRC}/build_openmw_${PLATFORM}"
    "${BUILD_DIR}/openmw-prefix/src/openmw-build"
    "${OPENMW_SRC}/build"
)
set(OPENMW_BUILD "")
foreach(c IN LISTS _bld_candidates)
    if(IS_DIRECTORY "${c}")
        set(OPENMW_BUILD "${c}")
        break()
    endif()
endforeach()
if(OPENMW_BUILD STREQUAL "")
    message(FATAL_ERROR "Cannot find OpenMW build dir. Tried: ${_bld_candidates}")
endif()

# --- Locate the built OpenMW.app bundle
set(_app_candidates
    "${OPENMW_BUILD}/OpenMW.app"
    "${OPENMW_BUILD}/Release/OpenMW.app"
    "${OPENMW_BUILD}/Release-iphoneos/OpenMW.app"
    "${OPENMW_BUILD}/Release-iphonesimulator/OpenMW.app"
)
set(OPENMW_APP "")
foreach(c IN LISTS _app_candidates)
    if(IS_DIRECTORY "${c}")
        set(OPENMW_APP "${c}")
        break()
    endif()
endforeach()

set(DYLIBS
    libSDL2-2.0.0.dylib
    libopenal.1.dylib
    libcollada-dom2.5-dp.0.dylib
    libbz2.1.dylib
)
set(RESOURCES
    defaults.bin
    gamecontrollerdb.txt
    openmw.cfg
)

file(MAKE_DIRECTORY "${DEST}" "${ASSETS_DEST}")

# --- Stage dylibs (cp -L)
foreach(lib IN LISTS DYLIBS)
    set(src "${prefix}/lib/${lib}")
    if(NOT EXISTS "${src}")
        message(FATAL_ERROR "MISSING: ${src} (run the ios-libs build first)")
    endif()
    file(COPY "${src}" DESTINATION "${DEST}" FOLLOW_SYMLINK_CHAIN)
endforeach()

# --- Copy resources to OpenMWAssets
set(resources_src "${OPENMW_APP}/Contents/Resources")
foreach(res IN LISTS RESOURCES)
    if(EXISTS "${resources_src}/${res}")
        file(COPY "${resources_src}/${res}" DESTINATION "${ASSETS_DEST}" FOLLOW_SYMLINK_CHAIN)
        message(STATUS "Copied ${res} to OpenMWAssets")
    elseif(EXISTS "${resources_src}/${OPENMW_CONFIG}/${res}")
        file(COPY "${resources_src}/${OPENMW_CONFIG}/${res}" DESTINATION "${ASSETS_DEST}" FOLLOW_SYMLINK_CHAIN)
        message(STATUS "Copied ${OPENMW_CONFIG}/${res} to OpenMWAssets")
    else()
        message(WARNING "Resource ${res} not found in ${resources_src} (or ${OPENMW_CONFIG}/ subfolder)")
    endif()
endforeach()

# --- Default settings.cfg from buildscripts
if(EXISTS "${REPO_DIR}/buildscripts/settings.cfg")
    file(COPY "${REPO_DIR}/buildscripts/settings.cfg" DESTINATION "${ASSETS_DEST}")
    message(STATUS "Copied default settings.cfg to OpenMWAssets")
endif()

# --- Resources folder (always from Release)
if(IS_DIRECTORY "${resources_src}/Release/resources")
    message(STATUS "Copying resources folder from Release...")
    file(REMOVE_RECURSE "${ASSETS_DEST}/resources")
    file(COPY "${resources_src}/Release/resources" DESTINATION "${ASSETS_DEST}")
    message(STATUS "Copied resources folder to OpenMWAssets")
endif()

# --- Rewrite openmw.cfg paths (was three sed -i '')
if(EXISTS "${ASSETS_DEST}/openmw.cfg")
    file(READ "${ASSETS_DEST}/openmw.cfg" _cfg)
    string(REPLACE "\${OPENMW_RESOURCE_FILES}"          "resources"             _cfg "${_cfg}")
    string(REPLACE "resources=../Resources/resources"   "resources=resources"   _cfg "${_cfg}")
    string(REPLACE "data=../Resources/resources/vfs-mw" "data=resources/vfs-mw" _cfg "${_cfg}")
    file(WRITE "${ASSETS_DEST}/openmw.cfg" "${_cfg}")
endif()

# --- Normalise SDL dylib id so it matches libopenmw's load command
execute_process(
    COMMAND install_name_tool -id @rpath/libSDL2-2.0.0.dylib "${DEST}/libSDL2-2.0.0.dylib"
    RESULT_VARIABLE _rc)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "install_name_tool failed on ${DEST}/libSDL2-2.0.0.dylib")
endif()

# Ad-hoc codesign (matches `|| true` — failure tolerated)
execute_process(
    COMMAND codesign -f -s - "${DEST}/libSDL2-2.0.0.dylib"
    RESULT_VARIABLE _rc
    ERROR_QUIET)

# --- libopenmw.dylib (prefix first, then the app bundle's MacOS/<cfg>/)
set(_openmw_candidates
    "${prefix}/lib/libopenmw.dylib"
    "${OPENMW_APP}/Contents/MacOS/${OPENMW_CONFIG}/libopenmw.dylib"
    "${OPENMW_APP}/Contents/MacOS/Release/libopenmw.dylib"
    "${OPENMW_APP}/Contents/MacOS/Debug/libopenmw.dylib"
    "${OPENMW_APP}/Contents/MacOS/RelWithDebInfo/libopenmw.dylib"
    "${OPENMW_APP}/Contents/MacOS/libopenmw.dylib"
)
set(_openmw "")
foreach(c IN LISTS _openmw_candidates)
    if(EXISTS "${c}")
        set(_openmw "${c}")
        break()
    endif()
endforeach()
if(_openmw STREQUAL "")
    message(FATAL_ERROR "MISSING: libopenmw.dylib for ${PLATFORM} (build OpenMW first)")
endif()
file(COPY "${_openmw}" DESTINATION "${DEST}" FOLLOW_SYMLINK_CHAIN)

message(STATUS "Staged ${PLATFORM} -> ${DEST}")