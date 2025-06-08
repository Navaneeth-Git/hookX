//
//  HotCornerManager.swift
//  hookX
//
//  Created by Claude AI on 6/8/25.
//

import Foundation
import AppKit
import Combine

// Model for hot corner actions
struct HotCornerAction: Identifiable, Equatable {
    var id = UUID()
    var appURL: URL?
    var appName: String = "None"
    var appIcon: NSImage?
}

// Enum for corner positions
enum Corner: String, CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

class HotCornerManager: ObservableObject {
    static let shared = HotCornerManager()
    
    @Published var cornerActions: [Corner: HotCornerAction] = [
        .topLeft: HotCornerAction(),
        .topRight: HotCornerAction(),
        .bottomLeft: HotCornerAction(),
        .bottomRight: HotCornerAction()
    ]
    
    @Published var isActive = false
    @Published var accessibilityPermissionGranted = false
    @Published var debugMousePosition: String = "No data"
    
    private var timer: Timer?
    private let cornerTriggerDistance: CGFloat = 25  // Increased from 15 to make detection even easier
    private var lastCornerTriggered: Corner?
    private var lastCornerTriggerTime = Date()
    private let triggerCooldown: TimeInterval = 1.0  // 1 second cooldown
    
    private init() {
        // Load saved configuration
        loadConfiguration()
        
        // Register for wake from sleep notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWakeFromSleep),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Check initial accessibility permission state
        _ = checkAccessibilityPermission(prompt: false)
        
        print("HotCornerManager initialized - Actions loaded:")
        for (corner, action) in cornerActions {
            print("- \(corner.description): \(action.appName)")
        }
        
        // Auto-start monitoring if we have permissions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.accessibilityPermissionGranted = self.checkAccessibilityPermission(prompt: true)
            if self.accessibilityPermissionGranted {
                print("Auto-starting hot corner monitoring")
                self.isActive = true
                self.startMonitoring()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleWakeFromSleep() {
        // If hot corners were active, restart monitoring
        if isActive {
            restartMonitoring()
        }
    }
    
    func checkAccessibilityPermission(prompt: Bool) -> Bool {
        // Try both methods for requesting accessibility permissions
        
        // Method 1: Using AXIsProcessTrustedWithOptions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        // Method 2: Direct check
        if prompt && !accessEnabled {
            // Force open the accessibility preferences
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
            
            // Show a more visible alert to guide the user
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Please add hookX to the accessibility permissions list:\n1. Click the + button\n2. Navigate to your Applications folder\n3. Select hookX.app\n4. Click Open"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        accessibilityPermissionGranted = accessEnabled
        return accessEnabled
    }
    
    func startMonitoring() {
        guard !isActive else { return }
        
        // Prompt for accessibility permissions if needed
        if !checkAccessibilityPermission(prompt: true) {
            print("No accessibility permissions - can't monitor hot corners")
            
            // Show an alert to guide the user
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "HookX needs accessibility permissions to detect screen corners. Please open System Settings > Privacy & Security > Accessibility and add HookX to the list of allowed apps."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Settings")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // Open accessibility preferences
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            
            return
        }
        
        print("Starting hot corner monitoring")
        isActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkCorners()
        }
        
        // Also add to common run loops for better responsiveness
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }
    
    func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }
    
    func saveConfiguration() {
        // Save configuration using UserDefaults
        let userDefaults = UserDefaults.standard
        
        for corner in Corner.allCases {
            if let action = cornerActions[corner], let url = action.appURL {
                userDefaults.set(url.path, forKey: "hotcorner_\(corner.rawValue)")
                userDefaults.set(action.appName, forKey: "hotcorner_name_\(corner.rawValue)")
            } else {
                userDefaults.removeObject(forKey: "hotcorner_\(corner.rawValue)")
                userDefaults.removeObject(forKey: "hotcorner_name_\(corner.rawValue)")
            }
        }
        
        userDefaults.synchronize()
    }
    
    func loadConfiguration() {
        let userDefaults = UserDefaults.standard
        
        for corner in Corner.allCases {
            if let path = userDefaults.string(forKey: "hotcorner_\(corner.rawValue)"),
               let appName = userDefaults.string(forKey: "hotcorner_name_\(corner.rawValue)") {
                
                let url = URL(fileURLWithPath: path)
                let icon = NSWorkspace.shared.icon(forFile: path)
                
                cornerActions[corner] = HotCornerAction(
                    appURL: url,
                    appName: appName,
                    appIcon: icon
                )
            } else {
                cornerActions[corner] = HotCornerAction()
            }
        }
    }
    
    private func checkCorners() {
        guard isActive else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        
        // Update debug info
        debugMousePosition = "Mouse: (\(Int(mouseLocation.x)), \(Int(mouseLocation.y)))"
        
        for screen in screens {
            let frame = screen.frame
            var detectedCorner: Corner?
            
            // Debug log screen frame occasionally
            if Int.random(in: 0...100) == 50 {  // Log occasionally to avoid spamming
                print("Screen frame: \(frame), Mouse: \(mouseLocation)")
            }
            
            // Check if mouse is in any corner (using increased trigger distance)
            if mouseLocation.x <= frame.minX + cornerTriggerDistance && mouseLocation.y >= frame.maxY - cornerTriggerDistance {
                detectedCorner = .topLeft
                print("Top left corner detected")
            } else if mouseLocation.x >= frame.maxX - cornerTriggerDistance && mouseLocation.y >= frame.maxY - cornerTriggerDistance {
                detectedCorner = .topRight
                print("Top right corner detected")
            } else if mouseLocation.x <= frame.minX + cornerTriggerDistance && mouseLocation.y <= frame.minY + cornerTriggerDistance {
                detectedCorner = .bottomLeft
                print("Bottom left corner detected")
            } else if mouseLocation.x >= frame.maxX - cornerTriggerDistance && mouseLocation.y <= frame.minY + cornerTriggerDistance {
                detectedCorner = .bottomRight
                print("Bottom right corner detected")
            }
            
            // If corner detected and not in cooldown, trigger action
            if let corner = detectedCorner {
                let now = Date()
                if lastCornerTriggered != corner || now.timeIntervalSince(lastCornerTriggerTime) > triggerCooldown {
                    triggerAction(for: corner)
                    lastCornerTriggered = corner
                    lastCornerTriggerTime = now
                }
                break
            }
        }
    }
    
    private func triggerAction(for corner: Corner) {
        guard let action = cornerActions[corner], let url = action.appURL else {
            print("No action configured for \(corner.description)")
            return
        }
        
        // Print debug information
        print("TRIGGERING ACTION for \(corner.description): \(action.appName)")
        
        // Open the app
        NSWorkspace.shared.open(url)
    }
} 