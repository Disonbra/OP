#!/bin/bash
# Build Zink using the MoltenVK we just built

set -e

echo "=== Building Zink with MoltenVK ==="

MESA_DIR="/Users/mac/Documents/mesa"
MOLTENVK_DIR="${MESA_DIR}/build-ios/MoltenVK"
INSTALL_DIR="${MESA_DIR}/zink-install"
BUILD_DIR="${MESA_DIR}/build-zink-final"

echo "Mesa dir: ${MESA_DIR}"
echo "MoltenVK dir: ${MOLTENVK_DIR}"
echo "Build dir: ${BUILD_DIR}"

# Verify MoltenVK exists
if [ ! -f "${MOLTENVK_DIR}/Package/Release/iOS/libMoltenVK.a" ]; then
    echo "ERROR: libMoltenVK.a not found!"
    echo "Looking in: ${MOLTENVK_DIR}/Package/Release/iOS/"
    ls -la "${MOLTENVK_DIR}/Package/Release/iOS/" || true
    exit 1
fi

echo "✓ Found MoltenVK at: ${MOLTENVK_DIR}/Package/Release/iOS/libMoltenVK.a"

# Clean and create directories
rm -rf "${BUILD_DIR}" "${INSTALL_DIR}"
mkdir -p "${BUILD_DIR}" "${INSTALL_DIR}"
cd "${BUILD_DIR}"

# Create cross file for iOS
cat > ios-cross.txt << 'EOF'
[binaries]
c = ['xcrun', '-sdk', 'iphoneos', 'clang']
cpp = ['xcrun', '-sdk', 'iphoneos', 'clang++']
objc = ['xcrun', '-sdk', 'iphoneos', 'clang']
objcpp = ['xcrun', '-sdk', 'iphoneos', 'clang++']
ar = 'ar'
strip = 'strip'
pkg-config = 'pkg-config'

[properties]
sys_root = '/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk'
c_args = ['-arch', 'arm64', '-miphoneos-version-min=17.0', '-DETIME=62']
cpp_args = ['-arch', 'arm64', '-miphoneos-version-min=17.0', '-DETIME=62']
c_link_args = ['-arch', 'arm64', '-miphoneos-version-min=17.0']
cpp_link_args = ['-arch', 'arm64', '-miphoneos-version-min=17.0']
needs_exe_wrapper = true

[host_machine]
system = 'darwin'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'
EOF

echo "=== Configuring Mesa ==="

# Configure Mesa with Zink driver
# We're using -Dvulkan-drivers=empty because we'll link MoltenVK manually
meson setup \
  --cross-file ios-cross.txt \
  -Dplatforms= \
  -Dgallium-drivers=zink \
  -Dvulkan-drivers= \
  -Dglx=disabled \
  -Degl=disabled \
  -Dgbm=disabled \
  -Dgles2=enabled \
  -Dgles1=enabled \
  -Dshared-glapi=enabled \
  -Dllvm=disabled \
  -Dshared-llvm=disabled \
  -Dbuildtype=release \
  -Dosmesa=false \
  -Dopengl=true \
  -Dglvnd=false \
  -Dgallium-vdpau=disabled \
  -Dgallium-va=disabled \
  -Dgallium-xa=disabled \
  -Dshader-cache=enabled \
  -Dprefix="${INSTALL_DIR}" \
  "${MESA_DIR}"

echo "=== Building... ==="
ninja
ninja install

echo "=== Creating iOS Framework with MoltenVK ==="

# Create framework directory
FRAMEWORK_DIR="${INSTALL_DIR}/Zink.framework"
mkdir -p "${FRAMEWORK_DIR}"

# Copy and merge libraries
echo "Copying libraries..."

# Find the main Mesa library
MESA_LIB=$(find "${INSTALL_DIR}/lib" -name "*.dylib" -o -name "*.a" | head -1)
if [ -z "$MESA_LIB" ]; then
    echo "ERROR: No Mesa library found in ${INSTALL_DIR}/lib/"
    ls -la "${INSTALL_DIR}/lib/"
    exit 1
fi

echo "Found Mesa library: ${MESA_LIB}"

# Create universal library with MoltenVK
echo "Creating universal library..."
LIB_NAME="libZink.dylib"
lipo -create \
  "${MESA_LIB}" \
  "${MOLTENVK_DIR}/Package/Release/iOS/libMoltenVK.a" \
  -output "${FRAMEWORK_DIR}/Zink"

# Copy headers
echo "Copying headers..."
mkdir -p "${FRAMEWORK_DIR}/Headers"
cp -r "${INSTALL_DIR}/include/GL" "${FRAMEWORK_DIR}/Headers/" 2>/dev/null || true
cp -r "${INSTALL_DIR}/include/GLES" "${FRAMEWORK_DIR}/Headers/" 2>/dev/null || true
cp -r "${INSTALL_DIR}/include/KHR" "${FRAMEWORK_DIR}/Headers/" 2>/dev/null || true

# Copy MoltenVK headers
cp -r "${MOLTENVK_DIR}/MoltenVK/include/"* "${FRAMEWORK_DIR}/Headers/" 2>/dev/null || true

# Create Info.plist
echo "Creating Info.plist..."
cat > "${FRAMEWORK_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Zink</string>
    <key>CFBundleIdentifier</key>
    <string>org.mesa.zink</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Zink</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>12.0</string>
</dict>
</plist>
EOF

echo "=== Build Complete! ==="
echo ""
echo "Framework created at: ${FRAMEWORK_DIR}"
echo ""
echo "To use in Xcode:"
echo "1. Add ${FRAMEWORK_DIR} to your Xcode project"
echo "2. Link these frameworks:"
echo "   - Metal.framework"
echo "   - Foundation.framework"
echo "   - UIKit.framework"
echo "   - QuartzCore.framework"
echo "   - CoreGraphics.framework"
echo "   - IOSurface.framework"
echo ""
echo "Test with:"
echo "otool -l ${FRAMEWORK_DIR}/Zink | grep -A5 LC_VERSION_MIN_IPHONEOS"