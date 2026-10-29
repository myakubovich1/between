import SwiftUI

@main
struct BetweenApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var testingReducedMotion: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ui-testing") && ProcessInfo.processInfo.arguments.contains("-reduce-motion")
        #else
        false
        #endif
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Color.ink).foregroundStyle(Color.ink)
                .environment(\.betweenReducedMotion, reduceMotion || testingReducedMotion)
                .task(id: scenePhase) { if scenePhase == .active { await store.runForeground() } }
        }
    }
}
struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            if store.config.isDemo { DemoBanner() }
            TabView(selection: $store.selectedTab) {
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
                case "saved": store.selectedTab = 1
                case "you": store.selectedTab = 2
                default: break
                }
            }
        }
    }
}
