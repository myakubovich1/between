import SwiftUI
import AuthenticationServices

struct SavedView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("Keep your good spots close.").font(.subheadline).foregroundStyle(Color.metadata).padding(.bottom, 12)
                if store.favorites.isEmpty {
                    ContentUnavailableView("Keep a good spot handy", systemImage: "bookmark", description: Text("Save a library from Find. Your favorites stay on this device without an account.")).padding(.top, 30)
                    PrimaryButton(title: "Find a library", symbol: "magnifyingglass") { store.selectedTab = 0 }.accessibilityIdentifier("saved-find")
                } else {
                    ForEach(store.places.filter { store.favorites.contains($0.id) }) { place in
                        NavigationLink { PlaceDetailView(place: place) } label: {
                            Surface {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label(place.shortName, systemImage: place.symbol).font(.headline).foregroundStyle(Color.ink)
                                    if !store.config.isDemo { OfficialCountLabel(observation: store.officialOccupancy[place.id], now: store.now, refreshFailed: store.occupancyFailures.contains(place.id)) }
                                    if store.config.isDemo || store.communityAvailable {
                                        StatusLabel(evidence: store.status(place: place.id), now: store.now)
                                        EvidenceCaption(evidence: store.status(place: place.id), now: store.now)
                                    }
                                    Text(store.offline ? "Cached conditions · may be old" : "Check hours and entry before you go").font(.caption).foregroundStyle(Color.metadata)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }.background(Color.canvas).navigationTitle("Saved").refreshable { await store.refresh() }
    }
}
struct YouView: View {
    @Environment(AppStore.self) private var store
    @State private var filters = false
    @State private var clear = false
    @State private var deleting = false
    @State private var demoDelete = false
    var body: some View {
        @Bindable var store = store
        List {
            Section {
                HStack(spacing: 16) {
                    Image("BrandMark").resizable().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) { Text(store.signedIn ? "A little help goes a long way." : "Your space, your pace.").font(.headline); Text(store.signedIn ? store.config.isDemo ? "Demo contributor" : "Signed in with Apple" : "Browsing as a guest").font(.subheadline).foregroundStyle(Color.metadata) }
                }.padding(.vertical, 8)
                if !store.signedIn {
                    if store.config.isDemo {
                        Button("Use demo contributor") { store.signedIn = true }.frame(minHeight: 44)
                    } else if store.communityAvailable {
                        SignInWithAppleButton(.signIn, onRequest: store.prepareApple) { result in Task { await store.completeApple(result) } }.frame(height: 50)
                    } else { Text("Live library data and saved places are available without an account.").font(.footnote).foregroundStyle(Color.metadata) }
                }
            }
            if !store.config.isDemo {
                Section("UF library sources") {
                    Link(destination: UFLibraryData.sourceURL) { Label("UF Libraries occupancy", systemImage: "person.2") }
                    Link(destination: URL(string: "https://libcal.uflib.ufl.edu/hours/")!) { Label("Official opening hours", systemImage: "clock") }
                    Link(destination: URL(string: "https://uflib.ufl.edu/using-the-libraries/studyareas/")!) { Label("Study spaces & reservations", systemImage: "calendar") }
                    Text("Official building and area counts, date-specific hours, and room/carrel availability from UF’s public sources. Counts do not measure available seats. Sensor timestamps aren’t supplied by UF’s display feed.").font(.caption).foregroundStyle(Color.metadata)
                }
            }
            Section("Make it yours") {
                Button { filters = true } label: { Label("Study preferences", systemImage: "slider.horizontal.3") }.frame(minHeight: 44)
                if store.signedIn { NavigationLink { MyReportsView() } label: { Label("My reports", systemImage: "text.bubble") } }
            }
            Section("Your data") {
                NavigationLink { DataExplanationView() } label: { Label("What Between keeps", systemImage: "hand.raised") }
                Button("Clear saved places & preferences") { clear = true }.frame(minHeight: 44)
                publicLink("Privacy policy", key: "PrivacyURL")
                publicLink("Terms of use", key: "TermsURL")
                publicLink("Support", key: "SupportURL")
            }
            if store.signedIn {
                Section("Account") {
                    Button("Sign out") { Task { await store.signOut() } }.frame(minHeight: 44)
                    Button("Delete account", role: .destructive) { if store.config.isDemo { demoDelete = true } else { deleting = true } }.frame(minHeight: 44)
                }
            }
            if store.config.isDemo {
                Section("Demo controls · isolated from live data") {
                    Toggle("Show no community reports", isOn: $store.demoNoReports).onChange(of: store.demoNoReports) { store.recalculateDemo() }
                    Toggle("Simulate offline", isOn: $store.demoOffline).onChange(of: store.demoOffline) { Task { await store.refresh() } }
                    Button("Advance demo clock by 31 minutes") { store.demoOffset += 1860; store.recalculateDemo() }
                    Button("Reset synthetic conditions") { store.demoOffset = 0; store.demoNoReports = false; store.seedDemo() }
                    Text("Synthetic reports, hours and route estimates. Nothing here is a live campus observation.").font(.caption).foregroundStyle(Color.metadata)
                }
            }
            Section { Text("Between · made for the moments between things.\nIndependent capstone project; not affiliated with UF.").font(.caption).foregroundStyle(Color.metadata).frame(maxWidth: .infinity, alignment: .center).padding(.vertical) }.listRowBackground(Color.clear)
        }.scrollContentBackground(.hidden).background(Color.canvas).navigationTitle("You")
            .sheet(isPresented: $filters) { FiltersView().modifier(DemoSheetLabel()) }
            .sheet(isPresented: $deleting) { DeleteAccountView() }
            .confirmationDialog("Clear local saved places and preferences?", isPresented: $clear, titleVisibility: .visible) { Button("Clear local data", role: .destructive) { store.resetLocal() } }
            .confirmationDialog("Delete this isolated demo account?", isPresented: $demoDelete, titleVisibility: .visible) { Button("Delete demo account", role: .destructive) { store.demoReports.removeAll { $0.author == "demo-local-contributor" }; store.signedIn = false; store.myReports = []; store.recalculateDemo(); Task { await store.refresh() } } }
    }
    @ViewBuilder private func publicLink(_ title: String, key: String) -> some View {
        if let url = store.config.publicURL(key) { Link(destination: url) { Label(title, systemImage: "arrow.up.right.square") }.frame(minHeight: 44) }
    }
}
struct MyReportsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            if store.myReports.isEmpty { ContentUnavailableView("No reports yet", systemImage: "text.bubble", description: Text("Share a quick observation from a place you’re visiting.")) }
            ForEach(store.myReports) { report in
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.places.first { $0.id == report.placeID }?.shortName ?? "Study space").font(.headline)
                    Text(report.seat.label).font(.subheadline)
                    Text(report.acceptedAt, style: .relative).font(.caption).foregroundStyle(Color.metadata)
                }.padding(.vertical, 6)
            }
        }.navigationTitle("My reports").task { await store.loadMyReports() }.refreshable { await store.loadMyReports() }
    }
}
struct DataExplanationView: View {
    var body: some View {
        List {
            Section("On this device") { Text("Saved places, study preferences and a small cache of conditions. Authentication tokens are kept in Keychain. Guest saves do not need an account.") }
            Section("When you report") { Text("The server stores your authenticated account ID, place or zone, structured conditions, acceptance time, proximity category and moderation state. Other students see summaries and opaque report references, never your identity or study history.") }
            Section("Location") { Text("Optional foreground samples help estimate routes or support a nearby check. The report endpoint checks the sample and discards raw coordinates. No location trail, continuous tracking or advertising analytics.") }
            Section("Your choices") { Text("Browse without signing in, decline location and choose a manual origin, clear local saves, mute a contributor, or delete your account and contributions from You. Server reports are retained for at most 24 hours; aggregation uses only the most recent 30 minutes.") }
        }.navigationTitle("What we keep").navigationBarTitleDisplayMode(.inline)
    }
}
struct DeleteAccountView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "person.crop.circle.badge.minus").font(.system(size: 50)).foregroundStyle(Color.ink)
                Text("Leave without a trail.").font(.largeTitle.weight(.bold))
                Text("Delete your account, reports, flags and mute list. Refresh sessions are revoked and Apple authorization is revoked before deletion completes. Your local saved places remain unless you clear them separately.")
                Text("Confirm with Apple to finish deleting. If revocation or deletion fails, this screen reports the error; it will not claim success.").font(.footnote).foregroundStyle(Color.metadata)
                if let error = store.error { NoticeView(title: error, symbol: "exclamationmark.triangle") }
                SignInWithAppleButton(.continue, onRequest: store.prepareApple) { result in
                    busy = true
                    Task { await store.completeApple(result, deleting: true); busy = false; if !store.signedIn { dismiss() } }
                }.frame(height: 52).disabled(busy)
                Spacer()
            }.padding(24).background(Color.canvas).navigationTitle("Delete account").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
