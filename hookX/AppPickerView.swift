//
//  AppPickerView.swift
//  hookX
//
//  Created by Claude AI on 6/8/25.
//

import SwiftUI
import AppKit

struct AppItem: Identifiable {
    var id = UUID()
    let url: URL
    let name: String
    let icon: NSImage
}

struct AppPickerView: View {
    var onSelect: (URL, String, NSImage) -> Void
    
    @State private var applications: [AppItem] = []
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredApps: [AppItem] {
        if searchText.isEmpty {
            return applications
        } else {
            return applications.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack {
            Text("Select Application")
                .font(.headline)
                .padding(.top)
            
            TextField("Search applications", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            List {
                ForEach(filteredApps) { app in
                    Button {
                        onSelect(app.url, app.name, app.icon)
                    } label: {
                        HStack {
                            Image(nsImage: app.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            
                            Text(app.name)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            loadApplications()
        }
    }
    
    private func loadApplications() {
        // Get applications from /Applications directory
        let fileManager = FileManager.default
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        
        if let appURLs = try? fileManager.contentsOfDirectory(at: applicationsURL, includingPropertiesForKeys: nil) {
            let apps = appURLs.compactMap { url -> AppItem? in
                guard url.pathExtension == "app" else { return nil }
                
                let name = url.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return AppItem(url: url, name: name, icon: icon)
            }
            
            self.applications = apps.sorted { $0.name < $1.name }
        }
        
        // Also check user applications
        let userAppsURL = URL(fileURLWithPath: "/Users/\(NSUserName())/Applications")
        if fileManager.fileExists(atPath: userAppsURL.path) {
            if let userAppURLs = try? fileManager.contentsOfDirectory(at: userAppsURL, includingPropertiesForKeys: nil) {
                let userApps = userAppURLs.compactMap { url -> AppItem? in
                    guard url.pathExtension == "app" else { return nil }
                    
                    let name = url.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    return AppItem(url: url, name: name, icon: icon)
                }
                
                self.applications.append(contentsOf: userApps)
                self.applications.sort { $0.name < $1.name }
            }
        }
    }
}

#Preview {
    AppPickerView(onSelect: { _, _, _ in })
} 