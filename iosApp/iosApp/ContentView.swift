import SwiftUI

/// The original SwiftUI launcher, kept as a fallback while the Compose
/// Multiplatform launcher (ComposeHost.swift) becomes the primary UI.
/// To use it, swap ContentView for LegacyLauncherView in iOSApp.swift.
struct LegacyLauncherView: View {
    @State private var gameData: OpenMWLauncher.GameData?
    @State private var launchError: String?
    @State private var isLaunching = false
    @State private var showLogs = false

    private var hasMorrowind: Bool {
        gameData?.contentFiles.contains { $0.lowercased() == "morrowind.esm" } ?? false
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                HStack {
                    Spacer()
                    Button(action: { showLogs.toggle() }) {
                        Label("Logs", systemImage: "terminal")
                            .font(.caption.bold())
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.trailing)
                    .foregroundColor(.white)
                }

                Text("OpenMW")
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text("Morrowind engine for iOS")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer()

                if let game = gameData {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Game files found", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                        Text(game.dataPath.lastPathComponent)
                            .font(.caption.monospaced())
                            .foregroundColor(.gray)
                        ForEach(game.contentFiles, id: \.self) { file in
                            Text(file)
                                .font(.caption.monospaced())
                                .foregroundColor(.white.opacity(0.8))
                        }
                        if !hasMorrowind {
                            Text("Morrowind.esm not found — the game may not start.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("No game files found", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.headline)
                        Text("Copy your Morrowind “Data Files” folder into this app:")
                            .foregroundColor(.white.opacity(0.9))
                        Text("1. Open the Files app (or Finder on your Mac with the device connected)\n2. Browse to “On My iPhone” → “\(Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "OpenMW")”\n3. Copy the entire “Data Files” folder from your Morrowind installation there")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                if let error = launchError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()

                Button(action: play) {
                    Label(isLaunching ? "Launching…" : "Play",
                          systemImage: isLaunching ? "hourglass" : "play.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(gameData != nil ? Color.accentColor : Color.gray.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 14))
                .foregroundColor(.white)
                .disabled(gameData == nil || isLaunching)
                .padding(.horizontal)

                Button("Rescan for game files", action: rescan)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }
        }
        .onAppear(perform: rescan)
        .engineLogOverlay(isPresented: $showLogs)
    }

    private func rescan() {
        gameData = OpenMWLauncher.scanForGameData()
        launchError = nil
    }

    private func play() {
        guard let game = gameData else { return }
        isLaunching = true
        launchError = nil
        // Give SwiftUI one frame to render the launching state before the
        // engine takes over the main thread for good.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                try OpenMWLauncher.launch(game: game)
            } catch {
                launchError = error.localizedDescription
                isLaunching = false
            }
        }
    }
}
