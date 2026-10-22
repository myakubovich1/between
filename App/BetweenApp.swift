import SwiftUI

@main
struct BetweenApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Color.forest)
                .task(id: scenePhase) { if scenePhase == .active { await store.runForeground() } }
        }
    }
}
struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var tab = 0
    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            if store.config.isDemo { DemoBanner() }
            TabView(selection: $tab) {
            NavigationStack { FindView() }.tabItem { Label("Find", systemImage: "map") }.tag(0)
            NavigationStack { SavedView() }.tabItem { Label("Saved", systemImage: "bookmark") }.tag(1)
            NavigationStack { YouView() }.tabItem { Label("You", systemImage: "person.crop.circle") }.tag(2)
        }
        }.background(Color.canvas.ignoresSafeArea())
        .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
        .overlay(alignment: .top) {
            if let notice = store.notice {
                Text(notice).font(.footnote).padding().background(.regularMaterial, in: Capsule()).padding(.top, 35).padding(.horizontal)
                    .onTapGesture { store.notice = nil }.task(id: notice) { try? await Task.sleep(for: .seconds(4)); if store.notice == notice { store.notice = nil } }
            }
        }
        .onAppear {
            if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-screen"), ProcessInfo.processInfo.arguments.count > index + 1 {
                switch ProcessInfo.processInfo.arguments[index + 1] {
                case "saved": tab = 1
                case "you": tab = 2
                default: break
                }
            }
        }
    }
}
