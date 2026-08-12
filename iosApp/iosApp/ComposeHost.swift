import SwiftUI
import UIKit
import Foundation
import ComposeApp

/// A custom window that only intercepts touches that hit its subviews (the buttons/thumbstick).
class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view == self || view == rootViewController?.view {
            return nil
        }
        return view
    }
}

struct ComposeLauncherView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = MainViewControllerKt.MainViewController(onPlay: startEngine)
        return LauncherRootViewController(content: controller)
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        ComposeLauncherView()
            .ignoresSafeArea()
    }
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
        
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        content.view.frame = view.bounds
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return allowLandscape ? .landscape : .portrait
    }
}

/// A native Thumbstick that maps to WASD keys.
class VirtualThumbstick: UIView {
    private let baseView = UIView()
    private let stickView = UIView()
    private let radius: CGFloat = 60
    private var activeKeys = Set<Int32>()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setup() {
        backgroundColor = .clear
        
        baseView.frame = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        baseView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        baseView.layer.cornerRadius = radius
        baseView.layer.borderWidth = 2
        baseView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        addSubview(baseView)
        
        stickView.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        stickView.center = CGPoint(x: radius, y: radius)
        stickView.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        stickView.layer.cornerRadius = 25
        addSubview(stickView)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let centerX = radius
        let centerY = radius
        
        let dx = location.x - centerX
        let dy = location.y - centerY
        let distance = sqrt(dx*dx + dy*dy)
        
        let angle = atan2(dy, dx)
        let cappedDistance = min(distance, radius)
        
        let newX = centerX + cos(angle) * cappedDistance
        let newY = centerY + sin(angle) * cappedDistance
        stickView.center = CGPoint(x: newX, y: newY)
        
        updateWASD(dx: dx, dy: dy, distance: cappedDistance)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        stickView.center = CGPoint(x: radius, y: radius)
        resetKeys()
    }
    
    private func updateWASD(dx: CGFloat, dy: CGFloat, distance: CGFloat) {
        let deadzone: CGFloat = 15
        var currentKeys = Set<Int32>()
        
        if distance > deadzone {
            if dy < -deadzone { currentKeys.insert(26) } // W
            if dy > deadzone  { currentKeys.insert(22) } // S
            if dx < -deadzone { currentKeys.insert(4)  } // A
            if dx > deadzone  { currentKeys.insert(7)  } // D
        }
        
        // Release keys no longer active
        for key in activeKeys where !currentKeys.contains(key) {
            sendNativeKey(scancode: key, state: 0)
        }
        // Press new keys
        for key in currentKeys where !activeKeys.contains(key) {
            sendNativeKey(scancode: key, state: 1)
        }
        
        activeKeys = currentKeys
    }
    
    private func resetKeys() {
        for key in activeKeys {
            sendNativeKey(scancode: key, state: 0)
        }
        activeKeys.removeAll()
    }
}

class GameplayOverlayController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        // Thumbstick on the left
        let thumbstick = VirtualThumbstick()
        thumbstick.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thumbstick)
        
        // Buttons on the right
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            thumbstick.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            thumbstick.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            thumbstick.widthAnchor.constraint(equalToConstant: 120),
            thumbstick.heightAnchor.constraint(equalToConstant: 120),
            
            buttonStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        
        buttonStack.addArrangedSubview(createButton(title: "ESC", action: #selector(escTapped)))
        buttonStack.addArrangedSubview(createButton(title: "ENT", action: #selector(entTapped)))
    }
    
    private func createButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        btn.layer.cornerRadius = 25
        btn.widthAnchor.constraint(equalToConstant: 50).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
    
    @objc func escTapped() { sendNativeKey(scancode: 41, state: 1); sendNativeKey(scancode: 41, state: 0) }
    @objc func entTapped() { sendNativeKey(scancode: 40, state: 1); sendNativeKey(scancode: 40, state: 0) }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
}

private var overlayWindow: PassThroughWindow?

private func startEngine() {
    guard let game = OpenMWLauncher.scanForGameData() else {
        presentAlert(title: "No game files found", message: "...")
        return
    }
    
    LauncherRootViewController.shared?.allowLandscape = true
    
    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        let window = PassThroughWindow(windowScene: scene)
        window.rootViewController = GameplayOverlayController()
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.isOpaque = false
        window.makeKeyAndVisible()
        overlayWindow = window
        
        // Hide original window using modern API
        scene.windows.first { $0 != window }?.isHidden = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        do {
            try OpenMWLauncher.launch(game: game)
        } catch {
            presentAlert(title: "Could not start the game", message: error.localizedDescription)
        }
    }
}

private func sendNativeKey(scancode: Int32, state: Int32) {
    typealias SendKeyFn = @convention(c) (Int32, Int32) -> Void
    if let handle = dlopen(nil, RTLD_NOW),
       let sym = dlsym(handle, "SDL_SendVirtualKeyboardKey") {
        let sendKey = unsafeBitCast(sym, to: SendKeyFn.self)
        sendKey(state, scancode)
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
