# patch_collada.cmake
# Applies source fixes to collada-dom for modern C++ and Boost versions.

if(EXISTS "${COLLADA_DIR}/dom/include/dae.h")
    file(READ "${COLLADA_DIR}/dom/include/dae.h" CONTENT)
    string(REPLACE "#include <boost/filesystem/convenience.hpp>" "#include <boost/filesystem.hpp>" CONTENT "${CONTENT}")
    file(WRITE "${COLLADA_DIR}/dom/include/dae.h" "${CONTENT}")
endif()

if(EXISTS "${COLLADA_DIR}/dom/src/dae/daeUtils.cpp")
    file(READ "${COLLADA_DIR}/dom/src/dae/daeUtils.cpp" CONTENT)
    string(REPLACE "#include <boost/filesystem/convenience.hpp>" "#include <boost/filesystem.hpp>" CONTENT "${CONTENT}")
    string(REPLACE "archivePath.branch_path().string()" "archivePath.parent_path().string()" CONTENT "${CONTENT}")
    file(WRITE "${COLLADA_DIR}/dom/src/dae/daeUtils.cpp" "${CONTENT}")
endif()

if(EXISTS "${COLLADA_DIR}/CMakeLists.txt")
    file(READ "${COLLADA_DIR}/CMakeLists.txt" CONTENT)
    string(REPLACE "pkg_check_modules(liburiparser liburiparser)" "# pkg_check_modules(liburiparser liburiparser)" CONTENT "${CONTENT}")
    file(WRITE "${COLLADA_DIR}/CMakeLists.txt" "${CONTENT}")
endif()
