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
                .frame(minWidth: 400, minHeight: 550)
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
    private var statusMenuItem: NSMenuItem?
    private var statusUpdateTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        
        // Load saved preferences
        if UserDefaults.standard.bool(forKey: "autoStart") {
            print("Auto-starting hot corners from preferences")
            hotCornerManager.isActive = true  // Set this first
            hotCornerManager.startMonitoring()
        }
        
        // Set up a timer to update the menu item state
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusMenuItemState()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
        statusUpdateTimer?.invalidate()
    }
    
    private func updateStatusMenuItemState() {
        DispatchQueue.main.async {
            self.statusMenuItem?.state = self.hotCornerManager.isActive ? .on : .off
        }
    }
    
    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "rectangles.group", accessibilityDescription: "HookX")
            
            // Add a tooltip
            button.toolTip = "HookX - Hot Corners"
        }
        
        let menu = NSMenu()
        
        // Toggle hot corners status
        statusMenuItem = NSMenuItem(
            title: "Hot Corners Active",
            action: #selector(toggleHotCorners),
            keyEquivalent: "t"
        )
        statusMenuItem?.state = hotCornerManager.isActive ? .on : .off
        menu.addItem(statusMenuItem!)
        
        // Add debug info menu item
        let debugMenuItem = NSMenuItem(
            title: "Debug Info",
            action: #selector(showDebugInfo),
            keyEquivalent: "d"
        )
        menu.addItem(debugMenuItem)
        
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
    
    @objc private func showDebugInfo() {
        let alert = NSAlert()
        alert.messageText = "HookX Debug Information"
        
        let debugInfo = """
        Active: \(hotCornerManager.isActive)
        Permission Granted: \(hotCornerManager.accessibilityPermissionGranted)
        Mouse Position: \(hotCornerManager.debugMousePosition)
        
        Top Left: \(hotCornerManager.cornerActions[.topLeft]?.appName ?? "None")
        Top Right: \(hotCornerManager.cornerActions[.topRight]?.appName ?? "None")
        Bottom Left: \(hotCornerManager.cornerActions[.bottomLeft]?.appName ?? "None")
        Bottom Right: \(hotCornerManager.cornerActions[.bottomRight]?.appName ?? "None")
        
        App Path: \(Bundle.main.bundlePath)
        """
        
        alert.informativeText = debugInfo
        alert.addButton(withTitle: "OK")
        
        alert.runModal()
    }
    
    @objc private func toggleHotCorners(_ sender: NSMenuItem) {
        let isActive = !hotCornerManager.isActive
        
        if isActive {
            // Check for accessibility permissions
            let accessEnabled = hotCornerManager.checkAccessibilityPermission(prompt: true)
            
            if accessEnabled {
                print("Starting hot corner monitoring from menu")
                hotCornerManager.isActive = true
                hotCornerManager.startMonitoring()
                sender.state = .on
            }
        } else {
            print("Stopping hot corner monitoring from menu")
            hotCornerManager.isActive = false
            hotCornerManager.stopMonitoring()
            sender.state = .off
        }
    }
}

// Preferences view for additional settings
struct PreferencesView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoStart") private var autoStart = false
    @ObservedObject private var hotCornerManager = HotCornerManager.shared
    
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
                        hotCornerManager.isActive = true
                        hotCornerManager.startMonitoring()
                    } else if !newValue {
                        hotCornerManager.isActive = false
                        hotCornerManager.stopMonitoring()
                    }
                }
            
            Divider()
            
            // Status section
            VStack(alignment: .leading) {
                Text("Status:")
                    .bold()
                Text("Active: \(hotCornerManager.isActive ? "Yes" : "No")")
                Text("Accessibility: \(hotCornerManager.accessibilityPermissionGranted ? "Granted" : "Not Granted")")
            }
            .padding(.vertical)
            
            Divider()
            
            Text("HookX version 1.0")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 350)
    }
}

