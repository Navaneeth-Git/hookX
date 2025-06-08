//
//  hookXApp.swift
//  hookX
//
//  Created by Navaneeth on 6/8/25.
//

import SwiftUI
import AppKit

@main
struct hookXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        // Add settings window
        Settings {
            PreferencesView()
        }
    }
}

// App delegate for additional functionality
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    private let hotCornerManager = HotCornerManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        
        // Load saved preferences
        if UserDefaults.standard.bool(forKey: "autoStart") {
            hotCornerManager.startMonitoring()
        }
    }
    
    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "rectangles.group", accessibilityDescription: "HookX")
        }
        
        let menu = NSMenu()
        
        // Toggle hot corners status
        let statusMenuItem = NSMenuItem(
            title: "Hot Corners Active",
            action: #selector(toggleHotCorners),
            keyEquivalent: "t"
        )
        statusMenuItem.state = hotCornerManager.isActive ? .on : .off
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open HookX", action: #selector(openApp), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusBarItem?.menu = menu
    }
    
    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func toggleHotCorners(_ sender: NSMenuItem) {
        let isActive = !hotCornerManager.isActive
        
        if isActive {
            // Check for accessibility permissions
            let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
            let accessEnabled = AXIsProcessTrustedWithOptions([checkOptPrompt: true] as CFDictionary)
            
            if !accessEnabled {
                // Show alert
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = "HookX needs accessibility permissions to monitor cursor position and detect hot corners. Please enable these permissions in System Settings."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            } else {
                hotCornerManager.startMonitoring()
                sender.state = .on
            }
        } else {
            hotCornerManager.stopMonitoring()
            sender.state = .off
        }
    }
}

// Preferences view for additional settings
struct PreferencesView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoStart") private var autoStart = false
    
    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    // Here we would implement the launch at login functionality
                    print("Launch at login: \(newValue)")
                }
            
            Toggle("Automatically start hot corners", isOn: $autoStart)
                .onChange(of: autoStart) { newValue in
                    if newValue {
                        HotCornerManager.shared.startMonitoring()
                    } else if !newValue {
                        HotCornerManager.shared.stopMonitoring()
                    }
                }
            
            Divider()
            
            Text("HookX version 1.0")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 350)
    }
}
