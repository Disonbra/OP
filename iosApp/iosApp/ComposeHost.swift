import SwiftUI
import UIKit
import Foundation
import ComposeApp

/// A custom window that only intercepts touches that hit its subviews.
class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if rootViewController?.presentedViewController != nil { return hitView }
        if hitView == self || hitView == rootViewController?.view {
            if let root = rootViewController {
                if root.view.viewWithTag(999) != nil || 
                   root.view.viewWithTag(888) != nil || 
                   root.view.viewWithTag(777) != nil { 
                    return hitView 
                }
            }
            return nil
        }
        return hitView
    }
}

struct ComposeLauncherView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        LogRedirector.shared.start()
        print("Launcher: Log redirection started")
        let controller = MainViewControllerKt.MainViewController(
            onPlay: startEngine,
            onResetSettings: { OpenMWLauncher.resetSettingsToDefault() }
        )
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
    enum Mode {
        case joystick
        case mouse
    }
    
    private let mode: Mode
    private let baseView = UIView()
    private let stickView = UIView()
    private let radius: CGFloat = 60
    var isLocked = true
    
    init(frame: CGRect, mode: Mode = .joystick) {
        self.mode = mode
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
            let key = mode == .joystick ? "OverlayThumbstickCenter_v7" : "OverlayRightStickCenter_v7"
            UserDefaults.standard.set(NSCoder.string(for: self.center), forKey: key)
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
        
        if mode == .joystick {
            updateJoystick(dx: dx, dy: dy, distance: cappedDistance)
        } else {
            // Mouse look relative motion
            let sensitivity: CGFloat = 0.4
            sendNativeMouseMotion(x: Int32(dx * sensitivity), y: Int32(dy * sensitivity))
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        stickView.center = CGPoint(x: radius, y: radius)
        if mode == .joystick {
            resetJoystick()
        }
    }
    
    private func updateJoystick(dx: CGFloat, dy: CGFloat, distance: CGFloat) {
        let deadzone: CGFloat = 5
        if distance < deadzone {
            resetJoystick()
            return
        }
        let normX = max(-1.0, min(1.0, dx / radius))
        let normY = max(-1.0, min(1.0, dy / radius))
        NativeJoystick.shared.setAxis(0, value: Int16(normX * 32767))
        NativeJoystick.shared.setAxis(1, value: Int16(normY * 32767))
    }
    
    private func resetJoystick() {
        NativeJoystick.shared.setAxis(0, value: 0)
        NativeJoystick.shared.setAxis(1, value: 0)
    }
}

class GameplayOverlayController: UIViewController {
    static var shared: GameplayOverlayController?
    var leftStick: VirtualThumbstick!
    var rightStick: VirtualThumbstick!
    var customButtons: [UIButton] = []
    var isEditMode = false
    let toolbar = UIView()
    let lockBtn = UIButton(type: .system)
    let logsBtn = UIButton(type: .system)
    let addBtn = UIButton(type: .system)
    let mouseIndicator = UIView()
    let cursorView = UIImageView()
    private var displayLink: CADisplayLink?
    private var layoutDone = false

    let availableButtons: [(name: String, code: Int32)] = [
        ("LCLICK", 1), ("RCLICK", 3), ("ESC", 41), ("ENT", 40), ("TAB", 43), ("SPC", 44),
        ("JUMP", 8), ("JOURN", 13), ("WAIT", 23), ("MAP", 16),
        ("WEAP", 9), ("MAG", 21), ("RUN", 225), ("SNK", 224),
        ("QSAVE", 62), ("QLOAD", 66), ("INV", 12),
        ("F1", 58), ("F2", 59), ("F3", 60), ("F4", 61), ("F5", 62), ("F6", 63),
        ("F7", 64), ("F8", 65), ("F9", 66), ("F10", 67), ("F11", 68), ("F12", 69),
        ("1", 30), ("2", 31), ("3", 32), ("4", 33)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        GameplayOverlayController.shared = self
        view.backgroundColor = .clear
        
        leftStick = VirtualThumbstick(frame: CGRect(x: 0, y: 0, width: 120, height: 120), mode: .joystick)
        view.addSubview(leftStick)
        
        rightStick = VirtualThumbstick(frame: CGRect(x: 0, y: 0, width: 120, height: 120), mode: .mouse)
        view.addSubview(rightStick)
        
        // Toolbar container
        toolbar.frame = CGRect(x: 24, y: 24, width: 180, height: 44)
        toolbar.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        toolbar.layer.cornerRadius = 22
        view.addSubview(toolbar)
        
        addBtn.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addBtn.tintColor = .white
        addBtn.frame = CGRect(x: 2, y: 2, width: 40, height: 40)
        addBtn.addTarget(self, action: #selector(showAddButtonPanel), for: .touchUpInside)
        toolbar.addSubview(addBtn)
        
        lockBtn.setImage(UIImage(systemName: "lock.fill"), for: .normal)
        lockBtn.tintColor = .white
        lockBtn.frame = CGRect(x: 44, y: 2, width: 40, height: 40)
        lockBtn.addTarget(self, action: #selector(toggleEditMode), for: .touchUpInside)
        toolbar.addSubview(lockBtn)
        
        logsBtn.setImage(UIImage(systemName: "terminal.fill"), for: .normal)
        logsBtn.tintColor = .white
        logsBtn.frame = CGRect(x: 86, y: 2, width: 40, height: 40)
        logsBtn.addTarget(self, action: #selector(toggleLogs), for: .touchUpInside)
        toolbar.addSubview(logsBtn)
        
        mouseIndicator.frame = CGRect(x: 136, y: 17, width: 10, height: 10)
        mouseIndicator.layer.cornerRadius = 5
        mouseIndicator.backgroundColor = .systemGray
        toolbar.addSubview(mouseIndicator)
        
        // Cursor icon - Solid Red Circle for guaranteed visibility
        cursorView.image = nil
        cursorView.backgroundColor = .systemRed
        cursorView.layer.borderColor = UIColor.white.cgColor
        cursorView.layer.borderWidth = 2
        cursorView.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        cursorView.layer.cornerRadius = 8
        cursorView.layer.zPosition = 9999
        cursorView.isHidden = true
        view.addSubview(cursorView)
        
        loadAllCustomButtons()

        // Polling display link
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateFrame() {
        let shown = checkMouseState()
        mouseIndicator.backgroundColor = shown ? .systemGreen : .systemRed
        
        if shown {
            var mx: Int32 = 0
            var my: Int32 = 0
            getNativeMouseState(x: &mx, y: &my)
            
            // Get the engine's window size
            var ww: Int32 = 0
            var wh: Int32 = 0
            getNativeWindowSize(width: &ww, height: &wh)
            
            if ww > 0 && wh > 0 {
                // Map engine pixels to iOS view points
                let scaleX = view.bounds.width / CGFloat(ww)
                let scaleY = view.bounds.height / CGFloat(wh)
                cursorView.center = CGPoint(x: CGFloat(mx) * scaleX, y: CGFloat(my) * scaleY)
            } else {
                // Fallback to raw points if window size lookup fails
                cursorView.center = CGPoint(x: CGFloat(mx), y: CGFloat(my))
            }
            
            cursorView.isHidden = false
            view.bringSubviewToFront(cursorView)
        } else {
            cursorView.isHidden = true
        }
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc func toggleEditMode() {
        isEditMode.toggle()
        lockBtn.setImage(UIImage(systemName: isEditMode ? "lock.open.fill" : "lock.fill"), for: .normal)
        lockBtn.tintColor = isEditMode ? .systemYellow : .white
        leftStick.isLocked = !isEditMode
        rightStick.isLocked = !isEditMode
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
                leftStick.center = NSCoder.cgPoint(for: saved)
            } else {
                leftStick.center = CGPoint(x: 80, y: screen.height - 80)
            }
            if let saved = UserDefaults.standard.string(forKey: "OverlayRightStickCenter_v7") {
                rightStick.center = NSCoder.cgPoint(for: saved)
            } else {
                rightStick.center = CGPoint(x: screen.width - 80, y: screen.height - 80)
            }
            if customButtons.isEmpty && UserDefaults.standard.array(forKey: "CustomButtonsList_v7") == nil {
                createAndAddButton(name: "LCLICK", scancode: 1, at: CGPoint(x: screen.width - 150, y: screen.height - 130))
                createAndAddButton(name: "RCLICK", scancode: 3, at: CGPoint(x: screen.width - 70, y: screen.height - 130))
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
        panel.layer.cornerRadius = 16; panel.layer.borderWidth = 1; panel.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor; panel.tag = 999
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 12, width: panelW, height: 24))
        titleLabel.text = "Tap to Add Button"; titleLabel.textAlignment = .center; titleLabel.textColor = .white; titleLabel.font = .boldSystemFont(ofSize: 18)
        panel.addSubview(titleLabel)
        let scroll = UIScrollView(frame: CGRect(x: 15, y: 45, width: panelW - 30, height: panelH - 100))
        panel.addSubview(scroll)
        let btnW: CGFloat = 85; let btnH: CGFloat = 40; let gap: CGFloat = 8; let cols = 4
        for (i, data) in availableButtons.enumerated() {
            let row = i / cols; let col = i % cols
            let b = UIButton(type: .system)
            b.frame = CGRect(x: CGFloat(col) * (btnW + gap), y: CGFloat(row) * (btnH + gap), width: btnW, height: btnH)
            b.setTitle(data.name, for: .normal); b.setTitleColor(.white, for: .normal); b.backgroundColor = UIColor.white.withAlphaComponent(0.1); b.layer.cornerRadius = 8; b.tag = Int(data.code)
            b.addTarget(self, action: #selector(buttonSelectedFromGrid(_:)), for: .touchUpInside)
            scroll.addSubview(b); scroll.contentSize = CGSize(width: scroll.frame.width, height: b.frame.maxY + gap)
        }
        let cancelBtn = UIButton(type: .system); cancelBtn.frame = CGRect(x: panelW/2 - 50, y: panelH - 45, width: 100, height: 35); cancelBtn.setTitle("Cancel", for: .normal); cancelBtn.setTitleColor(.white, for: .normal); cancelBtn.backgroundColor = .systemRed.withAlphaComponent(0.6); cancelBtn.layer.cornerRadius = 8
        cancelBtn.addTarget(self, action: #selector(hideConfigPanels), for: .touchUpInside); panel.addSubview(cancelBtn)
        view.addSubview(panel)
    }
    
    @objc func buttonSelectedFromGrid(_ sender: UIButton) {
        guard let name = sender.title(for: .normal) else { return }
        createAndAddButton(name: name, scancode: Int32(sender.tag), at: view.center)
        saveAllCustomButtons(); hideConfigPanels()
    }
    
    @objc func hideConfigPanels() {
        view.viewWithTag(999)?.removeFromSuperview()
        view.viewWithTag(888)?.removeFromSuperview()
        view.viewWithTag(777)?.removeFromSuperview()
    }

    @objc func toggleLogs() {
        if let existing = view.viewWithTag(777) {
            existing.removeFromSuperview()
            return
        }
        
        hideConfigPanels()
        
        let logView = LogOverlayView(isPresented: .init(get: { true }, set: { _ in self.hideConfigPanels() }))
        let hostingController = UIHostingController(rootView: logView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.tag = 777
        
        let width: CGFloat = min(view.bounds.width - 100, 600)
        let height: CGFloat = min(view.bounds.height - 100, 400)
        hostingController.view.frame = CGRect(x: (view.bounds.width - width)/2,
                                            y: (view.bounds.height - height)/2,
                                            width: width,
                                            height: height)
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
    
    private func createAndAddButton(name: String, scancode: Int32, at position: CGPoint) {
        let btn = UIButton(type: .system)
        btn.frame = CGRect(x: 0, y: 0, width: 70, height: 50); btn.center = position; btn.setTitle(name, for: .normal); btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold); btn.setTitleColor(.white, for: .normal); btn.backgroundColor = UIColor.black.withAlphaComponent(0.5); btn.layer.cornerRadius = 10; btn.tag = Int(scancode)
        btn.addTarget(self, action: #selector(customButtonDown(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(customButtonUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleButtonPan(_:))); pan.isEnabled = isEditMode; btn.addGestureRecognizer(pan)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleButtonLongPress(_:))); longPress.isEnabled = isEditMode; btn.addGestureRecognizer(longPress)
        view.addSubview(btn); customButtons.append(btn)
    }

    @objc func customButtonDown(_ sender: UIButton) {
        if isEditMode { return }
        let name = sender.title(for: .normal) ?? ""
        if name == "LCLICK" || name == "RCLICK" {
            sendNativeMouseButton(button: UInt8(sender.tag), state: 1)
        } else {
            sendNativeKey(scancode: Int32(sender.tag), state: 1)
        }
    }
    @objc func customButtonUp(_ sender: UIButton) {
        if isEditMode { return }
        let name = sender.title(for: .normal) ?? ""
        if name == "LCLICK" || name == "RCLICK" {
            sendNativeMouseButton(button: UInt8(sender.tag), state: 0)
        } else {
            sendNativeKey(scancode: Int32(sender.tag), state: 0)
        }
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
        let panel = UIView(frame: CGRect(x: 0, y: 0, width: 240, height: 120))
        panel.center = view.center; panel.backgroundColor = UIColor(white: 0.1, alpha: 0.98); panel.layer.cornerRadius = 16; panel.layer.borderWidth = 1; panel.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.4).cgColor; panel.tag = 888
        let label = UILabel(frame: CGRect(x: 10, y: 15, width: 220, height: 40))
        label.text = "Delete '\(btn.title(for: .normal) ?? "")'?"; label.textColor = .white; label.textAlignment = .center; label.font = .boldSystemFont(ofSize: 16); label.numberOfLines = 2
        panel.addSubview(label)
        let cancelBtn = UIButton(type: .system); cancelBtn.frame = CGRect(x: 15, y: 70, width: 100, height: 35); cancelBtn.setTitle("Cancel", for: .normal); cancelBtn.setTitleColor(.white, for: .normal); cancelBtn.backgroundColor = .gray.withAlphaComponent(0.6); cancelBtn.layer.cornerRadius = 8
        cancelBtn.addTarget(self, action: #selector(hideConfigPanels), for: .touchUpInside); panel.addSubview(cancelBtn)
        let delBtn = UIButton(type: .system); delBtn.frame = CGRect(x: 125, y: 70, width: 100, height: 35); delBtn.setTitle("Delete", for: .normal); delBtn.setTitleColor(.white, for: .normal); delBtn.backgroundColor = .systemRed.withAlphaComponent(0.8); delBtn.layer.cornerRadius = 8
        delBtn.addTarget(self, action: #selector(hideConfigPanels), for: .touchUpInside)
        delBtn.addAction(UIAction { [weak self, weak btn] _ in
            btn?.removeFromSuperview()
            if let b = btn { self?.customButtons.removeAll { $0 == b } }
            self?.saveAllCustomButtons()
        }, for: .touchUpInside)
        panel.addSubview(delBtn); view.addSubview(panel)
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

private class NativeJoystick {
    static let shared = NativeJoystick()
    private var joystick: UnsafeMutableRawPointer?
    private var handle: UnsafeMutableRawPointer?

    init() {
        self.handle = dlopen(nil, RTLD_NOW)
    }

    private func ensureAttached() {
        if joystick != nil { return }
        
        typealias AttachFn = @convention(c) (Int32, Int32, Int32, Int32) -> Int32
        typealias OpenFn = @convention(c) (Int32) -> UnsafeMutableRawPointer?
        
        guard let handle = handle else { return }
        
        if let attachSym = dlsym(handle, "SDL_JoystickAttachVirtual"),
           let openSym = dlsym(handle, "SDL_JoystickOpen") {
            
            let attach = unsafeBitCast(attachSym, to: AttachFn.self)
            let open = unsafeBitCast(openSym, to: OpenFn.self)
            
            // Type 1 = SDL_JOYSTICK_TYPE_GAMECONTROLLER, 2 axes, 0 buttons, 0 hats
            let index = attach(1, 2, 0, 0)
            if index >= 0 {
                self.joystick = open(index)
                print("NativeJoystick: Attached virtual joystick at index \(index)")
            } else {
                print("NativeJoystick: Failed to attach virtual joystick")
            }
        }
    }

    func setAxis(_ axis: Int32, value: Int16) {
        ensureAttached()
        guard let joystick = joystick, let handle = handle else { return }
        
        typealias SetAxisFn = @convention(c) (UnsafeMutableRawPointer?, Int32, Int16) -> Int32
        if let sym = dlsym(handle, "SDL_JoystickSetVirtualAxis") {
            let setAxis = unsafeBitCast(sym, to: SetAxisFn.self)
            _ = setAxis(joystick, axis, value)
        }
    }
}

private func checkMouseState() -> Bool {
    typealias ShowCursorFn = @convention(c) (Int32) -> Int32
    // Use RTLD_DEFAULT to search all loaded libraries
    let handle = UnsafeMutableRawPointer(bitPattern: -2)
    if let sym = dlsym(handle, "SDL_ShowCursor") {
        let showCursor = unsafeBitCast(sym, to: ShowCursorFn.self)
        // SDL_QUERY is -1
        return showCursor(-1) == 1
    }
    return false
}

private func sendNativeMouseMotion(x: Int32, y: Int32) {
    typealias GetFocusWindowFn = @convention(c) () -> UnsafeMutableRawPointer?
    typealias SendMouseMotionFn = @convention(c) (UnsafeMutableRawPointer?, UInt32, Int32, Int32, Int32) -> Int32
    let handle = UnsafeMutableRawPointer(bitPattern: -2)
    var window: UnsafeMutableRawPointer? = nil
    if let getFocusSym = dlsym(handle, "SDL_GetFocusWindow") {
        let getFocus = unsafeBitCast(getFocusSym, to: GetFocusWindowFn.self)
        window = getFocus()
    }
    if let sym = dlsym(handle, "SDL_SendMouseMotion") {
        let sendMotion = unsafeBitCast(sym, to: SendMouseMotionFn.self)
        _ = sendMotion(window, 0, 1, x, y)
    }
}

private func getNativeWindowSize(width: UnsafeMutablePointer<Int32>, height: UnsafeMutablePointer<Int32>) {
    typealias GetFocusWindowFn = @convention(c) () -> UnsafeMutableRawPointer?
    typealias GetWindowSizeFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Void
    let handle = UnsafeMutableRawPointer(bitPattern: -2)

    if let getFocusSym = dlsym(handle, "SDL_GetFocusWindow"),
       let getSizeSym = dlsym(handle, "SDL_GetWindowSize") {
        let getFocus = unsafeBitCast(getFocusSym, to: GetFocusWindowFn.self)
        let getSize = unsafeBitCast(getSizeSym, to: GetWindowSizeFn.self)
        if let window = getFocus() {
            getSize(window, width, height)
        }
    }
}

private func getNativeMouseState(x: UnsafeMutablePointer<Int32>, y: UnsafeMutablePointer<Int32>) {
    typealias GetMouseStateFn = @convention(c) (UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> UInt32
    let handle = UnsafeMutableRawPointer(bitPattern: -2)
    if let sym = dlsym(handle, "SDL_GetMouseState") {
        let getMouseState = unsafeBitCast(sym, to: GetMouseStateFn.self)
        _ = getMouseState(x, y)
    }
}

private func sendNativeKey(scancode: Int32, state: Int32) {
    typealias SendKeyFn = @convention(c) (Int32, Int32) -> Void
    guard let handle = LogRedirector.shared.engineHandle else { return }
    if let sym = dlsym(handle, "SDL_SendVirtualKeyboardKey") {
        let sendKey = unsafeBitCast(sym, to: SendKeyFn.self)
        sendKey(state, scancode)
    }
}

private func sendNativeMouseButton(button: UInt8, state: UInt8) {
    typealias SendMouseFn = @convention(c) (UnsafeMutableRawPointer?, UInt32, UInt8, UInt8) -> Int32
    guard let handle = LogRedirector.shared.engineHandle else { return }
    if let sym = dlsym(handle, "SDL_SendMouseButton") {
        let sendMouse = unsafeBitCast(sym, to: SendMouseFn.self)
        _ = sendMouse(nil, 0, state, button)
    }
}

private func presentAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController?.present(alert, animated: true)
}
