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
        stickView.isUserInteractionEnabled = false // Let parent handle touches
        addSubview(stickView)
        
        // Add pan gesture for draggability (use 2 fingers or long press if you want to distinguish from stick movement)
        // For now, let's try a simple pan that only works if you start dragging from the outer ring.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleMove(_:)))
        pan.minimumNumberOfTouches = 1
        // We'll use a delegate to allow it to coexist with touchesMoved if needed, 
        // but for now, let's keep it simple: 
        // A Long Press triggers draggability to avoid fighting with character movement.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        addGestureRecognizer(longPress)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            UIView.animate(withDuration: 0.2) {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.alpha = 0.8
            }
        } else if gesture.state == .changed {
            let location = gesture.location(in: superview)
            self.center = location
        } else if gesture.state == .ended || gesture.state == .cancelled {
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
                self.alpha = 1.0
            }
        }
    }
    
    @objc private func handleMove(_ gesture: UIPanGestureRecognizer) {
        // Optional: dedicated drag handle
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
        
        for key in activeKeys where !currentKeys.contains(key) {
            sendNativeKey(scancode: key, state: 0)
        }
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
        
        // Setup Thumbstick
        let thumbstick = VirtualThumbstick()
        thumbstick.frame = CGRect(x: 40, y: view.bounds.height - 160, width: 120, height: 120)
        thumbstick.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
        view.addSubview(thumbstick)
        
        // Setup Buttons (individual views to allow independent dragging)
        let escBtn = createDraggableButton(title: "ESC", action: #selector(escTapped))
        escBtn.center = CGPoint(x: view.bounds.width - 100, y: view.bounds.height - 60)
        view.addSubview(escBtn)
        
        let entBtn = createDraggableButton(title: "ENT", action: #selector(entTapped))
        entBtn.center = CGPoint(x: view.bounds.width - 40, y: view.bounds.height - 60)
        view.addSubview(entBtn)
    }
    
    private func createDraggableButton(title: String, action: Selector) -> UIButton {
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
        
        btn.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        
        return btn
    }
    
    @objc func handleButtonPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        if let btn = gesture.view {
            btn.center = CGPoint(x: btn.center.x + translation.x, y: btn.center.y + translation.y)
        }
        gesture.setTranslation(.zero, in: view)
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
    UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController?.present(alert, animated: true)
}
