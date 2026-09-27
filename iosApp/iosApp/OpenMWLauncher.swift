import UIKit
import ComposeApp

class LogRedirector {
    static let shared = LogRedirector()
    private var timer: Timer?
    private var lastOffset: UInt64 = 0
    private var logURL: URL {
        OpenMWLauncher.userConfigURL.appendingPathComponent("openmw.log")
    }

    func start() {
        // Start watching the engine's internal log file
        timer?.invalidate()
        lastOffset = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkLogs()
        }
    }

    private func checkLogs() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: logURL.path) else { return }
        
        guard let attributes = try? fm.attributesOfItem(atPath: logURL.path),
              let size = attributes[.size] as? UInt64 else { return }

        if size < lastOffset { lastOffset = 0 } // Log was cleared or rotated
        guard size > lastOffset else { return }

        do {
            let handle = try FileHandle(forReadingFrom: logURL)
            try handle.seek(toOffset: lastOffset)
            let data = handle.readDataToEndOfFile()
            lastOffset = size
            
            if let str = String(data: data, encoding: .utf8) {
                let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                DispatchQueue.main.async {
                    PlayBridge.shared.addLogs(lines: lines)
                    NotificationCenter.default.post(name: NSNotification.Name("NewEngineLogs"), object: lines)
                }
            }
            try handle.close()
        } catch {
            print("LogRedirector error: \(error)")
        }
    }
}

/// Bridges the SwiftUI launcher to the OpenMW engine, which is built as
/// libopenmw.dylib (embedded in the app's Frameworks directory) exporting
/// a C `main`.
///
/// Filesystem layout at runtime:
///  - Bundle/OpenMWAssets            "local" config dir: base openmw.cfg,
///                                   defaults.bin, gamecontrollerdb.txt,
///                                   resources/ (vfs, shaders, lua_api, ...)
///  - Documents/Data Files           user-supplied Morrowind data (via Files app)
///  - Library/Preferences/openmw     generated user openmw.cfg (data + content)
///  - Library/Application Support/openmw   saves etc. (created by the engine)
enum OpenMWLauncher {

    struct GameData {
        let dataPath: URL
        let contentFiles: [String]
        let archives: [String]
    }

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var userConfigURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Preferences/openmw", isDirectory: true)
    }

    static var userResourcesURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Alpha3/resources", isDirectory: true)
    }

    static var assetsURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("OpenMWAssets", isDirectory: true)
    }

    /// Master files first, in canonical order, then everything else alphabetically.
    private static let masterOrder = ["morrowind.esm", "tribunal.esm", "bloodmoon.esm"]
    private static let contentExtensions: Set<String> = ["esm", "esp", "omwgame", "omwaddon", "omwscripts"]

    /// Looks for game data in Documents/"Data Files", falling back to
    /// Documents itself so users can drop .esm files at the top level.
    static func scanForGameData() -> GameData? {
        let fm = FileManager.default
        let candidates = [
            documentsURL.appendingPathComponent("Data Files", isDirectory: true),
            documentsURL,
        ]
        for dir in candidates {
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            let content = names.filter { contentExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            if !content.isEmpty {
                let archives = names.filter { ($0 as NSString).pathExtension.lowercased() == "bsa" }
                return GameData(dataPath: dir,
                                contentFiles: sortContent(content),
                                archives: sortArchives(archives))
            }
        }
        return nil
    }

    /// Same canonical ordering as content files: the base game's archive
    /// first so expansions and mods can override it.
    private static func sortArchives(_ files: [String]) -> [String] {
        let masterArchives = ["morrowind.bsa", "tribunal.bsa", "bloodmoon.bsa"]
        let masters = masterArchives.compactMap { canonical in
            files.first { $0.lowercased() == canonical }
        }
        let rest = files
            .filter { !masterArchives.contains($0.lowercased()) }
            .sorted { $0.lowercased() < $1.lowercased() }
        return masters + rest
    }

    private static func sortContent(_ files: [String]) -> [String] {
        let masters = masterOrder.compactMap { canonical in
            files.first { $0.lowercased() == canonical }
        }
        let rest = files
            .filter { !masterOrder.contains($0.lowercased()) }
            .sorted { $0.lowercased() < $1.lowercased() }
        return masters + rest
    }

    /// Writes Library/Preferences/openmw/openmw.cfg pointing the engine at the
    /// detected data directory and content files. The bundled base config
    /// (OpenMWAssets/openmw.cfg) chains to this directory via `config="?userconfig?"`.
    static func writeUserConfig(for game: GameData) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: userConfigURL, withIntermediateDirectories: true)

        var cfg = "# Generated by the OpenMW iOS launcher. Edits are overwritten on each launch.\n"
        // Priority 1: Patched resources (shaders, etc.) in writable storage
        cfg += "data=\"\(userResourcesURL.path)\"\n"
        // Priority 2: User game data (Morrowind.esm, etc.)
        cfg += "data=\"\(game.dataPath.path)\"\n"
        
        for archive in game.archives {
            cfg += "fallback-archive=\(archive)\n"
        }
        for file in game.contentFiles {
            cfg += "content=\(file)\n"
        }
        cfg += "encoding=win1252\n"
        // Bink video playback stalls on iOS (the player waits on an audio
        // clock that never advances), freezing the engine on the intro
        // logos. Point the logo entries at a nonexistent file: the video
        // widget logs "Failed to open video" and returns immediately.
        // (An empty fallback value is rejected by the config parser.)
        cfg += "fallback=Movies_Company_Logo,skipped_on_ios.bik\n"
        cfg += "fallback=Movies_Morrowind_Logo,skipped_on_ios.bik\n"
        try cfg.write(to: userConfigURL.appendingPathComponent("openmw.cfg"),
                      atomically: true, encoding: .utf8)

        // Seed user settings once (the engine owns this file afterwards):
        let settingsURL = userConfigURL.appendingPathComponent("settings.cfg")
        if !fm.fileExists(atPath: settingsURL.path) {
            // Priority: bundled default from assets
            if let bundleSettings = assetsURL?.appendingPathComponent("settings.cfg"),
               fm.fileExists(atPath: bundleSettings.path) {
                try? fm.copyItem(at: bundleSettings, to: settingsURL)
            } else {
                // Fallback hardcoded defaults
                let settings = """
                [Video]
                resolution x = 1280
                resolution y = 720
                [GUI]
                scaling factor = 0.7
                [Post Processing]
                enabled = false
                [Shadows]
                enabled = false
                """
                try settings.write(to: settingsURL, atomically: true, encoding: .utf8)
            }
        }
    }

    static func resetSettingsToDefault() {
        let fm = FileManager.default
        let settingsURL = userConfigURL.appendingPathComponent("settings.cfg")
        
        // Remove existing
        if fm.fileExists(atPath: settingsURL.path) {
            try? fm.removeItem(at: settingsURL)
        }
        
        // Copy from bundle if possible
        if let bundleSettings = assetsURL?.appendingPathComponent("settings.cfg"),
           fm.fileExists(atPath: bundleSettings.path) {
            try? fm.copyItem(at: bundleSettings, to: settingsURL)
        }
    }

    enum LaunchError: LocalizedError {
        case assetsMissing
        case dylibMissing
        case dlopenFailed(String)
        case mainMissing

        var errorDescription: String? {
            switch self {
            case .assetsMissing: return "OpenMWAssets folder is missing from the app bundle."
            case .dylibMissing: return "libopenmw framework is missing from the app's Frameworks."
            case .dlopenFailed(let msg): return "Could not load the engine: \(msg)"
            case .mainMissing: return "The engine library does not export main()."
            }
        }
    }

    /// gl4es resolves GLES symbols through this hook. It must be a C function
    /// pointer, so the driver handle lives in a global rather than a capture.
    private static var glesDriverHandle: UnsafeMutableRawPointer?

    /// Kept alive for the process lifetime: gl4es's hardware probe needs a
    /// current GL context, and SDL doesn't create one until the engine starts.
    private static var bootstrapGLContext: EAGLContext?

    /// Prepares the OpenGL ES driver and runs its one-time initialization so 
    /// per-context state exists before the engine's first GL call.
    private static func initializeGLES() throws {
        glesDriverHandle = dlopen("/System/Library/Frameworks/OpenGLES.framework/OpenGLES", RTLD_NOW)
        guard glesDriverHandle != nil else {
            throw LaunchError.dlopenFailed(String(cString: dlerror()))
        }

        // The hardware probe needs a current context — crash otherwise. 
        // Try GLES3 first.
        guard let context = EAGLContext(api: .openGLES3) ?? EAGLContext(api: .openGLES2) else {
            throw LaunchError.dlopenFailed("Could not create a bootstrap OpenGL ES context.")
        }
        bootstrapGLContext = context
        EAGLContext.setCurrent(context)

        print("--- OpenGL ES Info ---")
        if let vendor = glGetString(GLenum(GL_VENDOR)) {
            print("Vendor: \(String(cString: vendor))")
        }
        if let renderer = glGetString(GLenum(GL_RENDERER)) {
            print("Renderer: \(String(cString: renderer))")
        }
        if let version = glGetString(GLenum(GL_VERSION)) {
            print("Version: \(String(cString: version))")
        }
        
        var numExtensions: GLint = 0
        glGetIntegerv(GLenum(GL_NUM_EXTENSIONS), &numExtensions)
        print("Extensions (\(numExtensions)):")
        
        for i in 0..<numExtensions {
            if let name = glGetStringi(GLenum(GL_EXTENSIONS), GLuint(i)) {
                print("  \(String(cString: name))")
            }
        }
        print("-----------------------")
    }

    /// Loads libopenmw.dylib and calls its `main`. This call blocks and takes
    /// over the process (SDL creates its own window on top of the launcher),
    /// so it must run on the main thread and is effectively one-way.
    static func launch(game: GameData) throws -> Never {
        guard let assets = assetsURL,
              FileManager.default.fileExists(atPath: assets.appendingPathComponent("openmw.cfg").path)
        else { throw LaunchError.assetsMissing }

        try writeUserConfig(for: game)

        // The engine resolves its "local" (base) configuration from this
        // directory; see components/files/macospath.cpp.
        setenv("OPENMW_LOCAL_CONFIG_DIR", assets.path, 1)
        // OSG on iOS has no plugin bundles; silence plugin path lookups.
        setenv("OSG_LIBRARY_PATH", "", 1)
        setenv("OPENMW_GLES_VERSION", "30", 1)
        setenv("LIBGL_ES", "3", 1)
        setenv("OSG_GL_CONTEXT_VERSION", "3.0", 1)
        setenv("OSG_GLES3_AVAILABLE", "1", 1)
        setenv("OSG_VERTEX_BUFFER_HINT", "VBO", 1)
        setenv("OSG_TEXT_SHADER_TECHNIQUE", "ALL", 1)
        setenv("OPENMW_DECOMPRESS_TEXTURES", "1", 1)
        setenv("OPENMW_DEBUG_OPENGL", "1", 1)

        guard let fwPath = Bundle.main.privateFrameworksPath else { throw LaunchError.dylibMissing }

        try initializeGLES()

        let frameworkPath = fwPath + "/libopenmw.framework/libopenmw"
        let dylibPath = fwPath + "/libopenmw.dylib"
        
        let enginePath: String
        if FileManager.default.fileExists(atPath: frameworkPath) {
            enginePath = frameworkPath
        } else if FileManager.default.fileExists(atPath: dylibPath) {
            enginePath = dylibPath
        } else {
            throw LaunchError.dylibMissing
        }

        guard let handle = dlopen(enginePath, RTLD_NOW) else {
            throw LaunchError.dlopenFailed(String(cString: dlerror()))
        }
        guard let sym = dlsym(handle, "main") else { throw LaunchError.mainMissing }

        typealias MainFn = @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32
        let engineMain = unsafeBitCast(sym, to: MainFn.self)

        var argv: [UnsafeMutablePointer<CChar>?] = [strdup("openmw"), nil]
        let code = engineMain(1, &argv)
        // The engine returning means the game quit; there is no launcher UI
        // to return to in a meaningful state, so end the process cleanly.
        exit(code)
    }
}
