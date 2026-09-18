import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var showingHelp = false
    @State private var showingFormats = false

    var body: some View {
        #if os(iOS)
        NavigationStack {
            GeneratorView()
                .toolbar {
                    toolbarContent
                }
                .sheet(isPresented: $showingHistory) {
                    if purchaseManager.isPro {
                        HistoryView()
                    } else {
                        PaywallView(feature: .history)
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
                .sheet(isPresented: $showingHelp) {
                    HelpView()
                }
                .sheet(isPresented: $showingFormats) {
                    FormatHelpView()
                }
        }
        .onOpenURL { url in
            deepLinkHandler.handle(url)
        }
        #else
        NavigationSplitView {
            sidebarContent
        } detail: {
            GeneratorView()
        }
        .frame(minWidth: 780, minHeight: 620)
        .sheet(isPresented: $showingHistory) {
            if purchaseManager.isPro {
                HistoryView()
            } else {
                PaywallView(feature: .history)
            }
        }
        .onOpenURL { url in
            deepLinkHandler.handle(url)
        }
        #endif
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // The mark and the name live in the bar the system already draws, instead
        // of a row of their own under it: on a short screen those ~41pt were the
        // difference between seeing the whole code and scrolling for it.
        ToolbarItem(placement: .principal) {
            HStack(spacing: 9) {
                AppMarkGlyph(color: .white)
                    .frame(width: 22, height: 22)
                Text(verbatim: "Radical QR")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingHistory = true
                } label: {
                    Label(String(localized: "toolbar.history", defaultValue: "History"), systemImage: "clock.arrow.circlepath")
                }

                Divider()

                Button {
                    showingFormats = true
                } label: {
                    Label(String(localized: "toolbar.formats", defaultValue: "Formats & Recognition",
                                 comment: "Menu item opening the screen that lists what the app recognizes — free text turned into an event, Wi-Fi, contact or address — with copyable examples."),
                          systemImage: "text.viewfinder")
                }

                Button {
                    showingHelp = true
                } label: {
                    Label(String(localized: "toolbar.help", defaultValue: "Help & Tips"), systemImage: "questionmark.circle")
                }

                Button {
                    showingSettings = true
                } label: {
                    Label(String(localized: "toolbar.settings", defaultValue: "Settings"), systemImage: "gear")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            // The bar is transparent over the gradient: the accent tint reads as
            // disabled there, white as a button.
            .tint(.white)
        }
    }

    #if os(macOS)
    private var sidebarContent: some View {
        List {
            NavigationLink {
                GeneratorView()
            } label: {
                Label(String(localized: "sidebar.generator", defaultValue: "Generator"), systemImage: "qrcode")
            }

            if purchaseManager.isPro {
                NavigationLink {
                    HistoryView()
                } label: {
                    Label(String(localized: "sidebar.history", defaultValue: "History"), systemImage: "clock.arrow.circlepath")
                }
            } else {
                Button {
                    showingHistory = true
                } label: {
                    Label(String(localized: "sidebar.history", defaultValue: "History"), systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.plain)
            }

            Section {
                NavigationLink {
                    HelpView()
                } label: {
                    Label(String(localized: "sidebar.help", defaultValue: "Help"), systemImage: "questionmark.circle")
                }
            }
        }
        .navigationTitle(String(localized: "app.name", defaultValue: "Radical QR"))
        .listStyle(.sidebar)
    }
    #endif
}

#Preview {
    ContentView()
        .environmentObject(PurchaseManager.shared)
        .environment(DeepLinkHandler())
}
