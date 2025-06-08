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
    
    var body: some View {
        VStack(spacing: 20) {
            Text("HookX - Hot Corners")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Customize your screen corners to launch applications quickly")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
                        // Request accessibility permissions
                        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
                        let accessEnabled = AXIsProcessTrustedWithOptions([checkOptPrompt: true] as CFDictionary)
                        
                        if !accessEnabled {
                            showPermissionsAlert = true
                        }
                        
                        cornerManager.startMonitoring()
                    } else {
                        cornerManager.stopMonitoring()
                    }
                }
                .frame(maxWidth: 300)
                .padding(.horizontal)
            
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
                Spacer()
                Button("Apply") {
                    cornerManager.saveConfiguration()
                    
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
        .frame(width: 400, height: 500)
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
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("HookX needs accessibility permissions to monitor cursor position and detect hot corners. Please enable these permissions in System Settings.")
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
