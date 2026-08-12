import SwiftUI
import UIKit
import Foundation
import ComposeApp

/// A custom window that only intercepts touches that hit its subviews.
class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        
        // If we hit the window background or the root controller's view, we might want to pass through.
        if hitView == self || hitView == rootViewController?.view {
            
            // Check for Custom Config Panel (tag 999)
            if let root = rootViewController, let _ = root.view.viewWithTag(999) {
                return hitView // Catch the touch for the panel
            }
            
            // Check for Delete Confirmation Panel (tag 888)
            if let root = rootViewController, let _ = root.view.viewWithTag(888) {
                return hitView // Catch the touch for the confirmation box
            }
            
            // Check for System Alerts
            if let root = rootViewController, root.presentedViewController != nil {
                return hitView // Catch for Alerts
            }
            
            return nil // Pass through to Morrowind
        }
        
        return hitView // Normal interaction for buttons and sticks
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

class VirtualThumbstick: UIView {
    private let baseView = UIView()
    private let stickView = UIView()
    private let radius: CGFloat = 60
    private var activeKeys = Set<Int32>()
    var isLocked = true
    
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
        if isLocked { return }
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
            UserDefaults.standard.set(NSCoder.string(for: self.center), forKey: "OverlayThumbstickCenter_v7")
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
    var customButtons: [UIButton] = []
    var isEditMode = false
    let lockBtn = UIButton(type: .system)
    private var layoutDone = false

    let availableButtons: [(name: String, code: Int32)] = [
        ("ESC", 41), ("ENT", 40), ("TAB", 43), ("SPC", 44),
        ("JUMP", 8), ("JOURN", 13), ("WAIT", 23), ("MAP", 16),
        ("WEAP", 9), ("MAG", 21), ("RUN", 225), ("SNK", 224),
        ("QSAVE", 62), ("QLOAD", 66), ("INV", 12),
        ("F1", 58), ("F2", 59), ("F3", 60), ("F4", 61), ("F5", 62), ("F6", 63),
        ("F7", 64), ("F8", 65), ("F9", 66), ("F10", 67), ("F11", 68), ("F12", 69),
        ("1", 30), ("2", 31), ("3", 32), ("4", 33)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        thumbstick = VirtualThumbstick(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        view.addSubview(thumbstick)
        
        let addBtn = UIButton(type: .system)
        addBtn.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addBtn.tintColor = .white
        addBtn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        addBtn.layer.cornerRadius = 20
        addBtn.frame = CGRect(x: 24, y: 24, width: 40, height: 40)
        addBtn.addTarget(self, action: #selector(showAddButtonPanel), for: .touchUpInside)
        view.addSubview(addBtn)
        
        lockBtn.setImage(UIImage(systemName: "lock.fill"), for: .normal)
        lockBtn.tintColor = .white
        lockBtn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        lockBtn.layer.cornerRadius = 20
        lockBtn.frame = CGRect(x: 74, y: 24, width: 40, height: 40)
        lockBtn.addTarget(self, action: #selector(toggleEditMode), for: .touchUpInside)
        view.addSubview(lockBtn)
        
        loadAllCustomButtons()
    }

    @objc func toggleEditMode() {
        isEditMode.toggle()
        lockBtn.setImage(UIImage(systemName: isEditMode ? "lock.open.fill" : "lock.fill"), for: .normal)
        lockBtn.tintColor = isEditMode ? .systemYellow : .white
        thumbstick.isLocked = !isEditMode
        for btn in customButtons {
            if let recognizers = btn.gestureRecognizers {
                for r in recognizers { r.isEnabled = isEditMode }
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let screen = view.bounds
        guard screen.width > screen.height else { return }
        if !layoutDone && screen.width > 200 {
            layoutDone = true
            if let saved = UserDefaults.standard.string(forKey: "OverlayThumbstickCenter_v7") {
                thumbstick.center = NSCoder.cgPoint(for: saved)
            } else {
                thumbstick.center = CGPoint(x: 80, y: screen.height - 80)
            }
            if customButtons.isEmpty && UserDefaults.standard.array(forKey: "CustomButtonsList_v7") == nil {
                createAndAddButton(name: "ESC", scancode: 41, at: CGPoint(x: screen.width - 120, y: screen.height - 60))
                createAndAddButton(name: "ENT", scancode: 40, at: CGPoint(x: screen.width - 50, y: screen.height - 60))
            }
        }
    }
    
    @objc func showAddButtonPanel() {
        if view.viewWithTag(999) != nil { return }
        
        let panelW: CGFloat = 400
        let panelH: CGFloat = 250
        let panel = UIView(frame: CGRect(x: 0, y: 0, width: panelW, height: panelH))
        panel.center = view.center
        panel.backgroundColor = UIColor(white: 0.1, alpha: 0.98)
        panel.layer.cornerRadius = 16
        panel.layer.borderWidth = 1
        panel.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        panel.tag = 999
        
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 12, width: panelW, height: 24))
        titleLabel.text = "Tap to Add Button"; titleLabel.textAlignment = .center; titleLabel.textColor = .white; titleLabel.font = .boldSystemFont(ofSize: 18)
        panel.addSubview(titleLabel)
        
        let scroll = UIScrollView(frame: CGRect(x: 15, y: 45, width: panelW - 30, height: panelH - 100))
        panel.addSubview(scroll)
        
        let btnW: CGFloat = 85
        let btnH: CGFloat = 40
        let gap: CGFloat = 8
        let cols = 4
        
        for (i, data) in availableButtons.enumerated() {
            let row = i / cols
            let col = i % cols
            let b = UIButton(type: .system)
            b.frame = CGRect(x: CGFloat(col) * (btnW + gap), y: CGFloat(row) * (btnH + gap), width: btnW, height: btnH)
            b.setTitle(data.name, for: .normal)
            b.setTitleColor(.white, for: .normal)
            b.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            b.layer.cornerRadius = 8
            b.tag = Int(data.code)
            b.addTarget(self, action: #selector(buttonSelectedFromGrid(_:)), for: .touchUpInside)
            scroll.addSubview(b)
            scroll.contentSize = CGSize(width: scroll.frame.width, height: b.frame.maxY + gap)
        }
        
        let cancelBtn = UIButton(type: .system); cancelBtn.frame = CGRect(x: panelW/2 - 50, y: panelH - 45, width: 100, height: 35); cancelBtn.setTitle("Cancel", for: .normal); cancelBtn.setTitleColor(.white, for: .normal); cancelBtn.backgroundColor = .systemRed.withAlphaComponent(0.6); cancelBtn.layer.cornerRadius = 8
        cancelBtn.addTarget(self, action: #selector(hideConfigPanels), for: .touchUpInside); panel.addSubview(cancelBtn)
        
        view.addSubview(panel)
    }
    
    @objc func buttonSelectedFromGrid(_ sender: UIButton) {
        guard let name = sender.title(for: .normal) else { return }
        createAndAddButton(name: name, scancode: Int32(sender.tag), at: view.center)
        saveAllCustomButtons()
        hideConfigPanels()
    }
    
    @objc func hideConfigPanels() {
        view.viewWithTag(999)?.removeFromSuperview()
        view.viewWithTag(888)?.removeFromSuperview()
    }
    
    private func createAndAddButton(name: String, scancode: Int32, at position: CGPoint) {
        let btn = UIButton(type: .system)
        btn.frame = CGRect(x: 0, y: 0, width: 70, height: 50); btn.center = position; btn.setTitle(name, for: .normal); btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold); btn.setTitleColor(.white, for: .normal); btn.backgroundColor = UIColor.black.withAlphaComponent(0.5); btn.layer.cornerRadius = 10; btn.tag = Int(scancode)
        btn.addTarget(self, action: #selector(customButtonDown(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(customButtonUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleButtonPan(_:)))
        pan.isEnabled = isEditMode
        btn.addGestureRecognizer(pan)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleButtonLongPress(_:)))
        longPress.isEnabled = isEditMode
        btn.addGestureRecognizer(longPress)
        
        view.addSubview(btn); customButtons.append(btn)
    }

    @objc func customButtonDown(_ sender: UIButton) {
        if isEditMode { return }
        sendNativeKey(scancode: Int32(sender.tag), state: 1)
    }
    @objc func customButtonUp(_ sender: UIButton) {
        if isEditMode { return }
        sendNativeKey(scancode: Int32(sender.tag), state: 0)
    }
    
    @objc func handleButtonPan(_ gesture: UIPanGestureRecognizer) {
        if !isEditMode { return }
        guard let btn = gesture.view else { return }
        let translation = gesture.translation(in: view)
        btn.center = CGPoint(x: btn.center.x + translation.x, y: btn.center.y + translation.y)
        gesture.setTranslation(.zero, in: view)
        if gesture.state == .ended { saveAllCustomButtons() }
    }

    @objc func handleButtonLongPress(_ gesture: UILongPressGestureRecognizer) {
        if !isEditMode || gesture.state != .began { return }
        guard let btn = gesture.view as? UIButton else { return }
        
        // Use a Custom Confirmation Panel (Tag 888) instead of a finicky UIAlertController
        let panel = UIView(frame: CGRect(x: 0, y: 0, width: 240, height: 120))
        panel.center = view.center
        panel.backgroundColor = UIColor(white: 0.1, alpha: 0.98)
        panel.layer.cornerRadius = 16
        panel.layer.borderWidth = 1
        panel.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.4).cgColor
        panel.tag = 888
        
        let label = UILabel(frame: CGRect(x: 10, y: 15, width: 220, height: 40))
        label.text = "Delete '\(btn.title(for: .normal) ?? "")'?"
        label.textColor = .white; label.textAlignment = .center; label.font = .boldSystemFont(ofSize: 16); label.numberOfLines = 2
        panel.addSubview(label)
        
        let cancelBtn = UIButton(type: .system); cancelBtn.frame = CGRect(x: 15, y: 70, width: 100, height: 35)
        cancelBtn.setTitle("Cancel", for: .normal); cancelBtn.setTitleColor(.white, for: .normal); cancelBtn.backgroundColor = .gray.withAlphaComponent(0.6); cancelBtn.layer.cornerRadius = 8
        cancelBtn.addTarget(self, action: #selector(hideConfigPanels), for: .touchUpInside); panel.addSubview(cancelBtn)
        
        let delBtn = UIButton(type: .system); delBtn.frame = CGRect(x: 125, y: 70, width: 100, height: 35)
        delBtn.setTitle("Delete", for: .normal); delBtn.setTitleColor(.white, for: .normal); delBtn.backgroundColor = .systemRed.withAlphaComponent(0.8); delBtn.layer.cornerRadius = 8
        
        // Pass the button to be deleted as a reference via a closure or helper
        delBtn.addTarget(self, action: #selector(hideConfigPanels), for: .touchUpInside)
        delBtn.addAction(UIAction { [weak self, weak btn] _ in
            btn?.removeFromSuperview()
            if let b = btn { self?.customButtons.removeAll { $0 == b } }
            self?.saveAllCustomButtons()
        }, for: .touchUpInside)
        
        panel.addSubview(delBtn)
        view.addSubview(panel)
    }

    private func saveAllCustomButtons() {
        let dataList = customButtons.map { btn -> [String: Any] in
            return ["name": btn.title(for: .normal) ?? "", "scancode": btn.tag, "center": NSCoder.string(for: btn.center)]
        }
        UserDefaults.standard.set(dataList, forKey: "CustomButtonsList_v7")
    }
    private func loadAllCustomButtons() {
        guard let savedList = UserDefaults.standard.array(forKey: "CustomButtonsList_v7") as? [[String: Any]] else { return }
        for item in savedList {
            if let name = item["name"] as? String, let scancode = item["scancode"] as? Int, let centerStr = item["center"] as? String {
                createAndAddButton(name: name, scancode: Int32(scancode), at: NSCoder.cgPoint(for: centerStr))
            }
        }
    }
}

private var overlayWindow: PassThroughWindow?

private func startEngine() {
    guard let game = OpenMWLauncher.scanForGameData() else {
        presentAlert(title: "No game files found", message: "...")
        return
    }
    LauncherRootViewController.shared?.switchToLandscape()
    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        let window = PassThroughWindow(windowScene: scene)
        window.rootViewController = GameplayOverlayController()
        window.windowLevel = UIWindow.Level.statusBar + 1
        window.backgroundColor = .clear; window.isOpaque = false; window.makeKeyAndVisible()
        overlayWindow = window
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        do { try OpenMWLauncher.launch(game: game) }
        catch { presentAlert(title: "Could not start the game", message: error.localizedDescription) }
    }
}

private func sendNativeKey(scancode: Int32, state: Int32) {
    typealias SendKeyFn = @convention(c) (Int32, Int32) -> Void
    if let handle = dlopen(nil, RTLD_NOW), let sym = dlsym(handle, "SDL_SendVirtualKeyboardKey") {
        let sendKey = unsafeBitCast(sym, to: SendKeyFn.self)
        sendKey(state, scancode)
    }
}

private func presentAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController?.present(alert, animated: true)
}
