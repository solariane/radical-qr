import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @State private var showingHistory = false
    @State private var showingSettings = false

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
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingHistory = true
                } label: {
                    Label(String(localized: "toolbar.history", defaultValue: "History"), systemImage: "clock.arrow.circlepath")
                }

                Divider()

                Button {
                    showingSettings = true
                } label: {
                    Label(String(localized: "toolbar.settings", defaultValue: "Settings"), systemImage: "gear")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
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
