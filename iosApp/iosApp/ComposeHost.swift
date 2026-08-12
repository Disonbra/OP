import SwiftUI
import UIKit
import Foundation
import ComposeApp

/// A custom window that only intercepts touches that hit its subviews (the buttons/thumbstick).
class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        // If we hit the window itself or the root controller's view, return nil to pass through.
        if hitView == self || hitView == rootViewController?.view {
            return nil
        }
        return hitView
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
        ComposeLauncherView().ignoresSafeArea()
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

/// A native Thumbstick that maps to WASD keys and allows itself to be dragged.
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
        stickView.isUserInteractionEnabled = false
        addSubview(stickView)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        addGestureRecognizer(longPress)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let superview = superview else { return }
        if gesture.state == .began {
            UIView.animate(withDuration: 0.2) {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.alpha = 0.8
            }
        } else if gesture.state == .changed {
            self.center = gesture.location(in: superview)
        } else if gesture.state == .ended || gesture.state == .cancelled {
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
                self.alpha = 1.0
            }
            UserDefaults.standard.set(NSCoder.string(for: self.center), forKey: "OverlayThumbstickCenter_v4")
        }
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
        stickView.center = CGPoint(x: centerX + cos(angle) * cappedDistance, y: centerY + sin(angle) * cappedDistance)
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
        for key in activeKeys where !currentKeys.contains(key) { sendNativeKey(scancode: key, state: 0) }
        for key in currentKeys where !activeKeys.contains(key) { sendNativeKey(scancode: key, state: 1) }
        activeKeys = currentKeys
    }
    
    private func resetKeys() {
        for key in activeKeys { sendNativeKey(scancode: key, state: 0) }
        activeKeys.removeAll()
    }
}

class GameplayOverlayController: UIViewController {
    var thumbstick: VirtualThumbstick!
    var escBtn: UIButton!
    var entBtn: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        // Initial setup
        thumbstick = VirtualThumbstick(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        view.addSubview(thumbstick)
        
        escBtn = createDraggableButton(title: "ESC", action: #selector(escTapped), key: "OverlayEsc_v4")
        view.addSubview(escBtn)
        
        entBtn = createDraggableButton(title: "ENT", action: #selector(entTapped), key: "OverlayEnt_v4")
        view.addSubview(entBtn)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let screen = view.bounds
        guard screen.width > screen.height else { return } // Wait for landscape

        // Restore positions in landscape
        if let saved = UserDefaults.standard.string(forKey: "OverlayThumbstickCenter_v4") {
            thumbstick.center = NSCoder.cgPoint(for: saved)
        } else {
            thumbstick.center = CGPoint(x: 80, y: screen.height - 80)
        }
        
        if let saved = UserDefaults.standard.string(forKey: "OverlayEsc_v4Center") {
            escBtn.center = NSCoder.cgPoint(for: saved)
        } else {
            escBtn.center = CGPoint(x: screen.width - 120, y: screen.height - 60)
        }
        
        if let saved = UserDefaults.standard.string(forKey: "OverlayEnt_v4Center") {
            entBtn.center = NSCoder.cgPoint(for: saved)
        } else {
            entBtn.center = CGPoint(x: screen.width - 50, y: screen.height - 60)
        }
    }
    
    private func createDraggableButton(title: String, action: Selector, key: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        btn.layer.cornerRadius = 25
        btn.addTarget(self, action: action, for: .touchUpInside)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleButtonPan(_:)))
        btn.addGestureRecognizer(pan)
        btn.accessibilityIdentifier = key
        return btn
    }
    
    @objc func handleButtonPan(_ gesture: UIPanGestureRecognizer) {
        guard let btn = gesture.view else { return }
        let translation = gesture.translation(in: view)
        btn.center = CGPoint(x: btn.center.x + translation.x, y: btn.center.y + translation.y)
        gesture.setTranslation(.zero, in: view)
        
        if gesture.state == .ended, let key = btn.accessibilityIdentifier {
            UserDefaults.standard.set(NSCoder.string(for: btn.center), forKey: "\(key)Center")
        }
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
    
    // 1. Trigger rotation on the main controller
    LauncherRootViewController.shared?.switchToLandscape()
    
    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        let window = PassThroughWindow(windowScene: scene)
        window.rootViewController = GameplayOverlayController()
        window.windowLevel = UIWindow.Level.statusBar + 1
        window.backgroundColor = .clear
        window.isOpaque = false
        window.makeKeyAndVisible()
        overlayWindow = window
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
    UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController?.present(alert, animated: true)
}
