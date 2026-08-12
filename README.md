# OpenMW for iOS

[Buy me a coffee.](https://ko-fi.com/jareddavenport)

[OpenMW](https://openmw.org) (the open-source Morrowind engine, 0.51.0) running
natively on iPhone and the iOS Simulator.

**Current state: playable alpha.** Main menu, character creation (with a
custom on-screen keyboard), and in-game rendering all work on a real device
and in the simulator. You supply your own Morrowind data files.

## How it works

- The engine and its dependency stack are built by `buildscripts/build_ios.sh`
  into `ios_build/` (device `OS64` and simulator `SIMULATORARM64` prefixes).
- OpenGL 2.1 is translated to OpenGL ES 2 by
  [gl4es](https://github.com/khanhduytran0/gl4es), running directly on Apple's
  deprecated-but-present OpenGLES framework. No MetalANGLE.
- OpenMW is built as `libopenmw.dylib` exporting a C `main`; a small SwiftUI
  launcher (`iosApp/`) scans `Documents/Data Files` (populated via the Files
  app / Finder file sharing), writes the user `openmw.cfg`, dlopens the engine
  and calls `main`.
- SDL is patched (`buildscripts/patches/sdl2_ios_scene.patch`) for modern iOS:
  UIScene window attachment, a `presentRenderbuffer` rebind (without which the
  screen freezes on stale content the moment the engine touches
  renderbuffers), and a custom overlay keyboard — iOS 26 refuses to sustain a
  text-input session for SDL's hidden-textfield trick, so SDL draws its own
  keys and injects text events directly.

## Building

1. Build the dependency stack (downloads, patches, and builds everything;
   progress markers in `ios_build/ios-libs/markers` make it resumable):

   ```
   ./buildscripts/build_ios.sh
   ```

2. Stage the engine dylibs into the app:

   ```
   ./buildscripts/stage_app_libs.sh        # or: device | sim
   ```

3. Open `iosApp/iosApp.xcodeproj` in Xcode, set your development team, and
   run — on a device or a simulator. A build phase picks the right dylib set
   (`EmbeddedLibsDevice/` vs `EmbeddedLibsSim/`) per destination.

4. Copy your Morrowind `Data Files` folder into the app via the Files app
   (device) or `xcrun simctl get_app_container ... data` (simulator), then
   hit Play.

## Known issues / next steps

- No touch-control overlay for gameplay yet (movement/camera) — the next big
  item; the plan is a native overlay injecting SDL events, mirroring the
  Android port's design.
- Bink video playback stalls the engine (the video player waits on an audio
  clock that never advances), so the intro logos are skipped via config.
  In-game cutscenes would hit the same stall.
- Post-processing is seeded disabled in `settings.cfg`; untested since the
  framebuffer chain was fixed.
- Backgrounding the app mid-game spams GPU-permission errors and eventually
  gets the process killed; graceful pause/resume is unimplemented.

## Credits

Based on [Duron27's openmw_ios](https://gitlab.com/duron27/openmw_ios)
dependency stack and launcher groundwork, and on the wider OpenMW-on-mobile
work (gl4es by ptitSeb/khanhduytran0, the OpenMW Android port lineage).
