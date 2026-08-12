import SwiftUI
import UIKit
import ComposeApp

struct ComposeLauncherView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = MainViewControllerKt.MainViewController(onPlay: startEngine)
        // Ensure Compose view is transparent
        controller.view.backgroundColor = .clear
        return LauncherRootViewController(content: controller)
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

class LauncherRootViewController: UIViewController {
    static var shared: LauncherRootViewController?
    var content: UIViewController
    var allowLandscape = false

    init(content: UIViewController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
        LauncherRootViewController.shared = self
        addChild(content)
        view.addSubview(content.view)
        content.didMove(toParent: self)
        
        // Ensure this container is transparent
        view.backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        content.view.frame = view.bounds
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return allowLandscape ? .landscape : .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return allowLandscape ? .landscapeRight : .portrait
    }
    
    func switchToLandscape() {
        allowLandscape = true
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            if let windowScene = view.window?.windowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}

struct ContentView: View {
    @State private var isPlaying = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // The Launcher (Compose)
            ComposeLauncherView()
                .ignoresSafeArea()
                .opacity(isPlaying ? 0 : 1)
                .allowsHitTesting(!isPlaying)

            // The Gameplay Overlay (Native SwiftUI)
            if isPlaying {
                HStack(spacing: 16) {
                    Button(action: {
                        sendNativeKey(scancode: 41) // SDL_SCANCODE_ESCAPE
                    }) {
                        Text("ESC")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        sendNativeKey(scancode: 40) // SDL_SCANCODE_RETURN
                    }) {
                        Text("ENT")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(24) // Position it away from the edge
                .ignoresSafeArea()
            }
        }
        .background(Color.clear) // Force ZStack to be clear
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartedEngine"))) { _ in
            self.isPlaying = true
        }
    }
}

private func startEngine() {
    guard let game = OpenMWLauncher.scanForGameData() else {
        presentAlert(title: "No game files found", message: "...")
        return
    }
    
    // 1. Force the UI to rotate to Landscape
    LauncherRootViewController.shared?.switchToLandscape()

    // 2. Elevate the window level and ensure it is transparent
    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        
        // Ensure root view is also clear
        window.rootViewController?.view.backgroundColor = .clear
    }
    
    // 3. Notify the UI to show the ESC button
    NotificationCenter.default.post(name: NSNotification.Name("StartedEngine"), object: nil)

    // 4. Wait for the rotation animation to finish (0.5s) BEFORE blocking
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        do {
            try OpenMWLauncher.launch(game: game)
        } catch {
            presentAlert(title: "Could not start the game", message: error.localizedDescription)
        }
    }
}

private func sendNativeKey(scancode: Int32) {
    typealias SendKeyFn = @convention(c) (Int32, Int32) -> Void
    if let handle = dlopen(nil, RTLD_NOW),
       let sym = dlsym(handle, "SDL_SendVirtualKeyboardKey") {
        let sendKey = unsafeBitCast(sym, to: SendKeyFn.self)
        sendKey(1, scancode) // SDL_PRESSED
        sendKey(0, scancode) // SDL_RELEASED
    }
}

private func presentAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController?.present(alert, animated: true)
}
