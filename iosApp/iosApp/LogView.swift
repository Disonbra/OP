import SwiftUI
import ComposeApp

class SwiftLogManager: ObservableObject {
    static let shared = SwiftLogManager()
    @Published var logs: [String] = []
    
    init() {
        // Pull existing history from Kotlin side so we don't start empty
        let existing = PlayBridge.shared.logs
        for i in 0..<Int(existing.count) {
            if let line = existing.object(at: i) as? String {
                self.logs.append(line)
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewLogs(_:)), name: NSNotification.Name("NewEngineLogs"), object: nil)
    }
    
    @objc private func handleNewLogs(_ notification: Notification) {
        if let newLines = notification.object as? [String] {
            DispatchQueue.main.async {
                self.logs.append(contentsOf: newLines)
                if self.logs.count > 500 {
                    self.logs.removeFirst(self.logs.count - 500)
                }
            }
        }
    }
    
    func clear() {
        logs.removeAll()
        PlayBridge.shared.clearLogs()
    }
}

struct LogOverlayView: View {
    @ObservedObject var logManager = SwiftLogManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Engine Logs")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Clear") {
                    logManager.clear()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.3))
                .cornerRadius(8)
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding()
            .background(Color.black.opacity(0.5))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logManager.logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .id(index)
                        }
                    }
                }
                .onChange(of: logManager.logs.count) { count in
                    if count > 0 {
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(5)
    }
}

extension View {
    func engineLogOverlay(isPresented: Binding<Bool>) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                LogOverlayView(isPresented: isPresented)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(999)
            }
        }
    }
}
