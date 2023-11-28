//
// SplashView.swift
//
import SwiftUI
import KeyboardShortcuts

#Preview {
    SplashView()
}

struct SplashView: View {
    @AppStorage(AppStorageKey.apiKey) var appStorage_apiKey: String = ""
    @AppStorage(AppStorageKey.finishedOnboarding) var appStorage_finishedOnboarding: Bool = false

    var shortcutName: String {
        var string = ""
        if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleAppWindow) {
            string = shortcut.description
        }
        return string
    }
    
    var body: some View {
        if(!appStorage_finishedOnboarding) {
            OnboardingView(apiKey: $appStorage_apiKey, finishedOnboarding: $appStorage_finishedOnboarding)
                .navigationTitle("Enter your API Key")
        }
        else {
            HStack(spacing: 0) {
                ZStack{
                    Image("SplashIconPatch")
                    if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleAppWindow) {
                        Text(shortcut.description)
                            .padding(4.0)
                            .background(.white.opacity(0.2))
                            .background(.ultraThinMaterial)
                            .cornerRadius(6.0)
                            .offset(x: 34, y: 14)
                    }
                }
                .padding(.bottom, 24.0)
                .background(.thinMaterial)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Open a JavaScript Patch:")
                        .bold()
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "a.circle.fill")
                                .resizable()
                                .foregroundStyle(.primary, .primary.opacity(0.2))
                                .frame(width: 16, height: 16)
                            Text("Select a JavaScript Patch and use the shortcut **\(shortcutName)**")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Image(systemName: "b.circle.fill")
                                .resizable()
                                .foregroundStyle(.primary, .primary.opacity(0.2))
                                .frame(width: 16, height: 16)
                            Text("Right-click a JavaScript Patch and choose **Open with...**")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 8.0)
                    HStack(spacing: 4.0) {
                        Text("You can configure the shortcut in the settings.")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                        Button("Open Settings") {
                            let _ = createSettingsWindow()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.blue)
                        .font(.subheadline)
                    }
                }
                .padding(.top, 8.0)
                .padding(.horizontal, 16.0)
                .padding(.bottom, 24.0)
            }
            .background(.regularMaterial)
            .navigationTitle(APP_NAME)
        }
       
    }
}
