# install_gl4es.cmake
# Installs gl4es dylib and headers into destination prefix

file(MAKE_DIRECTORY "${DEST_DIR}/lib" "${DEST_DIR}/include/gl4es")

if(EXISTS "${SRC_DIR}/lib/Release/libGL.dylib")
    file(COPY "${SRC_DIR}/lib/Release/libGL.dylib" DESTINATION "${DEST_DIR}/lib")
elseif(EXISTS "${SRC_DIR}/lib/Debug/libGL.dylib")
    file(COPY "${SRC_DIR}/lib/Debug/libGL.dylib" DESTINATION "${DEST_DIR}/lib")
elseif(EXISTS "${SRC_DIR}/lib/libGL.dylib")
    file(COPY "${SRC_DIR}/lib/libGL.dylib" DESTINATION "${DEST_DIR}/lib")
endif()

if(EXISTS "${SRC_DIR}/include")
    file(COPY "${SRC_DIR}/include/" DESTINATION "${DEST_DIR}/include/gl4es/include")
    file(COPY "${SRC_DIR}/include/" DESTINATION "${DEST_DIR}/include")
endif()
