//
//  ContentView.swift
//  hookX
//
//  Created by Navaneeth on 6/8/25.
//

import SwiftUI
import AppKit
import UserNotifications

struct ContentView: View {
    @StateObject private var cornerManager = HotCornerManager.shared
    
    @State private var isShowingAppPicker = false
    @State private var selectedCorner: Corner?
    @State private var showPermissionsAlert = false
    @State private var checkPermissionTimer: Timer?
    @State private var showDebugInfo = false  // Toggle for debug info
    
    var body: some View {
        VStack(spacing: 20) {
            Text("HookX - Hot Corners")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Customize your screen corners to launch applications quickly")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Permission status indicator
            HStack {
                Image(systemName: cornerManager.accessibilityPermissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(cornerManager.accessibilityPermissionGranted ? .green : .orange)
                
                Text(cornerManager.accessibilityPermissionGranted ? "Accessibility: Granted" : "Accessibility: Not Granted")
                    .foregroundColor(cornerManager.accessibilityPermissionGranted ? .green : .orange)
                
                if !cornerManager.accessibilityPermissionGranted {
                    Button("Grant Access") {
                        requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(cornerManager.accessibilityPermissionGranted ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .stroke(cornerManager.accessibilityPermissionGranted ? Color.green : Color.orange, lineWidth: 0.5)
            )
            
            // Main display area showing a rectangle with corners
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(radius: 5)
                    .frame(width: 300, height: 200)
                
                // Screen display
                Image(systemName: "display")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150)
                    .foregroundColor(Color(.tertiaryLabelColor))
                
                // Hot corners display - improved positioning
                CornerButtonView(corner: .topLeft, action: cornerManager.cornerActions[.topLeft]!)
                    .position(x: 25, y: 25)
                    .onTapGesture {
                        selectedCorner = .topLeft
                        isShowingAppPicker = true
                    }
                
                CornerButtonView(corner: .topRight, action: cornerManager.cornerActions[.topRight]!)
                    .position(x: 275, y: 25)
                    .onTapGesture {
                        selectedCorner = .topRight
                        isShowingAppPicker = true
                    }
                
                CornerButtonView(corner: .bottomLeft, action: cornerManager.cornerActions[.bottomLeft]!)
                    .position(x: 25, y: 175)
                    .onTapGesture {
                        selectedCorner = .bottomLeft
                        isShowingAppPicker = true
                    }
                
                CornerButtonView(corner: .bottomRight, action: cornerManager.cornerActions[.bottomRight]!)
                    .position(x: 275, y: 175)
                    .onTapGesture {
                        selectedCorner = .bottomRight
                        isShowingAppPicker = true
                    }
            }
            .padding()
            
            // Active status toggle
            Toggle("Active", isOn: $cornerManager.isActive)
                .toggleStyle(.switch)
                .onChange(of: cornerManager.isActive) { newValue in
                    if newValue {
                        if !cornerManager.accessibilityPermissionGranted {
                            requestAccessibilityPermission()
                        } else {
                            cornerManager.startMonitoring()
                        }
                    } else {
                        cornerManager.stopMonitoring()
                    }
                }
                .frame(maxWidth: 300)
                .padding(.horizontal)
            
            // Debug information
            if showDebugInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Information:")
                        .bold()
                    Text(cornerManager.debugMousePosition)
                    Text("Active: \(cornerManager.isActive ? "Yes" : "No")")
                    Text("Accessibility Granted: \(cornerManager.accessibilityPermissionGranted ? "Yes" : "No")")
                }
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(5)
                .padding(.horizontal)
            }
            
            // Settings and status display
            VStack {
                ForEach(Corner.allCases) { corner in
                    HStack {
                        Text("\(corner.description):")
                            .frame(width: 100, alignment: .leading)
                        
                        if let appIcon = cornerManager.cornerActions[corner]?.appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        
                        Text(cornerManager.cornerActions[corner]?.appName ?? "None")
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button("Change") {
                            selectedCorner = corner
                            isShowingAppPicker = true
                        }
                        .buttonStyle(.borderless)
                        
                        Button("Clear") {
                            cornerManager.cornerActions[corner] = HotCornerAction()
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
            )
            .padding(.horizontal)
            
            Spacer()
            
            HStack {
                // Debug toggle
                Toggle("Debug", isOn: $showDebugInfo)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                Spacer()
                
                Button("Apply") {
                    cornerManager.saveConfiguration()
                    
                    // Re-enable monitoring if it's supposed to be active
                    if cornerManager.isActive {
                        cornerManager.restartMonitoring()
                    }
                    
                    // Show confirmation
                    if #available(macOS 11.0, *) {
                        let center = UNUserNotificationCenter.current()
                        let content = UNMutableNotificationContent()
                        content.title = "HookX"
                        content.subtitle = "Hot corners configuration saved"
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                        center.add(request)
                    } else {
                        // Fallback for older macOS versions
                        NSSound.beep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(width: 400, height: 550)
        .padding()
        .sheet(isPresented: $isShowingAppPicker) {
            AppPickerView(onSelect: { url, name, icon in
                if let corner = selectedCorner {
                    cornerManager.cornerActions[corner] = HotCornerAction(appURL: url, appName: name, appIcon: icon)
                }
                isShowingAppPicker = false
            })
            .frame(width: 500, height: 400)
        }
        .alert("Accessibility Permissions Required", isPresented: $showPermissionsAlert) {
            Button("Open System Settings") {
                openSystemPreferences()
                startPermissionCheckTimer()
            }
            Button("Cancel", role: .cancel) { 
                if cornerManager.isActive && !cornerManager.accessibilityPermissionGranted {
                    cornerManager.isActive = false
                }
            }
        } message: {
            Text("HookX needs accessibility permissions to monitor cursor position and detect hot corners. Please enable these permissions in System Settings.\n\n1. Click 'Open System Settings'\n2. Click the lock icon if needed\n3. Find and check the box next to 'hookX'")
        }
        .onAppear {
            // Request notification permissions
            if #available(macOS 10.14, *) {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if granted {
                        print("Notification permission granted")
                    } else if let error = error {
                        print("Notification permission error: \(error.localizedDescription)")
                    }
                }
            }
            
            // Check accessibility permission
            if !cornerManager.accessibilityPermissionGranted && cornerManager.isActive {
                // If the app was restarted and was previously active, but permissions aren't granted
                showPermissionsAlert = true
            }
            
            // Make sure monitoring is active if it should be
            if cornerManager.isActive && cornerManager.accessibilityPermissionGranted {
                cornerManager.startMonitoring()
            }
        }
        .onDisappear {
            checkPermissionTimer?.invalidate()
            checkPermissionTimer = nil
        }
    }
    
    // Function to request accessibility permissions
    private func requestAccessibilityPermission() {
        if !cornerManager.checkAccessibilityPermission(prompt: true) {
            showPermissionsAlert = true
        } else {
            cornerManager.startMonitoring()
        }
    }
    
    // Function to open system preferences/settings
    private func openSystemPreferences() {
        if #available(macOS 13, *) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
        }
    }
    
    // Start a timer to periodically check if permissions have been granted
    private func startPermissionCheckTimer() {
        checkPermissionTimer?.invalidate()
        checkPermissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let hasPermission = cornerManager.checkAccessibilityPermission(prompt: false)
            if hasPermission {
                checkPermissionTimer?.invalidate()
                checkPermissionTimer = nil
                if cornerManager.isActive {
                    cornerManager.startMonitoring()
                }
            }
        }
    }
}

// View for individual corner buttons
struct CornerButtonView: View {
    let corner: Corner
    let action: HotCornerAction
    
    var body: some View {
        ZStack {
            Circle()
                .fill(action.appURL != nil ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
            
            if let icon = action.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "plus")
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    ContentView()
}
