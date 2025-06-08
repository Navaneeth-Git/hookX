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
    
    private var timer: Timer?
    private let cornerTriggerDistance: CGFloat = 15  // Increased from 10 to make detection easier
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
    
    func startMonitoring() {
        guard !isActive else { return }
        
        // Check for accessibility permissions
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let accessEnabled = AXIsProcessTrustedWithOptions([checkOptPrompt: true] as CFDictionary)
        
        if !accessEnabled {
            print("Accessibility permissions are required for hot corners to work")
        }
        
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
        
        for screen in screens {
            let frame = screen.frame
            var detectedCorner: Corner?
            
            // Check if mouse is in any corner (using increased trigger distance)
            if mouseLocation.x <= frame.minX + cornerTriggerDistance && mouseLocation.y >= frame.maxY - cornerTriggerDistance {
                detectedCorner = .topLeft
            } else if mouseLocation.x >= frame.maxX - cornerTriggerDistance && mouseLocation.y >= frame.maxY - cornerTriggerDistance {
                detectedCorner = .topRight
            } else if mouseLocation.x <= frame.minX + cornerTriggerDistance && mouseLocation.y <= frame.minY + cornerTriggerDistance {
                detectedCorner = .bottomLeft
            } else if mouseLocation.x >= frame.maxX - cornerTriggerDistance && mouseLocation.y <= frame.minY + cornerTriggerDistance {
                detectedCorner = .bottomRight
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
        guard let action = cornerActions[corner], let url = action.appURL else { return }
        
        // Print debug information
        print("Triggering action for \(corner.description): \(action.appName)")
        
        // Open the app
        NSWorkspace.shared.open(url)
    }
} 