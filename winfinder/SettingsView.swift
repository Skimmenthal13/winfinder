import SwiftUI
import CoreServices

struct SettingsView: View {
    @AppStorage("winfinder.useAsDefaultFolderHandler")
    private var useAsDefaultHandler = false

    var body: some View {
        Form {
            Section {
                Toggle("Use Win Finder as default folder handler", isOn: $useAsDefaultHandler)
                    .onChange(of: useAsDefaultHandler) { _, enabled in
                        applyHandlerRegistration(enabled: enabled)
                    }
            } header: {
                Text("System Integration")
            } footer: {
                Text("When enabled, Win Finder replaces Finder when other apps call \"Reveal in Finder\". Restoring sets com.apple.finder back as the handler.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func applyHandlerRegistration(enabled: Bool) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let handlerID = enabled ? bundleID : "com.apple.finder"
        LSSetDefaultRoleHandlerForContentType(
            "public.folder" as CFString,
            .viewer,
            handlerID as CFString
        )
    }
}
