import SwiftUI
import UIKit
import ComposeApp

/// Hosts the Compose Multiplatform launcher (composeApp/) and hands it the
/// native engine-start action — the iOS equivalent of the Android
/// launcher's System.loadLibrary glue.
struct ComposeLauncherView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        MainViewControllerKt.MainViewController(onPlay: startEngine)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        ComposeLauncherView()
            .ignoresSafeArea()
    }
}

private func startEngine() {
    guard let game = OpenMWLauncher.scanForGameData() else {
        presentAlert(title: "No game files found",
                     message: "Copy your Morrowind “Data Files” folder into this app with the Files app, then try again.")
        return
    }
    // Give Compose a beat to finish the tap animation before the engine
    // takes over the main thread for good.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        do {
            try OpenMWLauncher.launch(game: game)
        } catch {
            presentAlert(title: "Could not start the game",
                         message: error.localizedDescription)
        }
    }
}

private func presentAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController?
        .present(alert, animated: true)
}
